//
//  LaunchTimeline.swift
//  FinanceTracker
//
//  DEBUG-only. Writes, per launch, WHEN the launch-path seeding finished, so a
//  UI-test failure can say whether the app had finished seeding when the
//  assertion gave up (2026-10-12, D33).
//
//  Why a file: app stdout/os_log is NOT captured in xcodebuild logs, and the
//  /tmp channel is the one the suite already reads back (simulator processes
//  share the host filesystem; see MainThreadStallMonitor.note).
//
//  Format: `begin()` TRUNCATES the file, so it always describes the most
//  recent launch, which is the one a failing test is looking at:
//
//      launch pid=14797 at=1791797042.123
//      +0.412s task-start
//      +0.415s purge-done
//      +1.020s seed-done demo=1
//      +1.034s seams-done rows=212
//
//  Read by FinanceTrackerUITests/UITestFailureDiagnostics.swift.
//

import Foundation

#if DEBUG
enum LaunchTimeline {
    static let path = "/tmp/budgetcrab-launch-timeline.txt"

    /// Wall-clock time of `begin()`; offsets are measured from here.
    private static var launchedAt: Date?

    static func begin() {
        let now = Date()
        launchedAt = now
        let line = "launch pid=\(ProcessInfo.processInfo.processIdentifier)"
            + " at=\(String(format: "%.3f", now.timeIntervalSince1970))\n"
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func mark(_ event: String) {
        guard let launchedAt else { return }
        let offset = Date().timeIntervalSince(launchedAt)
        let line = String(format: "+%.3fs ", offset) + event + "\n"
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    }
}
#endif
