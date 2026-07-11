//
//  DuplicateReviewFlowTests.swift
//  FinanceTrackerUITests
//
//  Drives the whole possible-duplicate surface the way a user meets it: a foreign
//  CSV imported twice (via the DEBUG `--seed-possible-duplicates` seam, which runs
//  the REAL importer), then the badge, the banner, and the review sheet.
//
//  The unit tests prove the flag is set and cleared. Only this proves the user can
//  SEE it and act on it — which was the entire gap: the duplicates existed on
//  device, and there was no way to find them.
//

import XCTest

final class DuplicateReviewFlowTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchWithFlaggedDuplicates() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--seed-possible-duplicates",   // foreign CSV imported twice (DEBUG only)
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        // Tabs: Dashboard(0), Transactions(1), +(2), Analytics(3), Settings(4).
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 20), "Transactions tab never appeared")
        txTab.tap()
        return app
    }

    /// The badge is on the row, and the banner offers the way out. Both are matched
    /// on their TEXT, not their color — if this passes, the signal survives for a
    /// user who can't see the amber at all.
    func test_flaggedRows_showBadge_andBanner() {
        let app = launchWithFlaggedDuplicates()

        let badge = app.staticTexts["Possible duplicate"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 15),
                      "no 'Possible duplicate' badge on the re-imported rows")

        let banner = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Possible duplicates'")
        ).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "review banner missing from the list")

        attach(app, name: "01-list-badge-and-banner")

        banner.tap()
        XCTAssertTrue(app.buttons["Keep"].firstMatch.waitForExistence(timeout: 8))
        attach(app, name: "02-review-sheet")
    }

    /// Visual record of the two surfaces, so the badge + sheet can be eyeballed
    /// without a device in hand.
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The resolve half: the banner opens the review sheet, Delete removes the
    /// duplicate copy, and the row count drops. The originals must survive.
    func test_reviewSheet_deleteAll_removesDuplicatesAndBanner() {
        let app = launchWithFlaggedDuplicates()

        let banner = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Possible duplicates'")
        ).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "review banner missing")
        banner.tap()

        // The sheet lists the flagged rows with a per-row Keep / Delete.
        XCTAssertTrue(app.buttons["Keep"].firstMatch.waitForExistence(timeout: 8),
                      "review sheet has no per-row Keep")
        XCTAssertTrue(app.buttons["Delete"].firstMatch.exists,
                      "review sheet has no per-row Delete")

        // Bulk delete asks first — it's the only irreversible action here.
        app.buttons["Delete all"].tap()
        let confirm = app.alerts.buttons["Delete all"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "delete-all did not confirm first")
        confirm.tap()

        // Back on the list: no banner, no badge — and the original rows remain.
        XCTAssertFalse(
            app.buttons.containing(NSPredicate(format: "label CONTAINS 'Possible duplicates'"))
                .firstMatch.waitForExistence(timeout: 5),
            "banner still showing after every duplicate was deleted"
        )
        XCTAssertFalse(app.staticTexts["Possible duplicate"].firstMatch.exists,
                       "badge still showing after the duplicates were deleted")

        let remainingRows = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ', Expense, $'")
        ).count
        XCTAssertEqual(remainingRows, 3, "the three ORIGINAL transactions must survive delete-all")
    }

    /// Keep is the non-destructive resolution: the flag clears, the row stays.
    func test_reviewSheet_keepAll_clearsFlagsWithoutDeleting() {
        let app = launchWithFlaggedDuplicates()

        let banner = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Possible duplicates'")
        ).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "review banner missing")
        banner.tap()

        let keepAll = app.buttons["Keep all"]
        XCTAssertTrue(keepAll.waitForExistence(timeout: 8), "review sheet has no Keep all")
        keepAll.tap()

        XCTAssertFalse(
            app.buttons.containing(NSPredicate(format: "label CONTAINS 'Possible duplicates'"))
                .firstMatch.waitForExistence(timeout: 5),
            "banner still showing after keep-all"
        )

        // Keep deletes NOTHING: both copies of all three rows are still there.
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS ', Expense, $'")).count
        XCTAssertEqual(rows, 6, "keep-all must not delete any row")
    }
}
