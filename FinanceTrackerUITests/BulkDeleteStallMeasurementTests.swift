//
//  BulkDeleteStallMeasurementTests.swift
//  FinanceTrackerUITests
//
//  MEASUREMENT, not assertion. Answers one question for the 2026-08-04 brief:
//  for how much of a bulk delete is the UI unable to respond to a touch?
//
//  The 131-second figure from 2026-08-03 came from `DuplicateReviewDebugSeed`
//  deleting an inherited 8 000-row table one row at a time on the main thread at
//  launch. That seam is DEBUG-only, but `TransactionResetService.reset` and
//  `DuplicateReviewService.deleteAll` are production and have the same shape, so
//  the shape is what gets measured here — at several ledger sizes, because "at
//  what size does it start to hurt" is the question that decides whether a real
//  user meets it.
//
//  Results land in /tmp/stall-report.txt (the app writes them; simulator
//  processes share the host filesystem). Nothing is asserted about the numbers:
//  a threshold invented before the data would be the same mistake this whole
//  audit exists to clean up.
//

import XCTest

final class BulkDeleteStallMeasurementTests: XCTestCase {

    /// Seeds a ledger, then relaunches asking for the duplicate seam, whose first
    /// act is to delete every row it finds. The stall monitor observes the runloop
    /// across that delete.
    ///
    /// Two launches, not one: the seam order is purge -> seed -> duplicates, so a
    /// single launch carrying both arguments would seed and then immediately wipe
    /// what it seeded, measuring the right shape but obscuring which rows were
    /// present. Seeding first and wiping second keeps "how many rows" explicit.
    private func measureWipe(atRows rows: Int) {
        // ONE launch carrying both seeds. Two launches does not work any more and
        // the reason is worth recording: as of 2026-08-04 a launch that does NOT
        // ask for scale purges a leftover seeded ledger first, using the bulk
        // `delete(model:)` API — so the row-by-row loop would find an empty table
        // and measure nothing. The fixed seam order (purge -> seed -> duplicates)
        // is what makes "establish 8k rows, THEN wipe them row by row" sayable in
        // a single launch, which is also the shape a real user's Reset or
        // Delete-all takes.
        let app = XCUIApplication()
        // Mirrors MainThreadHangScaleTests.launch. The defaults pairs are not
        // decoration: without `-hasCompletedOnboarding YES` the app opens into
        // onboarding, ContentView's seam task never does the work, and the run
        // reports a fast, empty measurement that looks like good news. The first
        // attempt at this test did exactly that.
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD",
        ]
        // Appended AFTER the array: these are NSUserDefaults `-key value` pairs
        // and a lone dash-token in the middle shifts the pairing.
        app.launchArguments += [
            "--suppress-rating-prompt",
            "--seed-large-dataset",
            "--seed-possible-duplicates",
            "--stall-monitor",
        ]
        app.launch()
        // The pre-migration consent gate otherwise sits in front of the tab bar
        // and fakes "app never became ready".
        let proceed = app.buttons["Continue"]
        if proceed.waitForExistence(timeout: 10) { proceed.tap() }
        // Generous: the whole point is that this can take minutes. A timeout here
        // would throw away the measurement rather than record it.
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 900),
                      "app never became ready after the wipe at \(rows) rows")
        app.terminate()
    }

    /// The 8 000-row case: the ledger size the seam already produces, and roughly
    /// 24 months of dense history.
    func test_measure_wipe_at8kRows() {
        measureWipe(atRows: 8_000)
    }

    /// The PRODUCTION path, and the one that decides whether any of this matters:
    /// Settings -> Reset Transactions on an 8 000-row ledger. That runs
    /// `TransactionResetService.reset`, which deletes one row at a time on the
    /// main thread — the same shape as the DEBUG seam that produced 131s.
    ///
    /// Driven through the UI rather than called directly, because the question is
    /// what a person experiences after tapping a button, not what a function costs
    /// in isolation.
    func test_measure_settingsResetTransactions_at8kRows() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD",
        ]
        app.launchArguments += [
            "--suppress-rating-prompt",
            "--seed-large-dataset",
            "--stall-monitor",
        ]
        app.launch()
        let proceed = app.buttons["Continue"]
        if proceed.waitForExistence(timeout: 10) { proceed.tap() }

        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 900),
                      "app never became ready while seeding")

        // Settings tab (index 4), then General.
        app.tabBars.buttons.element(boundBy: 4).tap()
        let general = app.buttons["General"].firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 60), "General row missing")
        general.tap()

        let reset = app.buttons["Reset Transactions"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 60), "Reset Transactions row missing")
        reset.tap()

        // Confirmation alert — the destructive button carries the same label.
        let confirm = app.alerts.buttons["Reset Transactions"].firstMatch
        if confirm.waitForExistence(timeout: 20) { confirm.tap() }

        // The success message is the moment the UI is usable again. Generous, so a
        // long freeze is measured rather than thrown away as a timeout.
        let done = app.staticTexts["All transactions were deleted."].firstMatch
        _ = done.waitForExistence(timeout: 900)
        app.terminate()
    }
}
