//
//  VoiceInputService.swift
//  FinanceTracker
//
//  On-device speech-to-text wrapper for Quick Entry voice dictation.
//
//  Privacy-critical: `requiresOnDeviceRecognition = true` is enforced and the
//  service hides itself entirely (`isAvailable == false`) when on-device
//  recognition is unavailable for the user's locale. Audio never leaves the
//  device — see APP_PRIVACY_ANSWERS.md §3.7 / §6 (voice entry re-audit trigger).
//

import Foundation
import Combine
import Speech
import AVFoundation
import UIKit

@MainActor
final class VoiceInputService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {

    enum AuthState: Equatable {
        case undetermined
        case authorized
        case denied
        case restricted
        case deviceUnavailable   // locale not supported on-device, or hardware missing
    }

    enum VoiceError: Error {
        case authDenied
        case onDeviceUnavailable
        case audioEngineFailed(underlying: Error)
        case recognitionFailed(underlying: Error)
    }

    @Published private(set) var transcript: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var authState: AuthState = .undetermined

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Auto-stop after a pause so the user doesn't have to tap the mic to finish.
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.8

    // MARK: - Locale resolution

    /// Resolves the user's `appLanguageCode` to the first locale that actually has
    /// on-device recognition installed, trying a regional fallback chain.
    ///
    /// A user may have, say, a Spanish dictation pack for `es_ES` but not `es_MX`.
    /// Hardcoding `es_MX` returned a recognizer whose `supportsOnDeviceRecognition`
    /// was `false`, which auto-hid the mic. Walking a chain (es_MX → es_ES → es)
    /// finds whatever the device has. The same pattern protects EN/RU/PT users on
    /// regional iOS variants. Falls back to the primary candidate (non-nil where
    /// possible) when nothing on-device is available — `isAvailable` then gates the UI.
    nonisolated private static func resolveBestAvailableLocale() -> Locale {
        let stored = UserDefaults.standard.string(forKey: "appLanguageCode") ?? "system"

        let candidates: [String]
        switch stored {
        case "system", "":
            candidates = [Locale.current.identifier]
        case "en":
            candidates = ["en_US", "en_GB", "en_AU", "en_CA", "en_IE", "en"]
        case "ru":
            candidates = ["ru_RU", "ru"]
        case "es":
            // Mexican Spanish first (LATAM target), then Spain, then generic.
            candidates = ["es_MX", "es_ES", "es_419", "es_AR", "es_CO", "es"]
        case "de":
            candidates = ["de_DE", "de_AT", "de_CH", "de"]
        case "fr":
            candidates = ["fr_FR", "fr_CA", "fr"]
        case "pt", "pt-BR":
            candidates = ["pt_BR", "pt_PT", "pt"]
        case "ja":
            candidates = ["ja_JP", "ja"]
        case "zh", "zh-Hans":
            candidates = ["zh_CN", "zh_Hans", "zh"]
        default:
            candidates = [Locale.current.identifier]
        }

        for code in candidates {
            let locale = Locale(identifier: code)
            if let recognizer = SFSpeechRecognizer(locale: locale),
               recognizer.supportsOnDeviceRecognition {
                #if DEBUG
                print("[VoiceInputService] Using locale: \(code)")
                #endif
                return locale
            }
        }

        #if DEBUG
        print("[VoiceInputService] No on-device recognizer for appLanguageCode=\(stored)")
        #endif
        return Locale(identifier: candidates.first ?? Locale.current.identifier)
    }

    // MARK: - Init

    /// `locale` is injectable for testing (e.g. an unsupported locale to exercise the
    /// `isAvailable == false` path). Defaults to the best on-device locale for the
    /// app language selected by the user.
    init(locale: Locale = VoiceInputService.resolveBestAvailableLocale()) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        recognizer?.delegate = self
        recognizer?.defaultTaskHint = .dictation

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Tear down audio synchronously; we cannot hop to the main actor from deinit.
        recognitionTask?.cancel()
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
    }

    // MARK: - Availability

    /// True only when on-device recognition is supported for the current locale.
    /// When false, the UI must hide the mic button entirely.
    var isAvailable: Bool {
        guard let recognizer else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    // MARK: - Authorization

    /// Idempotent: the first call triggers the system prompts; subsequent calls return
    /// the cached state without re-prompting.
    func requestAuthorizationIfNeeded() async -> AuthState {
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            authState = .deviceUnavailable
            return authState
        }

        // Cached terminal state — don't re-prompt.
        switch authState {
        case .authorized, .denied, .restricted, .deviceUnavailable:
            return authState
        case .undetermined:
            break
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            break
        case .denied:
            authState = .denied
            return authState
        case .restricted:
            authState = .restricted
            return authState
        case .notDetermined:
            authState = .undetermined
            return authState
        @unknown default:
            authState = .denied
            return authState
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        authState = micGranted ? .authorized : .denied
        return authState
    }

    // MARK: - Listening

    /// Begins listening, updating `transcript` in real time. Throws if not authorized
    /// or if on-device recognition is unavailable.
    func start() async throws {
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            throw VoiceError.onDeviceUnavailable
        }
        guard authState == .authorized else {
            throw VoiceError.authDenied
        }

        // Tear down any prior session before starting a fresh one.
        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true   // privacy guarantee — never relax
        request.shouldReportPartialResults = true
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            cleanup()
            throw VoiceError.audioEngineFailed(underlying: error)
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanup()
            throw VoiceError.audioEngineFailed(underlying: error)
        }

        transcript = ""
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stop()
                        return
                    }
                    self.resetSilenceTimer()
                }
                if error != nil {
                    self.stop()
                }
            }
        }
    }

    /// Stops listening. Safe to call when not listening (no-op).
    func stop() {
        cleanup()
    }

    /// Restarts the silence countdown on every new partial transcript. When no fresh
    /// speech arrives within `silenceThreshold`, listening auto-stops.
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
    }

    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        request = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
    }

    // MARK: - Lifecycle

    @objc private func handleResignActive() {
        stop()
    }

    // MARK: - SFSpeechRecognizerDelegate

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        guard !available else { return }
        Task { @MainActor in
            self.stop()
        }
    }
}
