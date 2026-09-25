//
//  AnalyticsToolbarAfterSheetProbeTests.swift
//  FinanceTrackerUITests
//
//  PROBE, not a guard. TestFlight report 2026-09-24 (Elena, iPhone 13, iOS 26.6.1,
//  1.0.6 build 11): on the Analytics tab, once, everything ABOVE the "Analytics"
//  title stopped responding while everything below kept working; a relaunch
//  ~20 minutes later cleared it. The only controls above the title are the
//  navigation bar's — in 1.0.6 that is the Reports entry point.
//
//  Prime suspect: a dismissed sheet (Reports from the toolbar, or the Horizon
//  month sheet) leaving the navigation bar unable to receive touches — the
//  documented SwiftUI class where a toolbar button goes dead after a
//  swipe-dismissed sheet and a scroll revives it (developer.apple.com/forums
//  threads 131404, 685163, 692338).
//
//  Every test below drives one present/dismiss variant repeatedly and, after
//  each dismissal, PROBES the toolbar button: `isHittable`, then a tap that must
//  PRESENT the Reports screen (presence of `reports_kind_picker`, rule 4). On a
//  miss it records whether a scroll revives the button — the discriminator for
//  the known class — and attaches the accessibility tree.
//
//  This file exists to reproduce. If every variant passes, that is recorded as
//  "not reproduced under these variants on iOS 26.5 simulator", nothing more.
//

import XCTest

final class AnalyticsToolbarAfterSheetProbeTests: XCTestCase {

    private static let cycles = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD"
        ]
        app.launchArguments.append("--suppress-rating-prompt")
        // A small real ledger, so Horizon has a month to select.
        app.launchArguments.append("--seed-onboarding-demo")
        app.launch()
        return app
    }

    private func openAnalytics(_ app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["analytics_open_report"].waitForExistence(timeout: 15),
                      "the Reports entry point is missing from Analytics")
    }

    // MARK: - The probe

    /// Taps the toolbar button and requires the Reports screen to PRESENT.
    /// Returns a description of the miss, or nil on success. Leaves the Reports
    /// sheet OPEN on success so the caller chooses how to dismiss it.
    @discardableResult
    private func probeToolbar(_ app: XCUIApplication, cycle: Int, variant: String) -> String? {
        let open = app.buttons["analytics_open_report"]
        let hittable = open.isHittable
        let windows = app.windows.count
        open.tap()
        let presented = app.segmentedControls["reports_kind_picker"].waitForExistence(timeout: 6)
        if presented { return nil }

        // MISS. Discriminate: does a scroll revive it (the known SwiftUI class)?
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "tree-\(variant)-cycle\(cycle)"
        tree.lifetime = .keepAlways
        add(tree)
        app.swipeUp()
        app.swipeDown()
        open.tap()
        let revived = app.segmentedControls["reports_kind_picker"].waitForExistence(timeout: 6)
        return "variant=\(variant) cycle=\(cycle) hittable=\(hittable) windows=\(windows) presented=false revivedByScroll=\(revived)"
    }

    private func dismissReportsBySwipe(_ app: XCUIApplication) {
        // Drag the sheet down from its navigation bar; a sheet's nav bar is the grabber band.
        let bar = app.navigationBars["Reports"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "Reports sheet nav bar missing")
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 700))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(waitForAbsence(app.segmentedControls["reports_kind_picker"], timeout: 6),
                      "Reports sheet did not dismiss by swipe")
    }

    private func dismissReportsByDone(_ app: XCUIApplication) {
        let done = app.navigationBars["Reports"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Done missing on the Reports sheet")
        done.tap()
        XCTAssertTrue(waitForAbsence(app.segmentedControls["reports_kind_picker"], timeout: 6),
                      "Reports sheet did not dismiss by Done")
    }

    private func waitForAbsence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let p = NSPredicate(format: "exists == false")
        let e = XCTNSPredicateExpectation(predicate: p, object: element)
        return XCTWaiter().wait(for: [e], timeout: timeout) == .completed
    }

    // MARK: - Variant 1: Reports sheet, dismissed by swipe

    func test_reportsSheet_dismissedBySwipe_toolbarKeepsPresenting() {
        let app = launch()
        openAnalytics(app)
        var misses: [String] = []
        for c in 1...Self.cycles {
            if let miss = probeToolbar(app, cycle: c, variant: "swipe") { misses.append(miss); break }
            dismissReportsBySwipe(app)
        }
        XCTAssertTrue(misses.isEmpty, "REPRODUCED: \(misses.joined(separator: " | "))")
    }

    // MARK: - Variant 2: Reports sheet, dismissed by Done

    func test_reportsSheet_dismissedByDone_toolbarKeepsPresenting() {
        let app = launch()
        openAnalytics(app)
        var misses: [String] = []
        for c in 1...Self.cycles {
            if let miss = probeToolbar(app, cycle: c, variant: "done") { misses.append(miss); break }
            dismissReportsByDone(app)
        }
        XCTAssertTrue(misses.isEmpty, "REPRODUCED: \(misses.joined(separator: " | "))")
    }

    // MARK: - Variant 3: backgrounded during the dismissal, then foregrounded

    func test_reportsSheet_backgroundedDuringSwipeDismiss_toolbarKeepsPresenting() {
        let app = launch()
        openAnalytics(app)
        var misses: [String] = []
        for c in 1...Self.cycles {
            if let miss = probeToolbar(app, cycle: c, variant: "bg-during-dismiss") { misses.append(miss); break }
            let bar = app.navigationBars["Reports"]
            XCTAssertTrue(bar.waitForExistence(timeout: 5))
            let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 700)))
            // Interrupt while the dismissal is still animating.
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            _ = waitForAbsence(app.segmentedControls["reports_kind_picker"], timeout: 6)
        }
        XCTAssertTrue(misses.isEmpty, "REPRODUCED: \(misses.joined(separator: " | "))")
    }

    // MARK: - Horizon helpers

    private func openHorizon(_ app: XCUIApplication) {
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.staticTexts["Drag across the chart to explore"].waitForExistence(timeout: 10),
                      "Horizon hint missing — no chart to scrub")
    }

    /// Press-and-drag across the chart, which sits below the Horizon mode picker
    /// (the second segmented control) and the tooltip bar.
    private func scrubHorizonChart(_ app: XCUIApplication) {
        let modePicker = app.segmentedControls.element(boundBy: 1)
        XCTAssertTrue(modePicker.waitForExistence(timeout: 5), "Horizon mode picker missing")
        let origin = modePicker.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 1.0)).withOffset(CGVector(dx: 0, dy: 220))
        origin.press(forDuration: 0.4, thenDragTo: origin.withOffset(CGVector(dx: -60, dy: 0)))
    }

    // MARK: - Variant 4: the Horizon month sheet, dismissed by swipe — Elena's screen state

    func test_horizonMonthSheet_dismissedBySwipe_toolbarKeepsPresenting() {
        let app = launch()
        openAnalytics(app)
        openHorizon(app)

        var misses: [String] = []
        for c in 1...Self.cycles {
            // The sticky tooltip replaces the hint once a month is selected, so the
            // scrub is anchored on the mode picker (always present), not the hint.
            let tooltip = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '2026' OR label CONTAINS[c] '2025'")).firstMatch
            if !tooltip.exists {
                scrubHorizonChart(app)
                XCTAssertTrue(tooltip.waitForExistence(timeout: 5), "cycle \(c): the month tooltip never appeared after scrubbing")
            }
            tooltip.tap()
            // MonthDetailSheet PRESENT: its "%d transactions" line (analytics.transactions_count).
            let countLine = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'transaction'")).firstMatch
            XCTAssertTrue(countLine.waitForExistence(timeout: 6), "cycle \(c): the month sheet did not open")
            // Dismiss by swipe: drag down from the sheet's own header band.
            let header = countLine.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            header.press(forDuration: 0.05, thenDragTo: header.withOffset(CGVector(dx: 0, dy: 650)))
            XCTAssertTrue(waitForAbsence(countLine, timeout: 6),
                          "cycle \(c): the month sheet did not dismiss by swipe (probe not reached)")

            if let miss = probeToolbar(app, cycle: c, variant: "horizon-month-swipe") { misses.append(miss); break }
            dismissReportsByDone(app)
        }
        XCTAssertTrue(misses.isEmpty, "REPRODUCED: \(misses.joined(separator: " | "))")
    }

    // MARK: - Variant 5: sticky tooltip UP (the screenshot state), Reports sheet dismissed by swipe

    func test_horizonTooltipUp_reportsSheetDismissedBySwipe_toolbarKeepsPresenting() {
        let app = launch()
        openAnalytics(app)
        openHorizon(app)
        scrubHorizonChart(app)
        let tooltip = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '2026' OR label CONTAINS[c] '2025'")).firstMatch
        XCTAssertTrue(tooltip.waitForExistence(timeout: 5), "the month tooltip never appeared after scrubbing")

        var misses: [String] = []
        for c in 1...Self.cycles {
            if let miss = probeToolbar(app, cycle: c, variant: "tooltip-up-swipe") { misses.append(miss); break }
            dismissReportsBySwipe(app)
            XCTAssertTrue(tooltip.exists, "cycle \(c): the sticky tooltip was lost across the sheet")
        }
        XCTAssertTrue(misses.isEmpty, "REPRODUCED: \(misses.joined(separator: " | "))")
    }
}
