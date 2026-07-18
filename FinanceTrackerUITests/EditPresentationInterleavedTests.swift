//
//  EditPresentationInterleavedTests.swift
//  FinanceTrackerUITests
//
//  The repro EditPresentationReproTests could not have caught. That matrix opens
//  and dismisses the editor on FRESH state and is green — which is exactly why it
//  missed the 2026-07-17 device bug: the editor push was never broken on a clean
//  cycle. It broke when the presentation state was disturbed BETWEEN cycles.
//
//  Device evidence (EditPresentation os_log): the stuck cycle interleaved with
//  QuickAdd saves and a climbing periodCount, and never logged the `→nil` reset.
//  The old `navigationDestination(item: $editTx)` was cleared only as a side
//  effect of SwiftUI's own pop, so a route that took the destination off screen
//  without a tracked pop left the item non-nil forever — and because that
//  modifier presents on nil→value only, every later Edit tap was a silent no-op.
//
//  These tests drive that interleaving: open the editor, disturb the state (the
//  "+" tab bounce, which momentarily selects tag 2 and presents QuickEntry over
//  the stack, plus a real save that rebuilds the list), then edit AGAIN.
//

import XCTest

final class EditPresentationInterleavedTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mode",
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        // Appended AFTER the array — see the note in EditPresentationReproTests.
        // The StoreKit rating prompt is an out-of-process window that eats taps,
        // and it fires on a save COUNT shared across the whole suite, so a test
        // that saves (as these do) is a prime victim without this.
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()
        return app
    }

    private func transactionsTab(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons.element(boundBy: 1)
    }

    private func firstRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND (label CONTAINS '$' OR label CONTAINS 'US$')")
        ).firstMatch
    }

    private func assertEditorOpened(_ app: XCUIApplication, _ context: String) {
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 8),
                      "\(context): editor did NOT present (no Save button)")
    }

    private func popEditor(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 8),
                      "list did not come back after pop")
    }

    /// Opens the editor from the long-press context menu — the second Edit
    /// affordance the device report named.
    ///
    /// Swipe-action Edit is NOT driven repeatedly here, deliberately. Two harness
    /// traps make a repeated synthetic swipe on this List lie about the product:
    /// the trailing actions are `allowsFullSwipe: true` with the destructive
    /// Delete FIRST, so a full-travel `swipeLeft()` fires Delete and its alert;
    /// and a gentle/slow swipe is resolved as a TAP on the row button, which
    /// opens the editor by the other path. Both then surface as "no swipe Edit"
    /// while the product is fine. Swipe-Edit's own coverage lives in
    /// EditPresentationReproTests (`test_en_swipeEdit_opensEditor`,
    /// `test_ru_swipeEdit_opensEditor`) on a fresh list, where a plain swipe is
    /// unambiguous; what THIS file adds is repeated cycles in one session.
    private func contextMenuEdit(_ app: XCUIApplication, cycle: Int) {
        firstRow(app).press(forDuration: 1.0)
        let menuEdit = app.buttons["Edit"]
        XCTAssertTrue(menuEdit.waitForExistence(timeout: 5), "cycle \(cycle): no context Edit")
        menuEdit.tap()
    }

    /// Saves one transaction through the "+" tab. This is the disturbance: the
    /// tab selection bounces 1→2→1 (ContentView restores `oldTab`) while
    /// QuickEntry presents ABOVE the whole TabView, and the resulting insert
    /// rebuilds the period-scoped @Query behind it.
    private func quickAddSave(_ app: XCUIApplication, _ text: String) {
        app.tabBars.buttons.element(boundBy: 2).tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "QuickEntry input missing")
        field.tap()
        field.typeText(text)

        // Save lives in the keyboard accessory bar; match on label so we don't
        // depend on placement.
        let save = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Save'")
        ).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8), "QuickEntry Save missing")
        // The parse is debounced, so Save is briefly present-but-disabled. Wait for
        // it rather than sampling `isEnabled` immediately (that raced, and read as
        // "did not parse" on a perfectly good input).
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"),
                                  evaluatedWith: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed,
                       "QuickEntry never enabled Save for '\(text)'")
        save.tap()

        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 10),
                      "did not return to the transactions list after QuickAdd save")
    }

    /// THE REPRO: edit → dismiss → QuickAdd insert (list rebuild) → edit again.
    func test_editAfterQuickAddInsert_stillOpensEditor() {
        let app = launchDemo()
        XCTAssertTrue(transactionsTab(app).waitForExistence(timeout: 20))
        transactionsTab(app).tap()

        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 15), "no rows (demo seed missing)")
        firstRow(app).tap()
        assertEditorOpened(app, "1st entry")
        popEditor(app)

        quickAddSave(app, "Coffee 5")

        firstRow(app).tap()
        assertEditorOpened(app, "2nd entry after a QuickAdd insert rebuilt the list")
    }

    /// The harsher ordering: the "+" tab is hit while the editor is STILL pushed,
    /// so the tab bounce disturbs a live presentation rather than an idle one.
    func test_quickAddWhileEditorPushed_thenEditAgain_opensEditor() {
        let app = launchDemo()
        XCTAssertTrue(transactionsTab(app).waitForExistence(timeout: 20))
        transactionsTab(app).tap()

        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 15), "no rows (demo seed missing)")
        firstRow(app).tap()
        assertEditorOpened(app, "1st entry")

        // Disturb WITHOUT popping first.
        app.tabBars.buttons.element(boundBy: 2).tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "QuickEntry input missing")
        field.tap()
        field.typeText("Bagel 4")
        let save = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Save'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8), "QuickEntry Save missing")
        save.tap()

        // Get back to the list from wherever the bounce left us.
        if !firstRow(app).waitForExistence(timeout: 8) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 8), "list not reachable after the bounce")

        firstRow(app).tap()
        assertEditorOpened(app, "edit after a QuickAdd taken while the editor was pushed")
    }

    /// Repeated edit cycles in ONE session, alternating the row-tap and
    /// context-menu affordances. Both share `setEdit`, so a stuck presentation
    /// kills them together — and repeated cycles in a single session is exactly
    /// what the fresh-state matrix never exercises.
    func test_repeatedEditCycles_bothAffordances_keepOpening() {
        let app = launchDemo()
        XCTAssertTrue(transactionsTab(app).waitForExistence(timeout: 20))
        transactionsTab(app).tap()
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 15), "no rows (demo seed missing)")

        for cycle in 1...3 {
            firstRow(app).tap()
            assertEditorOpened(app, "cycle \(cycle) row tap")
            popEditor(app)

            contextMenuEdit(app, cycle: cycle)
            assertEditorOpened(app, "cycle \(cycle) context Edit")
            popEditor(app)
        }
    }
}
