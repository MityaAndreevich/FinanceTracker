//
//  SettingsStackDeepPopTests.swift
//  FinanceTrackerUITests
//
//  Regression guard for Round 9 R1 (fb9c075, 2026-06-27): "returning from Help →
//  tap General → no response". Settings then used NavigationStack(path:) while
//  its rows pushed with destination-based NavigationLinks. A bound path only
//  tracks value-based links, so after a deep pop (article → back → back) the
//  stack and the empty path disagreed and froze further navigation.
//
//  Written 2026-10-11, BEFORE the Guide converts the Settings stack to a bound
//  path with value-based routes (DESIGN_USER_GUIDE §7). That conversion
//  re-enters the exact territory R1 came from. The fix was only "verified" by
//  hand in June. This test is what holds it now.
//
//  Commissioned red against the R1 shape (a bound path over destination links)
//  before it was trusted. See STATE §13.7.
//

import XCTest

final class SettingsStackDeepPopTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Settings → Learn & Tips → an article → back → back → General must open.
    /// Three cycles: the original report needed repeated Help visits.
    func test_afterDeepPopFromHelpArticle_generalStillOpens() {
        let app = launch()

        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "Settings tab never appeared")
        settingsTab.tap()

        let general = app.buttons["settings_general_row"]
        let learn = app.buttons["settings_learn_tips_row"]
        let article = app.buttons["help_article_row_quickAdd"]
        let articleView = app.descendants(matching: .any)["help_article_view"]
        let languageRow = app.descendants(matching: .any)["settings.language.row"]

        for cycle in 1...3 {
            XCTAssertTrue(learn.waitForExistence(timeout: 8), "cycle \(cycle): Learn & Tips row missing")
            learn.tap()

            XCTAssertTrue(article.waitForExistence(timeout: 8), "cycle \(cycle): article row missing")
            article.tap()
            XCTAssertTrue(articleView.waitForExistence(timeout: 8), "cycle \(cycle): article never opened")

            backOnce(app)   // → Learn & Tips
            XCTAssertTrue(article.waitForExistence(timeout: 8), "cycle \(cycle): not back on Learn & Tips")
            backOnce(app)   // → Settings root
            XCTAssertTrue(general.waitForExistence(timeout: 8), "cycle \(cycle): not back on Settings")

            // THE R1 ASSERTION: General is present AND opens.
            general.tap()
            XCTAssertTrue(languageRow.waitForExistence(timeout: 8),
                          "cycle \(cycle): General did not open after a deep pop from a Help article (R1)")
            backOnce(app)
        }
    }

    /// The tab-leave reset is the other half of the design: leave Settings while
    /// an article is pushed, come back, and the stack must be a working root.
    func test_leavingTabWhileDeep_thenGeneralStillOpens() {
        let app = launch()
        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "Settings tab never appeared")

        for cycle in 1...3 {
            settingsTab.tap()
            let learn = app.buttons["settings_learn_tips_row"]
            XCTAssertTrue(learn.waitForExistence(timeout: 8), "cycle \(cycle): Settings did not open at its root")
            learn.tap()
            let article = app.buttons["help_article_row_quickAdd"]
            XCTAssertTrue(article.waitForExistence(timeout: 8), "cycle \(cycle): article row missing")
            article.tap()
            XCTAssertTrue(app.descendants(matching: .any)["help_article_view"].waitForExistence(timeout: 8),
                          "cycle \(cycle): article never opened")

            dashboardTab.tap()
            settingsTab.tap()

            let general = app.buttons["settings_general_row"]
            XCTAssertTrue(general.waitForExistence(timeout: 8),
                          "cycle \(cycle): returning to Settings did not land on its root")
            general.tap()
            XCTAssertTrue(app.descendants(matching: .any)["settings.language.row"].waitForExistence(timeout: 8),
                          "cycle \(cycle): General did not open after leaving the tab while deep")
            dashboardTab.tap()
        }
    }

    /// Every route on the Settings stack lands on its own screen. With value
    /// links, a route whose destination is not registered on the stack does
    /// NOTHING when tapped, silently. This test is what catches that.
    /// (`SettingsRoute.tip` is not driven: which tips are revealed depends on the
    /// per-user deck and the day.)
    func test_everySettingsRoute_opensItsScreen() {
        let app = launch()
        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "Settings tab never appeared")
        settingsTab.tap()

        let rows: [(row: String, title: String)] = [
            ("settings_general_row", "General"),
            ("settings_premium_row", "Premium"),
            ("settings_data_row", "Data"),
            ("settings_categories_row", "Categories & Accounts"),
            ("settings_recurring_row", "Recurring"),
            ("settings_privacy_row", "Privacy"),
            ("settings_alerts_row", "Alerts"),
            ("settings_reports_row", "Reports"),
            ("settings_learn_tips_row", "Learn & Tips"),
            ("settings_setup_guide_row", "Set up Widget & Siri"),
            ("settings_about_row", "About"),
        ]
        for (rowID, title) in rows {
            let row = app.buttons[rowID]
            reveal(row, in: app)
            row.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8),
                          "\(rowID) did not open '\(title)'")
            backOnce(app)
        }

        // Second level: the Reports bell, and an article from the Setup guide.
        let reportsRow = app.buttons["settings_reports_row"]
        reveal(reportsRow, in: app)
        reportsRow.tap()
        let bell = app.buttons["Automatic reports"]
        XCTAssertTrue(bell.waitForExistence(timeout: 8), "Reports bell missing")
        bell.tap()
        XCTAssertTrue(app.navigationBars["Automatic reports"].waitForExistence(timeout: 8),
                      "Reports bell (Settings stack) did not open Automatic reports")
        backOnce(app)
        backOnce(app)

        let setup = app.buttons["settings_setup_guide_row"]
        reveal(setup, in: app)
        setup.tap()
        let widgetArticle = app.buttons["Widget"]
        XCTAssertTrue(widgetArticle.waitForExistence(timeout: 8), "Setup guide's Widget row missing")
        widgetArticle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["help_article_view"].waitForExistence(timeout: 8),
                      "Setup guide article did not open")
    }

    /// The same bell inside `ReportsScreen`, the sheet Analytics opens. That stack
    /// is not the Settings stack, so it must register the routes itself.
    func test_reportsSheetBell_opensReportsSettings() {
        let app = launch()
        let analyticsTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(analyticsTab.waitForExistence(timeout: 15), "Analytics tab never appeared")
        analyticsTab.tap()
        let open = app.buttons["analytics_open_report"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "Analytics' report button missing")
        open.tap()
        let bell = app.buttons["Automatic reports"]
        XCTAssertTrue(bell.waitForExistence(timeout: 8), "Reports bell missing in the sheet")
        bell.tap()
        XCTAssertTrue(app.navigationBars["Automatic reports"].waitForExistence(timeout: 8),
                      "Reports bell (sheet) did not open Automatic reports")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<3 where !element.exists { app.swipeUp() }
        for _ in 0..<4 where !element.exists { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 4), "\(element) not found in the Settings list")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)"
        ]
        // After the array, never inside it (see LanguageSwitchTests).
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()
        return app
    }

    private func backOnce(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 8), "no back button")
        back.tap()
    }
}
