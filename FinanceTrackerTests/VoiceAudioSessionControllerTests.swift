//
//  VoiceAudioSessionControllerTests.swift
//  FinanceTrackerTests
//
//  The music-does-not-resume bug (1.0.5) was a swallowed `setActive(false)`.
//  These pin the two things that stop it coming back: the deactivation is
//  retried until it succeeds or gives up loudly, and no code outside the
//  controller can touch AVAudioSession at all — a `try?` there is exactly the
//  defect, one file over.
//
//  COMMISSIONED RED 2026-09-21, both halves — see the Phase 0 report.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("VoiceAudioSessionController release contract")
@MainActor
struct VoiceAudioSessionControllerTests {

    /// A backend whose `deactivate` fails `failuresBeforeSuccess` times with
    /// OSStatus-shaped errors, then succeeds. Sleeps return immediately and are
    /// recorded so the schedule itself is asserted, not just the outcome.
    final class ScriptedBackend {
        var failuresBeforeSuccess: Int
        private(set) var deactivateCalls = 0
        private(set) var activateCalls = 0
        private(set) var sleeps: [Duration] = []

        init(failuresBeforeSuccess: Int) { self.failuresBeforeSuccess = failuresBeforeSuccess }

        var backend: VoiceAudioSessionController.Backend {
            VoiceAudioSessionController.Backend(
                activate: { [self] in activateCalls += 1 },
                deactivate: { [self] in
                    deactivateCalls += 1
                    if deactivateCalls <= failuresBeforeSuccess {
                        // 561017449 = '!int' (AVAudioSessionErrorCodeIsBusy) — the
                        // code a session-busy failure carries on a real device.
                        throw NSError(domain: NSOSStatusErrorDomain, code: 561_017_449)
                    }
                },
                isOtherAudioPlaying: { false },
                sleep: { [self] in sleeps.append($0) }
            )
        }
    }

    @Test("release without activate is a no-op and touches the session zero times")
    func releaseWithoutActivate() async {
        let scripted = ScriptedBackend(failuresBeforeSuccess: 0)
        let controller = VoiceAudioSessionController(backend: scripted.backend)
        let outcome = await controller.release().value
        #expect(outcome == .notActive)
        #expect(scripted.deactivateCalls == 0)
    }

    @Test("a deactivation that succeeds first time is not retried")
    func firstAttemptSucceeds() async throws {
        let scripted = ScriptedBackend(failuresBeforeSuccess: 0)
        let controller = VoiceAudioSessionController(backend: scripted.backend)
        try controller.activate()
        let outcome = await controller.release().value
        #expect(outcome == .released(attempts: 1))
        #expect(scripted.deactivateCalls == 1)
        #expect(controller.isActive == false)
    }

    @Test("a busy session is retried until it releases — the field bug")
    func busySessionIsRetried() async throws {
        let scripted = ScriptedBackend(failuresBeforeSuccess: 2)
        let controller = VoiceAudioSessionController(backend: scripted.backend)
        try controller.activate()
        let outcome = await controller.release().value
        #expect(outcome == .released(attempts: 3))
        #expect(scripted.deactivateCalls == 3)
        // Prefix, not equality: after a successful release the controller also
        // sleeps 2 s before probing whether other audio resumed, and that sleep
        // may or may not have been recorded by the time this line runs.
        #expect(Array(scripted.sleeps.prefix(2)) == Array(VoiceAudioSessionController.retryDelays.prefix(2)))
    }

    @Test("a session that never releases gives up after the whole schedule, reporting the code")
    func givesUpLoudly() async throws {
        let scripted = ScriptedBackend(failuresBeforeSuccess: .max)
        let controller = VoiceAudioSessionController(backend: scripted.backend)
        try controller.activate()
        let outcome = await controller.release().value
        let expectedAttempts = VoiceAudioSessionController.retryDelays.count + 1
        #expect(outcome == .failed(attempts: expectedAttempts, code: 561_017_449))
        #expect(scripted.deactivateCalls == expectedAttempts)
        #expect(scripted.sleeps == VoiceAudioSessionController.retryDelays)
    }

    @Test("a second release while the first is retrying does not double-deactivate")
    func secondReleaseIsIdempotent() async throws {
        let scripted = ScriptedBackend(failuresBeforeSuccess: 1)
        let controller = VoiceAudioSessionController(backend: scripted.backend)
        try controller.activate()
        let first = controller.release()
        let second = await controller.release().value
        #expect(second == .notActive)
        #expect(await first.value == .released(attempts: 2))
        #expect(scripted.deactivateCalls == 2)
    }

    @Test("activation failure propagates instead of being swallowed")
    func activationFailurePropagates() {
        var backend = ScriptedBackend(failuresBeforeSuccess: 0).backend
        backend.activate = { throw NSError(domain: NSOSStatusErrorDomain, code: -50) }
        let controller = VoiceAudioSessionController(backend: backend)
        #expect(throws: NSError.self) { try controller.activate() }
        #expect(controller.isActive == false)
    }
}

@Suite("AVAudioSession is touched in exactly one file, and never with try?")
struct AudioSessionCallSiteGuardTests {

    private static let scannedRoots = ["FinanceTracker", "BudgetCrabShared", "BudgetCrabWidget"]
    private static let onlyPermittedFile = "FinanceTracker/Services/VoiceAudioSessionController.swift"

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func stripLineComment(_ line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[line.startIndex..<range.lowerBound])
    }

    @Test("no file other than the controller references AVAudioSession; the controller never uses try?")
    func audioSessionIsConfinedToTheController() throws {
        let root = repoRoot()
        var scannedFiles = 0
        var strays: [String] = []
        var swallowed: [String] = []
        var controllerSeen = false

        for directory in Self.scannedRoots {
            let url = root.appendingPathComponent(directory)
            var isDirectory: ObjCBool = false
            #expect(
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue,
                "scan root \(directory) is missing — the sources moved and this guard is scanning nothing"
            )
            let enumerator = try #require(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                scannedFiles += 1
                let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
                let source = try String(contentsOf: file, encoding: .utf8)
                for (offset, rawLine) in source.components(separatedBy: .newlines).enumerated() {
                    let line = stripLineComment(rawLine)
                    guard line.contains("AVAudioSession") else { continue }
                    if relative == Self.onlyPermittedFile {
                        controllerSeen = true
                        if line.contains("try?") { swallowed.append("\(relative):\(offset + 1)  \(rawLine.trimmingCharacters(in: .whitespaces))") }
                    } else {
                        strays.append("\(relative):\(offset + 1)  \(rawLine.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }

        #expect(scannedFiles > 100, "scanned only \(scannedFiles) files — the corpus is not what this guard thinks it is")
        #expect(controllerSeen, "the controller no longer references AVAudioSession — this guard is asserting on nothing")
        #expect(strays.isEmpty, Comment(rawValue: "AVAudioSession is used outside the controller:\n" + strays.joined(separator: "\n")))
        #expect(swallowed.isEmpty, Comment(rawValue: "the controller swallows an AVAudioSession error:\n" + swallowed.joined(separator: "\n")))
    }
}
