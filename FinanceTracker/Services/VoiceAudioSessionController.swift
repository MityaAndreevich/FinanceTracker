//
//  VoiceAudioSessionController.swift
//  FinanceTracker
//
//  The ONLY place this app touches `AVAudioSession`.
//
//  WHY THIS EXISTS
//    Field bug, 1.0.5 (10), confirmed on the founder's iPhone: after every voice
//    entry, music or a podcast that was playing stays paused. The one call that
//    lets other apps resume is
//        setActive(false, options: .notifyOthersOnDeactivation)
//    and `VoiceInputService.cleanup()` made it with `try?`. If it failed, nothing
//    said so, nothing retried, and the other app was never told to resume.
//
//    This type makes that call un-swallowable: every failure is logged with its
//    code, a failed deactivation is retried on a bounded schedule, and a final
//    failure is logged as a fault. It deactivates only a session it activated.
//
//  WHAT IS NOT YET KNOWN (2026-09-21)
//    That the swallowed error IS the cause has not been observed on a device.
//    The log lines below exist to settle it in one run with music playing:
//    `othersPlayingAtActivate` and `othersPlayingAfterRelease` report whether
//    other audio was playing before we took the session and whether it came back.
//
//  Privacy: the log carries error codes, attempt counts and two booleans about
//  OTHER apps' audio. No transcript, no audio, no user content.
//

import AVFoundation
import os

let voiceAudioLog = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "VoiceAudio")

@MainActor
final class VoiceAudioSessionController {

    /// The calls into the system, injectable so the retry contract is testable
    /// without a microphone.
    struct Backend {
        var activate: () throws -> Void
        var deactivate: () throws -> Void
        var isOtherAudioPlaying: () -> Bool
        var sleep: (Duration) async -> Void
    }

    enum ReleaseOutcome: Equatable {
        /// We never activated the session, so there is nothing to give back.
        case notActive
        case released(attempts: Int)
        /// Every attempt failed. `code` is the last `NSError.code`.
        case failed(attempts: Int, code: Int)
        /// A new `activate()` took the session while a retry was pending; that
        /// activation owns the session now and will release it itself.
        case superseded
    }

    static let shared = VoiceAudioSessionController(backend: .live)

    /// Delays before attempts 2…n. Bounded: about 1.9 s in total, then give up loudly.
    static let retryDelays: [Duration] = [
        .milliseconds(100), .milliseconds(250), .milliseconds(500), .seconds(1)
    ]

    private let backend: Backend
    private(set) var isActive = false
    /// Bumped on every activation, so a pending retry can tell it has been overtaken.
    private var generation = 0

    init(backend: Backend) {
        self.backend = backend
    }

    func activate() throws {
        generation += 1
        let othersPlaying = backend.isOtherAudioPlaying()
        do {
            try backend.activate()
        } catch {
            let ns = error as NSError
            voiceAudioLog.error(
                "activate failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)"
            )
            throw error
        }
        isActive = true
        voiceAudioLog.info("activated othersPlayingAtActivate=\(othersPlaying, privacy: .public)")
    }

    /// Gives the session back so other apps can resume. The first attempt is made
    /// synchronously, before this returns; retries run in the returned task, which
    /// does not depend on the caller staying alive — the Quick Entry sheet is
    /// usually dismissed within a second of the last word.
    @discardableResult
    func release() -> Task<ReleaseOutcome, Never> {
        guard isActive else { return Task { .notActive } }
        isActive = false
        let owner = generation

        var lastCode: Int
        do {
            try backend.deactivate()
            reportReleased(attempts: 1)
            return Task { .released(attempts: 1) }
        } catch {
            lastCode = logDeactivateFailure(error, attempt: 1)
        }

        return Task { @MainActor in
            var attempt = 1
            for delay in Self.retryDelays {
                await self.backend.sleep(delay)
                guard owner == self.generation else {
                    voiceAudioLog.info("deactivate retry superseded by a new activation")
                    return .superseded
                }
                attempt += 1
                do {
                    try self.backend.deactivate()
                    self.reportReleased(attempts: attempt)
                    return .released(attempts: attempt)
                } catch {
                    lastCode = self.logDeactivateFailure(error, attempt: attempt)
                }
            }
            voiceAudioLog.fault(
                "deactivate GAVE UP attempts=\(attempt, privacy: .public) code=\(lastCode, privacy: .public) — other apps were not told to resume"
            )
            return .failed(attempts: attempt, code: lastCode)
        }
    }

    private func logDeactivateFailure(_ error: Error, attempt: Int) -> Int {
        let ns = error as NSError
        voiceAudioLog.error(
            "deactivate failed attempt=\(attempt, privacy: .public) domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)"
        )
        return ns.code
    }

    private func reportReleased(attempts: Int) {
        voiceAudioLog.info("deactivated attempts=\(attempts, privacy: .public)")
        // Whether the music actually came back is the question the field bug asks,
        // and other apps take a moment to react to the notification.
        let owner = generation
        Task { @MainActor in
            await self.backend.sleep(.seconds(2))
            guard owner == self.generation, !self.isActive else { return }
            voiceAudioLog.info(
                "othersPlayingAfterRelease=\(self.backend.isOtherAudioPlaying(), privacy: .public)"
            )
        }
    }
}

extension VoiceAudioSessionController.Backend {
    static let live = Self(
        activate: {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
        },
        deactivate: {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        },
        isOtherAudioPlaying: { AVAudioSession.sharedInstance().isOtherAudioPlaying },
        // Cancellation is the only failure, and an early wake-up only means an early retry.
        sleep: { try? await Task.sleep(for: $0) }
    )
}
