//
//  SearchRecomputationRegressionTests.swift
//  FinanceTrackerUITests
//
//  Regression guard for the 2026-07-25 freeze: typing one search query into the
//  Transactions list ran the whole filter 256 times and the day-grouping 252
//  times — ~1.6s of main-thread work at 8k rows, for ONE interaction.
//
//  Mechanism: `filtered` and `grouped` were computed properties (Swift caches
//  neither), `grouped` re-derived `filtered`, and BOTH `daySection` and
//  `dayHeader` indexed into `grouped` — so the cost scaled with the number of
//  rendered sections, not with the number of rows. Both are now computed once
//  per body evaluation in `body` and threaded down as values.
//
//  This asserts the COUNT, not the wall clock. A timing ceiling would be a
//  flaky proxy for a defect that is precisely a recomputation count: the
//  measured pre-fix and post-fix wall times (2203ms → 1565ms) differ by less
//  than simulator noise across machines, while the counts differ by ~50x. The
//  app dumps HangProbe's counters to /tmp under `--hangprobe-dump`.
//
//  MEASURED on this script (iPhone 17 Pro sim, 8k rows, ~1.1k split purchases):
//    before: Transactions.filtered = 256, Transactions.grouped = 252
//    after:  Transactions.filtered = 5,   Transactions.grouped = 5
//  The ceiling below sits an order of magnitude above "after" and well below
//  "before", so it survives render-count jitter without going blind.
//

import XCTest

final class SearchRecomputationRegressionTests: XCTestCase {

    /// Generous on purpose: the exact number of body evaluations SwiftUI spends
    /// on a search is not a contract, and pinning it would make this test a
    /// tripwire for unrelated view work. What IS a contract: the count must not
    /// scale with the number of rendered day sections. 40 is ~8x the observed
    /// post-fix value and ~6x below the pre-fix one.
    private let maxPasses = 40

    override func setUp() { continueAfterFailure = false }

    func test_search_doesNotRecomputeFilterPerSection() throws {
        try? FileManager.default.removeItem(atPath: "/tmp/hangprobe-counts.txt")

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
        app.launchArguments.append("--seed-large-dataset")
        app.launchArguments.append("--hangprobe-dump")
        app.launch()

        // A simulator holding a V1 store opens on the pre-migration consent
        // screen and waits for a tap; without this the test fails as "never
        // became ready", which reads exactly like the hang it guards.
        let proceed = app.buttons["Continue"]
        if proceed.waitForExistence(timeout: 10) { proceed.tap() }

        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 900),
                      "app never became ready")

        app.tabBars.buttons.element(boundBy: 1).tap()
        let anyRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 180), "Transactions list never showed rows")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 30), "search field missing")
        search.tap()
        search.typeText("Seed")

        expectation(for: NSPredicate(format: "value CONTAINS 'Seed'"), evaluatedWith: search)
        waitForExpectations(timeout: 180)

        let counts = try readCounts()
        let filtered = counts["Transactions.filtered"] ?? 0
        let grouped = counts["Transactions.grouped"] ?? 0

        XCTAssertGreaterThan(filtered, 0,
                             "probe recorded nothing — the dump seam is broken, not the fix")
        XCTAssertLessThanOrEqual(
            filtered, maxPasses,
            "the search filter ran \(filtered) times for one interaction. It is being "
            + "re-derived per rendered section again — check that `body` computes it once "
            + "and threads it into daySection/dayHeader."
        )
        XCTAssertLessThanOrEqual(
            grouped, maxPasses,
            "the day grouping ran \(grouped) times for one interaction (it re-derives the "
            + "filter each time, so this multiplies)."
        )
    }

    private func readCounts() throws -> [String: Int] {
        let text = try String(contentsOfFile: "/tmp/hangprobe-counts.txt", encoding: .utf8)
        var out: [String: Int] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=")
            guard parts.count == 2, let value = Int(parts[1]) else { continue }
            out[String(parts[0])] = value
        }
        return out
    }
}
