//
//  BreakdownOtherExpandTests.swift
//  FinanceTrackerUITests
//
//  Device QA 2026-07-23 #1/#2: a category ranked below the Breakdown's top-5
//  fold (where a fresh split part almost always lands) was sealed inside a
//  non-navigable "Other" row — invisible and unreachable. Guards the fix:
//  tapping "Other" unfolds the tail, and a tail row drills down like any
//  category. Demo seed has 9 expense categories, so the fold always exists.
//

import XCTest

final class BreakdownOtherExpandTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func test_otherRow_expands_andTailCategoryDrillsDown() {
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

        let analyticsTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(analyticsTab.waitForExistence(timeout: 20), "Analytics tab never appeared")
        analyticsTab.tap()

        let breakdownSegment = app.buttons["Breakdown"]
        XCTAssertTrue(breakdownSegment.waitForExistence(timeout: 8), "Breakdown segment missing")
        breakdownSegment.tap()

        // The fold row (demo seed: 9 expense categories → top 5 + Other).
        let otherRow = app.staticTexts["Other"]
        if !otherRow.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(otherRow.waitForExistence(timeout: 5), "no 'Other' fold row (seed shape changed?)")

        // Coffee is the smallest demo category — always inside the fold, and
        // must NOT be visible while collapsed.
        let tailCategory = app.staticTexts["Coffee"]
        XCTAssertFalse(tailCategory.isHittable, "tail category visible before expanding — fold broken")

        otherRow.tap()
        if !tailCategory.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(tailCategory.waitForExistence(timeout: 5),
                      "tapping 'Other' did not reveal the folded tail")

        // A tail row is a real category row: it must drill down.
        tailCategory.tap()
        XCTAssertTrue(app.navigationBars["Coffee"].waitForExistence(timeout: 5),
                      "tail category row did not open the drill-down")

        // Collapse works too: back, tap the row again, tail hides. While the
        // Other slice is focused its name ALSO sits in the donut center, so
        // target the row by its unique "+N more" subtitle, not by "Other".
        app.navigationBars.buttons.firstMatch.tap()
        let otherSubtitle = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "+")
        ).firstMatch
        XCTAssertTrue(otherSubtitle.waitForExistence(timeout: 5), "Breakdown did not come back")
        otherSubtitle.tap()
        XCTAssertTrue(tailCategory.waitForNonExistence(timeout: 3),
                      "tapping 'Other' again did not collapse the tail")
    }
}
