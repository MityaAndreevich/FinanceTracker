//
//  SplitAnalyticsReproTests.swift
//  FinanceTrackerUITests
//
//  Hands-on report #4 (2026-07-23): the split amount field (decimal pad — no
//  return key) had no keyboard-dismiss affordance, unlike AddTransactionView.
//  Guards the shared "Hide Keyboard" toolbar on the edit surface.
//

import XCTest

final class SplitAnalyticsReproTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func test_splitAmountField_showsKeyboardDismissToolbar() {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mode",
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()

        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20), "Transactions tab never appeared")
        txTab.tap()

        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", ", Expense, $")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no expense rows (demo seed missing)")
        row.tap()

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8), "editor did not open")

        let addPart = app.buttons["Add a part"]
        if !addPart.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(addPart.waitForExistence(timeout: 5), "'Add a part' missing")
        addPart.tap()

        // Focus the split amount field — the decimal pad comes up.
        let splitAmount = app.textFields["Amount"].firstMatch
        XCTAssertTrue(splitAmount.waitForExistence(timeout: 5), "split amount field missing")
        splitAmount.tap()

        // The shared dismiss affordance must sit above the keyboard…
        let hide = app.buttons["Hide Keyboard"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5),
                      "no 'Hide Keyboard' toolbar on the split amount field (report #4)")

        // …and actually dismiss it.
        hide.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5),
                      "keyboard still up after tapping Hide Keyboard")
    }
}
