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

    // MARK: - Locale resolution

    /// Maps the user's `appLanguageCode` AppStorage value to the correct recognizer locale.
    /// Falls back to `Locale.current` for "system" or any unrecognized code.
    nonisolated private static func resolvedLocale() -> Locale {
        let stored = UserDefaults.standard.string(forKey: "appLanguageCode") ?? "system"
        switch stored {
        case "system", "":
            return .current
        case "en":
            return Locale(identifier: "en_US")
        case "ru":
            return Locale(identifier: "ru_RU")
        case "es":
            return Locale(identifier: "es_MX")
        case "de":
            return Locale(identifier: "de_DE")
        case "fr":
            return Locale(identifier: "fr_FR")
        case "pt-BR":
            return Locale(identifier: "pt_BR")
        case "ja":
            return Locale(identifier: "ja_JP")
        case "zh-Hans":
            return Locale(identifier: "zh_CN")
        default:
            return .current
        }
    }

    // MARK: - Init

    /// `locale` is injectable for testing (e.g. an unsupported locale to exercise the
    /// `isAvailable == false` path). Defaults to the app language selected by the user.
    init(locale: Locale = VoiceInputService.resolvedLocale()) {
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

    private func cleanup() {
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
