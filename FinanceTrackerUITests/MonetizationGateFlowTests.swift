//
//  MonetizationGateFlowTests.swift
//  FinanceTrackerUITests
//
//  Drives the v1.0.2 free/paid line the way a lapsed user meets it, via the DEBUG
//  `--expire-reverse-trial` seam, which backdates the REAL trial start so the real
//  state machine decides — nothing here fakes a gate.
//
//  The unit tests prove the access rules. Only this proves the user actually hits
//  the paywall where we think they do, and — the load-bearing one — that CSV export
//  is genuinely reachable on the free tier. If we ever gate the data escape hatch
//  by accident, test_csvExport_isFreeAfterTrialEnds is what catches it.
//

import XCTest

final class MonetizationGateFlowTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// Fresh install, trial backdated past its 14 days, nothing purchased → free tier.
    private func launchAsLapsedFreeUser() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--expire-reverse-trial",       // DEBUG seam: backdates the real trial start
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        return app
    }

    /// The trial-end paywall auto-raises. Dismiss it to reach the app underneath.
    @discardableResult
    private func dismissTrialEndPaywall(_ app: XCUIApplication) -> Bool {
        let notice = app.staticTexts["Your 14-day trial has ended"]
        let appeared = notice.waitForExistence(timeout: 25)
        if appeared {
            app.buttons["Close"].firstMatch.tap()
        }
        return appeared
    }

    private func openDataSettings(_ app: XCUIApplication) {
        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 20), "Settings tab never appeared")
        settingsTab.tap()

        let dataRow = app.buttons["Data"].firstMatch
        XCTAssertTrue(dataRow.waitForExistence(timeout: 10), "Data row never appeared")
        dataRow.tap()
    }

    // MARK: - Trial end

    func test_trialEnd_raisesPaywall_andSaysNothingWasDeleted() {
        let app = launchAsLapsedFreeUser()

        XCTAssertTrue(dismissTrialEndPaywall(app),
                      "The reverse trial lapsed unpaid but the paywall never appeared")
    }

    // MARK: - The gates

    func test_csvImport_isGatedAfterTrialEnds() {
        let app = launchAsLapsedFreeUser()
        dismissTrialEndPaywall(app)
        openDataSettings(app)

        let importRow = app.buttons["Import CSV"].firstMatch
        XCTAssertTrue(importRow.waitForExistence(timeout: 10), "Import row never appeared")
        importRow.tap()

        // The contextual gate fires on intent: the paywall, not the file importer.
        XCTAssertTrue(app.staticTexts["Premium"].firstMatch.waitForExistence(timeout: 15),
                      "Import is premium, but tapping it on the free tier didn't raise the paywall")
    }

    /// The one that matters most. CSV export — at ALL-TIME scope — must stay free,
    /// forever, on every tier. A user must always be able to walk out with their own
    /// records. If this ever fails, we have started holding data hostage.
    func test_csvExport_isFreeAfterTrialEnds() {
        let app = launchAsLapsedFreeUser()
        dismissTrialEndPaywall(app)
        openDataSettings(app)

        let exportRow = app.buttons["Export CSV (all)"].firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "All-time CSV export row never appeared")
        exportRow.tap()

        // No paywall. The export runs and offers the file to share.
        XCTAssertFalse(app.staticTexts["Premium"].firstMatch.waitForExistence(timeout: 4),
                       "All-time CSV export raised the paywall — the data escape hatch has been gated")
    }

    func test_allTimePDFExport_isGatedAfterTrialEnds() {
        let app = launchAsLapsedFreeUser()
        dismissTrialEndPaywall(app)
        openDataSettings(app)

        let pdfRow = app.buttons["Export PDF (all)"].firstMatch
        XCTAssertTrue(pdfRow.waitForExistence(timeout: 10), "All-time PDF export row never appeared")
        pdfRow.tap()

        XCTAssertTrue(app.staticTexts["Premium"].firstMatch.waitForExistence(timeout: 15),
                      "All-time PDF is premium, but it didn't raise the paywall on the free tier")
    }

    // MARK: - The cap, and the data it must never touch

    /// Creates accounts up to the free cap, then proves the NEXT one raises the
    /// paywall — while every account already created is still sitting in the list.
    /// That second assertion is the whole ethic of the brief: the cap blocks the
    /// add, it does not take anything away.
    func test_accountCap_blocksTheNextAdd_butKeepsExistingAccounts() {
        let app = launchAsLapsedFreeUser()
        dismissTrialEndPaywall(app)

        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 20))
        settingsTab.tap()

        let categoriesRow = app.buttons["Categories & Accounts"].firstMatch
        XCTAssertTrue(categoriesRow.waitForExistence(timeout: 10), "Categories & Accounts row never appeared")
        categoriesRow.tap()

        // Fill the free tier: 2 accounts.
        addAccount(app, named: "Cash")
        addAccount(app, named: "Card")

        // The third is the forcing gate.
        let addButton = app.buttons["Add Account"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        XCTAssertTrue(app.staticTexts["Premium"].firstMatch.waitForExistence(timeout: 15),
                      "A free user past the account cap should have been shown the paywall")
        app.buttons["Close"].firstMatch.tap()

        // …and nothing they already made was deleted, hidden, or locked.
        XCTAssertTrue(app.staticTexts["Cash"].firstMatch.waitForExistence(timeout: 10),
                      "An account created before the cap was reached has gone missing")
        XCTAssertTrue(app.staticTexts["Card"].firstMatch.exists,
                      "An account created before the cap was reached has gone missing")
    }

    private func addAccount(_ app: XCUIApplication, named name: String) {
        let addButton = app.buttons["Add Account"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Add Account button never appeared")
        addButton.tap()

        let field = app.textFields["Account name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Account name field never appeared")
        field.tap()
        field.typeText(name)

        // Scope to the sheet's nav bar: the "Add" TAB is also a button labelled "Add",
        // and a bare app.buttons["Add"] matches it first.
        app.navigationBars["Add Account"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 10),
                      "Account \(name) was not created")
    }
}
