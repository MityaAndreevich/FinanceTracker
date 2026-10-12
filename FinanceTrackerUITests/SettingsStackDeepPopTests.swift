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
