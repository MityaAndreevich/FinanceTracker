//
//  PoisonedAnalyticsJourneyTests.swift
//  FinanceTrackerUITests
//
//  DESIGN_REPORTS_1_0_6.md §10.3 — the journey the D5 fix exists for:
//
//    cold launch with an unsummable ledger → Analytics (Pulse, Breakdown,
//    Horizon) each render the unavailable card → Reports (from the Analytics
//    toolbar) → week, month, year each render the card → Share → PDF produces
//    a file (the share row appears)
//
//  Presence assertions only (rule 4): the card's TITLE must exist on every
//  screen, and the share row must APPEAR. Before 1.0.6 the Analytics tab
//  trapped the process on this ledger one tap after the dashboard had said
//  everything else was fine — which is why that sentence was deleted.
//
//  COMMISSIONED RED 2026-09-21 against the pre-D5 AnalyticsSeries: the process
//  died on the Analytics tab (recorded in the Phase 1 report).
//
//  Erased simulator: several UI suites pass from an erased simulator and fail
//  from a dirty one (scripts/run-tests.sh:161).
//

import XCTest

final class PoisonedAnalyticsJourneyTests: XCTestCase {

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
        app.launchArguments.append("--poison-amounts")
        app.launch()
        return app
    }

    private static let cardTitle = "These totals can't be shown"

    func test_analyticsAndReports_showUnavailable_neverTrap_andPDFExportsAnyway() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        // Analytics tab: all three sub-screens.
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertEqual(app.state, .runningForeground, "Analytics trapped on the poisoned ledger")
        let card = app.staticTexts[Self.cardTitle]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Analytics did not show the unavailable card")

        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "the Pulse/Breakdown/Horizon picker is missing")
        for index in [1, 2, 0] {
            picker.buttons.element(boundBy: index).tap()
            XCTAssertEqual(app.state, .runningForeground, "Analytics sub-screen \(index) trapped")
            XCTAssertTrue(app.staticTexts[Self.cardTitle].waitForExistence(timeout: 10),
                          "Analytics sub-screen \(index) did not show the unavailable card")
        }

        // Reports, from the Analytics toolbar.
        let open = app.buttons["analytics_open_report"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), "the Reports entry point is missing from Analytics")
        open.tap()
        let kindPicker = app.segmentedControls["reports_kind_picker"]
        XCTAssertTrue(kindPicker.waitForExistence(timeout: 10), "the Reports screen did not open")
        XCTAssertTrue(app.staticTexts[Self.cardTitle].waitForExistence(timeout: 15),
                      "the month report did not show the unavailable card")

        for (index, name) in [(0, "week"), (2, "year")] {
            kindPicker.buttons.element(boundBy: index).tap()
            XCTAssertEqual(app.state, .runningForeground, "the \(name) report trapped")
            XCTAssertTrue(app.staticTexts[Self.cardTitle].waitForExistence(timeout: 15),
                          "the \(name) report did not show the unavailable card")
        }

        // Share → PDF still produces a file: the rows are representable, only their
        // sum is not, and the PDF says so on its first page.
        kindPicker.buttons.element(boundBy: 1).tap()   // month: free export, no paywall
        let share = app.buttons["reports_share_menu"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        let pdf = app.buttons["PDF report"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 5), "the share menu did not open")
        pdf.tap()
        XCTAssertTrue(app.otherElements["reports_share_link"].waitForExistence(timeout: 15)
                      || app.buttons["reports_share_link"].waitForExistence(timeout: 5),
                      "no share row appeared — the PDF was not produced")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
