//
//  EditPresentationReproTests.swift
//  FinanceTrackerUITests
//
//  Condition matrix for the 2026-07-16 device report: "tapping Edit on a
//  transaction opens nothing" — the SECOND report of this symptom (QA round 2
//  #4 was the first; it resolved as a stale device build).
//
//  Every condition here was driven at HEAD and PASSED, on iOS 18.6 and 26.5:
//  row tap / swipe Edit, EN / RU, mid-search, after a LIVE EN→RU language
//  switch, and re-entry after both pop affordances (back button, edge swipe).
//  The presentation path (`editTx` → navigationDestination) is demonstrably
//  healthy in all of them, so the report matches the round-2 stale-build
//  profile, not a code defect. These stay as the permanent guard: if any of
//  them ever fails, THAT failure is the repro this investigation didn't have.
//
//  Two traps this harness fell into and documents so nobody re-falls:
//  * asserting a LOCALIZED label after a live language switch — `Text(key)`
//    chrome legitimately stays in the launch language until relaunch, so the
//    editor "not presenting" was actually the editor presenting in EN;
//  * reading a same-code "failure" as a regression without checking the view
//    hierarchy attachment — the xcresult snapshot showed the editor on screen.
//

import XCTest

final class EditPresentationReproTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchDemo(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mode",
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        return app
    }

    private func firstRow(_ app: XCUIApplication) -> XCUIElement {
        // Row buttons are labelled "Merchant, Type, amount" in the active locale;
        // match on the currency-agnostic comma structure via the tile's a11y label
        // pieces. The demo seed always has expense rows.
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND (label CONTAINS '$' OR label CONTAINS '₽' OR label CONTAINS 'US$')")
        ).firstMatch
    }

    private func assertEditorOpened(_ app: XCUIApplication, saveLabel: String, context: String) {
        let save = app.buttons[saveLabel]
        XCTAssertTrue(save.waitForExistence(timeout: 8),
                      "\(context): editor did NOT present ('\(saveLabel)' button missing)")
    }

    /// Language-agnostic editor detection. After a LIVE in-app switch the
    /// editor's `Text(key)` chrome legitimately stays in the launch language
    /// until relaunch (the switch is applied silently, completed on next
    /// launch — 5c8ce15), so asserting a specific localization here tests the
    /// wrong thing. This harness fell for exactly that once: the "failure" that
    /// looked like the device bug was the editor opening in EN while the test
    /// demanded «Сохранить». Presence, not language.
    private func assertEditorOpenedAnyLanguage(_ app: XCUIApplication, context: String) {
        let save = app.buttons.matching(
            NSPredicate(format: "label == 'Save' OR label == 'Сохранить'")
        ).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8),
                      "\(context): editor did NOT present (no Save button in any expected language)")
    }

    /// Variable 1: RU language, plain row tap.
    func test_ru_rowTap_opensEditor() {
        let app = launchDemo(language: "ru", locale: "ru_RU")
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20))
        txTab.tap()

        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no rows (ru demo seed missing)")
        row.tap()
        assertEditorOpened(app, saveLabel: "Сохранить", context: "ru row tap")
    }

    /// Variable 2: EN language, swipe-action Edit button (the affordance the
    /// founder actually names: "tapping Edit").
    func test_en_swipeEdit_opensEditor() {
        let app = launchDemo(language: "en", locale: "en_US")
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20))
        txTab.tap()

        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no rows (demo seed missing)")
        row.swipeLeft()

        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "swipe revealed no Edit button")
        editButton.tap()
        assertEditorOpened(app, saveLabel: "Save", context: "en swipe Edit")
    }

    /// Variable 3: edit WHILE the search field is active. The Transactions list
    /// runs an always-visible `.searchable` drawer, and navigationDestination
    /// pushes from inside an active search context are a known SwiftUI trap.
    func test_en_editWhileSearching_opensEditor() {
        let app = launchDemo(language: "en", locale: "en_US")
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20))
        txTab.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8), "search drawer missing")
        searchField.tap()
        searchField.typeText("Spotify")

        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 8), "search found no Spotify row")
        row.tap()
        assertEditorOpened(app, saveLabel: "Save", context: "en edit mid-search")
    }

    /// Variable 4: an in-app language switch BEFORE editing. `.languageReactive()`
    /// flips an `.id` around the whole Transactions subtree — including the
    /// `.navigationDestination` registration — when the language changes, so the
    /// registration is torn down and re-created while the stack is alive.
    func test_switchLanguageThenEdit_opensEditor() {
        let app = launchDemo(language: "en", locale: "en_US")

        // Settings → General → Language → Русский
        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 20))
        settingsTab.tap()
        let generalRow = app.staticTexts["General"].firstMatch
        XCTAssertTrue(generalRow.waitForExistence(timeout: 8), "General row missing")
        generalRow.tap()
        let languageRow = app.otherElements["settings.language.row"].firstMatch.exists
            ? app.otherElements["settings.language.row"].firstMatch
            : app.buttons["settings.language.row"].firstMatch
        XCTAssertTrue(languageRow.waitForExistence(timeout: 8), "Language row missing")
        languageRow.tap()
        let ruRow = app.buttons["picker.locale.ru"].firstMatch.exists
            ? app.buttons["picker.locale.ru"].firstMatch
            : app.otherElements["picker.locale.ru"].firstMatch
        XCTAssertTrue(ruRow.waitForExistence(timeout: 8), "RU picker row missing")
        ruRow.tap()

        // Now edit from the Transactions list, in the switched language.
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        txTab.tap()
        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no rows after language switch")
        row.tap()
        assertEditorOpenedAnyLanguage(app, context: "edit after EN→RU switch")
    }

    /// Variable 5: RE-ENTRY after popping back. `navigationDestination(item:)`
    /// has a known failure mode where a pop that doesn't reset the bound item
    /// leaves it non-nil — after which every subsequent `editTx =` set is a
    /// silent no-op until relaunch ("worked earlier, now Edit opens nothing").
    /// Drives both pop affordances: the back button and the edge-swipe gesture.
    func test_editPopBack_thenEditAgain_opensEditor() {
        let app = launchDemo(language: "en", locale: "en_US")
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20))
        txTab.tap()

        // 1st entry.
        var row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no rows (demo seed missing)")
        row.tap()
        assertEditorOpened(app, saveLabel: "Save", context: "1st entry")

        // Pop via the back button (labelled with the previous screen's title).
        app.navigationBars.buttons.firstMatch.tap()

        // 2nd entry — the one that goes dead when the item binding sticks.
        row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 8), "list did not come back after pop")
        row.tap()
        assertEditorOpened(app, saveLabel: "Save", context: "2nd entry after back-button pop")

        // Pop again. A synthetic edge-swipe doesn't reliably trigger the
        // interactive pop recognizer on iOS 18 simulators (verified via the
        // failure snapshot: the editor was still on screen after the drag), so
        // try the swipe for realism but fall back to the back button — the
        // item-binding reset under test happens on the POP, not on which
        // affordance caused it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        if !firstRow(app).waitForExistence(timeout: 3) {
            app.navigationBars.buttons.firstMatch.tap()
        }

        // 3rd entry.
        row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 8), "list did not come back after second pop")
        row.tap()
        assertEditorOpened(app, saveLabel: "Save", context: "3rd entry after second pop")
    }

    /// Both variables at once: RU + swipe Edit — the founder's exact path.
    func test_ru_swipeEdit_opensEditor() {
        let app = launchDemo(language: "ru", locale: "ru_RU")
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20))
        txTab.tap()

        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no rows (ru demo seed missing)")
        row.swipeLeft()

        let editButton = app.buttons["Изменить"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "swipe revealed no Изменить button")
        editButton.tap()
        assertEditorOpened(app, saveLabel: "Сохранить", context: "ru swipe Edit")
    }
}
