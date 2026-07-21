//
//  SplitPickerPresentationTests.swift
//  FinanceTrackerUITests
//
//  Reproduces + guards the 1.0.3 blocker: tapping "Pick a category" on a split
//  row presented the CategoryPickerSheet and it immediately slid down again —
//  a presentation torn down the instant it appeared, so a split could never be
//  completed. The tap deliberately happens WITHOUT touching the amount field
//  first, so a keyboard-dismissal race cannot explain a failure here.
//

import XCTest

final class SplitPickerPresentationTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func test_splitCategoryPicker_staysPresented_andPicks() {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mode",                 // seeds demo transactions (DEBUG only)
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        // Appended AFTER the array, never inside it (see EditTransactionFlowTests).
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()

        // Tabs: Dashboard(0), Transactions(1), +(2), Analytics(3), Settings(4).
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20), "Transactions tab never appeared")
        txTab.tap()

        // The split section is expense-only — target an Expense row.
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", ", Expense, $")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "no expense rows in the list (demo seed missing / out of period)")
        row.tap()

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8),
                      "tapping a row did NOT open the editor (Save button missing)")

        // Add a split part. The row may need scrolling into view inside the Form.
        let addPart = app.buttons["Add a part"]
        if !addPart.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(addPart.waitForExistence(timeout: 5), "split 'Add a part' button missing")
        addPart.tap()

        // Tap "Pick a category" WITHOUT typing an amount first — no keyboard in play.
        let pick = app.buttons["Pick a category"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "split row's 'Pick a category' button missing")
        pick.tap()

        // The shared picker sheet must appear…
        let pickerTitle = app.navigationBars["Choose category"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5),
                      "CategoryPickerSheet never appeared after tapping the split row's picker button")

        // …and STAY. The bug: it slid down by itself right after appearing.
        sleep(3)
        XCTAssertTrue(pickerTitle.exists,
                      "CategoryPickerSheet dismissed itself — split category can never be chosen (the 1.0.3 blocker)")

        // Complete the flow: pick a known seeded expense category and verify it
        // landed on the row. NEVER firstMatch here — that grabs the "Sheet
        // Grabber" drag handle, not a category row.
        let categoryRow = app.buttons["Food & Drink"].exists
            ? app.buttons["Food & Drink"]
            : app.buttons["Coffee"]
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 5), "no known category row inside the picker sheet")
        categoryRow.tap()

        XCTAssertTrue(pickerTitle.waitForNonExistence(timeout: 5),
                      "picker did not dismiss after a category was chosen")
        XCTAssertFalse(app.buttons["Pick a category"].waitForExistence(timeout: 3),
                       "split row still shows 'Pick a category' — the chosen category did not land on the draft")
    }
}
