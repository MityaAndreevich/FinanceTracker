//
//  PreV1UpgradeFlowTests.swift
//  FinanceTrackerUITests
//
//  The 1.0.0-upgrade path, driven end to end. Hermetic via `--seed-pre-v1-store`
//  (DEBUG seam), which replaces the App Group store with a V0-shaped one and
//  clears the migration sentinels — so this needs no old build, no captured
//  store, and no manual setup.
//
//  Before that seam existed, verifying the floor screen's escape hatch required
//  installing a 1.0.0-era build by hand, and the check could not live in the
//  suite at all.
//

import XCTest

final class PreV1UpgradeFlowTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(failMigration: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--seed-pre-v1-store",
        ]
        if failMigration { app.launchArguments.append("--fail-migration") }
        // Out-of-process rating window eats taps mid-suite (see eed765f).
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()
        return app
    }

    /// THE ROOT FIX, at UI level: a store older than the declared V1 must reach
    /// the app. Before the lift this ended on the terminal floor screen.
    func test_preV1Store_migratesAndReachesTheApp() {
        let app = launch(failMigration: false)

        let preMigration = app.staticTexts["We've improved how your data is stored"]
        XCTAssertTrue(preMigration.waitForExistence(timeout: 30),
                      "the pre-migration screen did not appear — the seam did not produce an unmigrated store")

        app.buttons["Continue"].firstMatch.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60),
                      "a pre-V1 store did not reach the app — this is the field bug of 2026-08-14")
        XCTAssertFalse(app.staticTexts["Your data is safe"].exists,
                       "landed on the degraded floor instead of the app")
    }

    /// THE ESCAPE HATCH. `--fail-migration` forces the floor with the store still
    /// pre-V1 (the ladder restores the PRE-LIFT backup), which is exactly the
    /// state the field reporter was in. The export must work from there, and the
    /// screen must say what deleting the app costs.
    func test_floorScreen_warnsAboutDeletionAndExportsAnyway() {
        let app = launch(failMigration: true)

        XCTAssertTrue(app.buttons["Continue"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["Continue"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Your data is safe"].waitForExistence(timeout: 45),
                      "--fail-migration did not land on the floor")

        // The warning is the half a stranded user needs BEFORE they act: the
        // screen reads as reassurance, and their obvious next move destroys data.
        let warning = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5),
                      "the floor does not warn that deleting the app erases the data")

        let export = app.buttons["Export my data"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        export.tap()

        // The failure line must NOT appear: on a pre-V1 store the first
        // read-only open throws, and the retry-after-lift is what rescues it.
        let failureLine = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] \"export didn't work\"")).firstMatch
        XCTAssertFalse(failureLine.waitForExistence(timeout: 12),
                       "the floor's only data-out route failed — the state that made delete-and-reinstall the user's best option")
    }
}
