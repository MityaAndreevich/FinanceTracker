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
//  audit exists to clean up. What IS asserted is that the run measured
//  something — see `assertLedgerWasActuallySeeded`.
//
//  REPAIRED 2026-08-08 (F1). Until now this vehicle had never produced a real
//  measurement, and it had three independent ways of saying so quietly:
//
//    1. It never scrolled, so the Reset row — last in a long `Form` — was not in
//       the accessibility tree and `waitForExistence` failed for 60 s against a
//       screen that was rendering fine. This was the visible failure.
//    2. It looked for an alert button labelled "Reset Transactions". The
//       destructive button is "Reset"; only the alert TITLE carries the longer
//       string. The lookup was guarded by `if` and the final wait discarded with
//       `_ =`, so fixing (1) alone would have produced a test that tapped the
//       row, never confirmed, and PASSED while performing no reset at all.
//    3. `--seed-large-dataset` had been throwing since 2026-08-04 (3ba801a, NOT
//       since V2 — the multi-config container predates it by two weeks but the
//       seam did not use the bulk API until then). `delete(model:)` cannot
//       resolve an entity in a multi-configuration container; the throw was
//       caught and reported via `print`, which xcodebuild does not capture.
//       The seam could no longer establish or reset the ledger, so the store was
//       whatever history had left in it — a real 8k ledger on a simulator
//       carrying pre-08-04 leftovers, and EMPTY on a freshly erased one.
//
//  All three are fixed, and each now has an assertion standing where the silence
//  used to be. First real numbers, iPhone 17 Pro simulator, 8 000 rows:
//
//      launch-seams   observedMs=15074  blockedPct=99.7  longestGapMs=15074
//      settings-reset observedMs=6667   blockedPct=99.3  longestGapMs=6667
//
//  The reset is ONE unbroken 6.7-second gap — not many small ones. That is a
//  single main-thread block with no runloop turn in it, which is watchdog
//  territory on a cold path.
//

import XCTest

final class BulkDeleteStallMeasurementTests: XCTestCase {

    private static let reportPath = "/tmp/stall-report.txt"

    /// Byte offset of the report file when the test started, so only THIS run's
    /// lines are read back. Deleting the file instead would discard whatever a
    /// concurrently-running measurement had already written.
    private func reportOffset() -> UInt64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.reportPath)
        return (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func reportTail(from offset: UInt64) -> String {
        guard let data = FileManager.default.contents(atPath: Self.reportPath),
              data.count > Int(offset) else { return "" }
        return String(decoding: data.suffix(from: Int(offset)), as: UTF8.self)
    }

    /// THE GUARD THAT WAS MISSING. Both tests here depend on
    /// `--seed-large-dataset`, and that seam threw on every call from 2026-08-04
    /// to 2026-08-08 — `delete(model:)` cannot resolve an entity in a
    /// multi-configuration container, the throw was caught, and the only report of
    /// it was a `print` that xcodebuild does not capture. The vehicle then ran
    /// against whatever the store happened to hold: an empty ledger on a clean
    /// simulator, stale leftovers on a dirty one. Both pass silently.
    ///
    /// A measurement vehicle must fail when it measures nothing. It now asserts
    /// the seam's own outcome line, read back out of the shared /tmp channel.
    private func assertLedgerWasActuallySeeded(from offset: UInt64,
                                               file: StaticString = #filePath,
                                               line: UInt = #line) {
        let tail = reportTail(from: offset)
        XCTAssertTrue(
            tail.contains("NOTE seed-large-dataset target=8000 landed=8000"),
            """
            the 8 000-row ledger was never established, so any number this run \
            produced is a measurement of an empty store. Report tail:
            \(tail.isEmpty ? "<nothing written>" : tail)
            """,
            file: file, line: line
        )
    }

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
        // ask for scale purges a leftover seeded ledger first (fetch-and-delete
        // as of 2026-08-08; it was `delete(model:)`, which threw) — so the
        // row-by-row loop would find an empty table and measure nothing. The
        // fixed seam order (purge -> seed -> duplicates)
        // is what makes "establish 8k rows, THEN wipe them row by row" sayable in
        // a single launch, which is also the shape a real user's Reset or
        // Delete-all takes.
        let offset = reportOffset()
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
        assertLedgerWasActuallySeeded(from: offset)
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
        let offset = reportOffset()
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

        // SCROLL. Reset Transactions is the LAST control in a long General form
        // (language, currency, appearance, restart onboarding, then reset), and an
        // unrealized `Form` row is not in the accessibility tree — so
        // `waitForExistence` legitimately failed for 60 s against a screen that was
        // rendering perfectly. This was defect 1 of 2 in F1; scroll occlusion is
        // already on this project's documented harness-trap list.
        let reset = app.buttons["Reset Transactions"].firstMatch
        var swipes = 0
        while !reset.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(reset.waitForExistence(timeout: 60),
                      "Reset Transactions row missing after \(swipes) swipes")
        reset.tap()

        // CONFIRMATION. The destructive button is labelled "Reset"
        // (`general.alert.reset`) — only the alert TITLE is "Reset Transactions?".
        // This was defect 2, and it was the dangerous one: the old lookup was for
        // "Reset Transactions", guarded by `if`, with the final wait discarded via
        // `_ =`. Once defect 1 was fixed this test would have tapped the row, never
        // confirmed, never performed the reset, and PASSED while measuring nothing.
        // A measurement vehicle that reports success without performing the
        // operation is worse than one that fails, so every step below asserts.
        let confirm = app.alerts.buttons["Reset"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 20),
                      "confirmation alert never appeared — nothing was measured")
        confirm.tap()

        // The success message is the moment the UI is usable again. Generous, so a
        // long freeze is measured rather than thrown away as a timeout — but
        // ASSERTED, so a reset that never completed cannot read as a fast one.
        let done = app.staticTexts["All transactions were deleted."].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 900),
                      "the reset never reported completion — the measurement is void")
        assertLedgerWasActuallySeeded(from: offset)
        app.terminate()
    }
}
