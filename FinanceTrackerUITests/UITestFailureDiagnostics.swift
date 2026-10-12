//
//  UITestFailureDiagnostics.swift
//  FinanceTrackerUITests
//
//  On the FIRST failure in every UI test, attaches, automatically:
//    1. a screenshot of the whole screen (XCUIScreen, so out-of-process system
//       alerts such as the rating prompt are in it too),
//    2. the app's accessibility hierarchy (`app.debugDescription`), plus
//       SpringBoard's, for system alerts the app's tree does not contain,
//    3. the launch timeline: when the launch-path seeding finished relative to
//       launch, or that it had not, against the moment of the failure
//       (FinanceTracker/Shared/LaunchTimeline.swift, DEBUG).
//
//  Why (2026-10-12, D33): four reds had the same observable, an element that
//  should be present was ABSENT, on four screens. A message like "demo seed
//  missing" names the test's guess, not what was on screen. With this, every
//  red is diagnosable from its own bundle without another run.
//
//  Registered as the bundle's NSPrincipalClass (INFOPLIST_KEY_NSPrincipalClass
//  on the UI-test target), so no test class has to opt in.
//

import XCTest

@objc(UITestFailureDiagnostics)
final class UITestFailureDiagnostics: NSObject, XCTestObservation {
    private var attachedForCurrentTest = false
    private var capturing = false

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        attachedForCurrentTest = false
    }

    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        // Once per test, and never re-entrantly: a query below that itself
        // fails must not recurse into another capture.
        guard !attachedForCurrentTest, !capturing, Thread.isMainThread else { return }
        attachedForCurrentTest = true
        capturing = true
        defer { capturing = false }
        let failedAt = Date()
        MainActor.assumeIsolated {
            Self.capture(into: testCase, failedAt: failedAt)
        }
    }

    @MainActor
    private static func capture(into testCase: XCTestCase, failedAt: Date) {
        func attach(_ attachment: XCTAttachment, _ name: String) {
            attachment.name = "failure-\(name)"
            attachment.lifetime = .keepAlways
            testCase.add(attachment)
        }

        attach(XCTAttachment(screenshot: XCUIScreen.main.screenshot()), "screen")

        let app = XCUIApplication()
        var appPid: String?
        switch app.state {
        case .runningForeground, .runningBackground, .runningBackgroundSuspended:
            let tree = app.debugDescription
            appPid = tree.range(of: #"pid: (\d+)"#, options: .regularExpression)
                .map { String(tree[$0].dropFirst(5)) }
            attach(XCTAttachment(string: tree), "app-hierarchy")
        default:
            attach(XCTAttachment(string: "app not running (state \(app.state.rawValue))"), "app-hierarchy")
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        attach(XCTAttachment(string: springboard.debugDescription), "springboard-hierarchy")

        attach(XCTAttachment(string: timelineReport(failedAt: failedAt, appPid: appPid)), "launch-timeline")
    }

    /// The timeline file plus the two facts a reader needs: how long after launch
    /// the failure came, and whether seeding had finished by then.
    private static func timelineReport(failedAt: Date, appPid: String?) -> String {
        let path = "/tmp/budgetcrab-launch-timeline.txt"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "NO TIMELINE at \(path) (Release build, or the app never reached init)"
        }
        var summary: [String] = []
        let header = text.split(separator: "\n").first.map(String.init) ?? ""
        if let at = header.range(of: #"at=([0-9.]+)"#, options: .regularExpression)
            .flatMap({ Double(header[$0].dropFirst(3)) }) {
            let since = failedAt.timeIntervalSince1970 - at
            summary.append(String(format: "failure at +%.3fs after launch", since))
        }
        summary.append(text.contains("seed-done")
            ? "seeding: COMPLETED before the failure"
            : "seeding: NOT COMPLETED at the failure")
        if let appPid, !header.contains("pid=\(appPid) ") {
            summary.append("⚠ timeline pid does not match the running app (pid \(appPid)): it describes another launch")
        }
        return summary.joined(separator: "\n") + "\n\n" + text
    }
}
