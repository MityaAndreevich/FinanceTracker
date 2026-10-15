//
//  TabBarNavigation.swift
//  FinanceTrackerUITests
//
//  The one way a D33-affected test taps a tab (2026-10-14).
//
//  WHY: in every residual D33 red a tab-bar tap was not acted on. The app stayed
//  on a populated Dashboard and the test failed LATER, with a message naming
//  what it expected next ("no rows (demo seed missing)", "Save button missing").
//  That message was wrong about the cause. This helper asserts the EXPECTED
//  STATE right after the tap, so the red names the tap.
//
//  WHAT IT IS NOT: a retry. One tap, then a check. It never taps again, never
//  loops until selected, and its 2 s bound is shorter than every wait it
//  precedes, so it cannot turn a red green. If the tap is ignored, the test goes
//  red here, with what is on screen.
//
//  It also logs the test's side of the tap to os_log (subsystem
//  com.dmitrylogachev.budgetcrab.uitests, category D33TabTap): wall-clock tap
//  time, the element's frame, isHittable, and how many elements match. The app
//  logs its side under `--d33-tap-diagnostics` (Shared/TabTapDiagnostics.swift).
//
//  Tabs: Dashboard 0, Transactions 1, + 2 (an action: opens Quick Add and puts
//  the selection back), Analytics 3, Settings 4.
//

import XCTest
import os

enum TabBarNavigation {
    /// Add to `launchArguments` (appended, never inside a `-key value` array).
    static let appDiagnosticsArgument = "--d33-tap-diagnostics"
    /// How long the selected state may take to show after `tap()` returns.
    static let settleBound: TimeInterval = 2
    static let log = Logger(subsystem: "com.dmitrylogachev.budgetcrab.uitests", category: "D33TabTap")
}

extension XCUIApplication {

    func tapTab(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "tab #\(index) never appeared",
                      file: file, line: line)

        // (c) The test's side, recorded BEFORE the tap.
        let label = tab.label
        let frame = tab.frame
        let hittable = tab.isHittable
        let tabBarCount = tabBars.count
        let sameLabelInApp = descendants(matching: .button)
            .matching(NSPredicate(format: "label == %@", label)).count
        let selectedBefore = selectedTabLabel()
        let tappedAt = Date().timeIntervalSince1970

        tab.tap()

        let facts = String(
            format: "tap t=%.3f tab=#%d frame=(%.0f,%.0f,%.0f,%.0f) isHittable=%@ tabBars=%d sameLabelButtons=%d selectedBefore=%@",
            tappedAt, index, frame.minX, frame.minY, frame.width, frame.height,
            hittable ? "true" : "false", tabBarCount, sameLabelInApp, selectedBefore)
        TabBarNavigation.log.notice("\(facts, privacy: .public)")

        let reached: Bool
        let expected: String
        if index == 2 {
            expected = "the Quick Add sheet"
            reached = buttons["quickEntry.close"].waitForExistence(timeout: TabBarNavigation.settleBound)
        } else {
            expected = "'\(label)' Selected"
            let immediately = tab.isSelected
            reached = immediately || XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: tab)],
                timeout: TabBarNavigation.settleBound) == .completed
            if reached && !immediately {
                TabBarNavigation.log.notice("selection lagged: '\(label, privacy: .public)' not Selected when tap() returned, Selected within \(TabBarNavigation.settleBound, privacy: .public)s")
            }
        }
        TabBarNavigation.log.notice("after-tap t=\(String(format: "%.3f", Date().timeIntervalSince1970), privacy: .public) reached=\(reached, privacy: .public) selectedNow=\(self.selectedTabLabel(), privacy: .public)")
        guard !reached else { return }

        let message = "tab tap ignored: '\(selectedTabLabel())' still selected after tapping "
            + "'\(label)' (#\(index)); expected \(expected) within \(Int(TabBarNavigation.settleBound)) s; "
            + "seed rows=\(Self.seedRows())"
        XCTContext.runActivity(named: "tab tap ignored") { activity in
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "tabtap-screen"
            screen.lifetime = .keepAlways
            activity.add(screen)
            let tree = XCTAttachment(string: debugDescription)
            tree.name = "tabtap-hierarchy"
            tree.lifetime = .keepAlways
            activity.add(tree)
            let tap = XCTAttachment(string: facts + "\n" + message)
            tap.name = "tabtap-facts"
            tap.lifetime = .keepAlways
            activity.add(tap)
        }
        XCTFail(message, file: file, line: line)
    }

    private func selectedTabLabel() -> String {
        let selected = tabBars.buttons.matching(NSPredicate(format: "isSelected == true"))
        return selected.count == 0 ? "none" : selected.firstMatch.label
    }

    /// From the app's launch timeline (FinanceTracker/Shared/LaunchTimeline.swift).
    private static func seedRows() -> String {
        guard let text = try? String(contentsOfFile: "/tmp/budgetcrab-launch-timeline.txt", encoding: .utf8) else {
            return "? (no launch timeline)"
        }
        if let r = text.range(of: #"seams-done rows=(\d+)"#, options: .regularExpression) {
            return String(text[r].dropFirst("seams-done rows=".count))
        }
        return text.contains("seed-done") ? "? (seeded, rows not yet counted)" : "? (seeding NOT complete)"
    }
}
