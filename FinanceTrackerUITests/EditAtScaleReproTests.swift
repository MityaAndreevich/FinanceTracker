//
//  EditAtScaleReproTests.swift
//  FinanceTrackerUITests
//
//  The 2026-07-17 device report the small-store matrix is structurally blind to:
//  at ~8k seeded rows, tapping Edit on a Transactions row opens NOTHING —
//  persistent, silent, no crash. EditPresentationReproTests runs on `--demo-mode`
//  (~30 rows) and passes; MainThreadHangScaleTests seeds 8k but its edit tap
//  lands on a row created by its own preceding QuickAdds, not a seeded row.
//
//  This test isolates the missing condition: launch seeded, go straight to
//  Transactions, tap a SEEDED row, assert the editor presents. If it fails, THIS
//  is the repro the investigation lacked.
//

import XCTest

final class EditAtScaleReproTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func record(_ s: String) {
        print("⏱ \(s)")
        let a = XCTAttachment(string: s); a.name = "diag"; a.lifetime = .keepAlways; add(a)
    }

    /// The native StoreKit review sheet (AppStore.requestReview) renders in-process
    /// on the simulator and steals taps. Dismiss it so it can't masquerade as the
    /// bug under test.
    private func dismissReviewPromptIfPresent(_ app: XCUIApplication) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 3) { notNow.tap() }
    }

    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD"
        ]
        if seeded { app.launchArguments.append("--seed-large-dataset") }
        app.launch()
        return app
    }

    /// The founder's EXACT sequence: ONE launch with the seed, then tap. The
    /// two-launch variant below lets the didSave storm settle first; the founder
    /// never gets that pause.
    func test_singleLaunch_seedThenEdit_opensEditor() {
        let app = launch(seeded: true)
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 300),
                      "app never became ready while seeding")
        dismissReviewPromptIfPresent(app)
        txTab.tap()

        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        if !row.waitForExistence(timeout: 60) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "transactions-screen-no-rows"; shot.lifetime = .keepAlways; add(shot)
            let att = XCTAttachment(string: app.debugDescription)
            att.name = "hierarchy-transactions-no-rows"; att.lifetime = .keepAlways; add(att)
            let emptyTitle = app.staticTexts["No transactions yet"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'transaction'")).firstMatch.exists
            record("NO ROWS. buttons=\(app.buttons.count) cells=\(app.cells.count) staticTexts=\(app.staticTexts.count) emptyStateVisible=\(emptyTitle)")
        }
        XCTAssertTrue(row.exists, "Transactions list never showed rows")
        row.tap()

        let editorSave = app.buttons["Save"]
        let presented = editorSave.waitForExistence(timeout: 20)
        if !presented {
            let att = XCTAttachment(string: app.debugDescription)
            att.name = "hierarchy-after-failed-single-launch-edit"
            att.lifetime = .keepAlways
            add(att)
        }
        XCTAssertTrue(presented, "editor never presented (single-launch seed) @8k rows")
    }

    private func gotoTransactions(_ app: XCUIApplication) -> XCUIElement {
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 300), "app never became ready")
        dismissReviewPromptIfPresent(app)
        txTab.tap()
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 120), "list never showed rows")
        return row
    }

    private func assertEditor(_ app: XCUIApplication, _ ctx: String) {
        let save = app.buttons["Save"]
        let ok = save.waitForExistence(timeout: 20)
        if !ok {
            let s = XCTAttachment(screenshot: app.screenshot()); s.name = "\(ctx)-fail"; s.lifetime = .keepAlways; add(s)
            let h = XCTAttachment(string: app.debugDescription); h.name = "\(ctx)-hierarchy"; h.lifetime = .keepAlways; add(h)
        }
        XCTAssertTrue(ok, "\(ctx): editor never presented @8k rows")
    }

    /// The affordance the founder literally names: the swipe-action "Edit" button.
    func test_singleLaunch_swipeEdit_atScale() {
        let app = launch(seeded: true)
        let row = gotoTransactions(app)
        row.swipeLeft()
        let editBtn = app.buttons["Edit"]
        XCTAssertTrue(editBtn.waitForExistence(timeout: 8), "swipe revealed no Edit button")
        editBtn.tap()
        assertEditor(app, "swipeEdit")
    }

    /// Context-menu "Edit" (long-press).
    func test_singleLaunch_contextEdit_atScale() {
        let app = launch(seeded: true)
        let row = gotoTransactions(app)
        row.press(forDuration: 1.0)
        let editBtn = app.buttons["Edit"]
        XCTAssertTrue(editBtn.waitForExistence(timeout: 8), "context menu revealed no Edit button")
        editBtn.tap()
        assertEditor(app, "contextEdit")
    }

    /// Variable-5 at scale: tap → pop → tap again. The known sticky-item failure
    /// mode where the second `editTx =` is a silent no-op ("worked earlier, now
    /// Edit opens nothing").
    func test_reentry_tapPopTap_atScale() {
        let app = launch(seeded: true)
        var row = gotoTransactions(app)
        row.tap()
        assertEditor(app, "reentry-1st")
        app.navigationBars.buttons.firstMatch.tap()   // back
        row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "list didn't return after pop")
        row.tap()
        assertEditor(app, "reentry-2nd")
    }

    // NOTE: a "scroll deep, then tap a far-down row" case was tried and removed.
    // It failed intermittently — but always as an XCUITest artifact, never the
    // product: after several swipes `element(boundBy:)` resolves to a row whose
    // center sits under the sticky period/filter bar (safeAreaInset), so the tap
    // lands on the bar and the row action never fires (verified via the
    // EditPresentation instrument: NO TAP-SET was emitted on the failing runs,
    // i.e. the button closure never ran). A deep-row tap drives the identical
    // Button → setEdit → navigationDestination path as a top row — the
    // presentation is scroll-offset-independent — so the row/swipe/context/
    // re-entry cases below already pin it deterministically. A flaky test that
    // fails on simulator scroll mechanics is worse than none.

    /// Seed once (persists in the app container), then drive the founder's tap.
    func test_seededRowTap_opensEditor() {
        // Launch 1: seeding pass — slow by design, not measured.
        var app = launch(seeded: true)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 300),
                      "app never became ready while seeding")
        app.terminate()

        // Launch 2: store already at ~8k rows (idempotent threshold guard).
        app = launch(seeded: true)
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 120), "tab bar missing")
        txTab.tap()

        // First real row — a SEEDED "Seed Merchant N" row, source == nil.
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 120), "Transactions list never showed rows")

        row.tap()

        let editorSave = app.buttons["Save"]
        let presented = editorSave.waitForExistence(timeout: 20)
        if !presented {
            // Capture the hierarchy at the moment of failure for the mechanism read.
            let att = XCTAttachment(string: app.debugDescription)
            att.name = "hierarchy-after-failed-edit-tap"
            att.lifetime = .keepAlways
            add(att)
        }
        XCTAssertTrue(presented, "editor never presented after tapping a seeded row @8k rows")
    }
}
