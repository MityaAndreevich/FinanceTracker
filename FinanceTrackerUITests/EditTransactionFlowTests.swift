//
//  EditTransactionFlowTests.swift
//  FinanceTrackerUITests
//
//  Reproduces + guards the "editing a transaction from the Transactions list is
//  broken" device report (QA round 2 #4). Drives the real flow: open the
//  Transactions tab, tap a row, change the amount, Save, and assert the list
//  reflects the new amount (persist + refresh end-to-end).
//

import XCTest

final class EditTransactionFlowTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func test_editAmountFromTransactionsList_persistsAndListReflects() {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mode",                 // seeds demo transactions (DEBUG only)
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        // Appended AFTER the array, never inside it: these launch args are
        // NSUserDefaults `-key value` pairs, and a lone extra dash-token in
        // the middle shifts that pairing. Keeps the StoreKit rating prompt (an
        // out-of-process window that covers the app and eats taps) from firing
        // mid-suite.
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()

        // Tabs: Dashboard(0), Transactions(1), +(2), Analytics(3), Settings(4).
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20), "Transactions tab never appeared")
        txTab.tap()

        // Tap the first transaction row. SwiftUI exposes each row as a button
        // labelled "Merchant, Type, $amount" — target that, not `cells` (whose
        // index 0 can be a section header / inline hint, not a tappable row).
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", ", Expense, $", ", Income, $")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "no transaction rows in the list (demo seed missing / out of period)")
        row.tap()

        // (a) Did tapping a row open the editor? Save button is unique to it.
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8),
                      "tapping a row did NOT open the editor (Save button missing)")

        // Change the amount to a distinctive value.
        let amountField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "amount field missing in editor")
        amountField.tap()
        if let existing = amountField.value as? String, !existing.isEmpty {
            amountField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        amountField.typeText("77777")

        saveButton.tap()

        // (b)+(c) Back on the list, the edited amount must be visible.
        // USD formatting → "$77,777.00" (expense row renders "-$77,777.00").
        let updated = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "77,777")
        ).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 8),
                      "list did NOT reflect the edited amount — Save failed to persist or the list didn't refresh")
    }
}
