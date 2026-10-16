//
//  GuideShowMeJourneyTests.swift
//  FinanceTrackerUITests
//
//  Every Show-me destination LANDS (User Guide step 2, DESIGN_USER_GUIDE §7,
//  outputs/GUIDE_STEP2_PLAN.md).
//
//  The trigger is the DEBUG route harness (`--guide-route-harness`), a thin
//  caller of `GuideRouter.open(_:)`, the same function step 3's Show me button
//  calls. Step 3 switches these journeys to the card's button.
//
//  Rules this file keeps:
//    • Each destination is proven by an element ON the destination (its screen
//      id, or the sheet's own control), never by tab selection alone.
//    • Each journey STARTS where its destination is not, so a route that does
//      nothing fails: Settings destinations start on the Dashboard, the rest on
//      Settings, and in-screen defaults are moved first (Pulse is Analytics'
//      default, so the Pulse case starts from Breakdown).
//    • Scroll destinations must put their row on screen AND in the upper part of
//      it: presence in the tree is not "scrolled to".
//
//  Commissioned red per destination, see STATE §13.12.
//

import XCTest

final class GuideShowMeJourneyTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private enum Start { case dashboard, settings, insideGeneral, analyticsBreakdown, transactionsSearched }

    // MARK: - Families (the harness groups its menu the same way)

    func test_tabs() {
        journey("tabs", "dashboard", from: .settings) { app in
            self.present(app, "screen.dashboard")
        }
        journey("tabs", "transactions", from: .transactionsSearched) { app in
            guard self.present(app, "screen.transactions") else { return false }
            let search = app.searchFields.firstMatch
            let value = (search.value as? String) ?? ""
            let cleared = !search.exists || value.isEmpty || value == search.placeholderValue
            XCTAssertTrue(cleared, "transactions: the search still reads '\(value)'")
            return cleared
        }
        journey("tabs", "analyticsPulse", from: .analyticsBreakdown) { app in
            self.present(app, "screen.analytics.pulse")
        }
        journey("tabs", "analyticsBreakdown", from: .settings) { app in
            self.present(app, "screen.analytics.breakdown")
        }
        journey("tabs", "analyticsHorizon", from: .settings) { app in
            self.present(app, "screen.analytics.horizon")
        }
    }

    func test_sheets() {
        journey("sheets", "quickEntry", from: .settings) { app in
            self.present(app, "quickEntry.close")
        }
        journey("sheets", "addForm", from: .settings) { app in
            self.present(app, "screen.addTransaction")
        }
        journey("sheets", "dashboardBudget", from: .settings) { app in
            self.present(app, "dashboard.budget.field")
        }
        // The simulator has no mail account, so this proves the FALLBACK sheet
        // only. The consent → Mail path is verified on device (step-6 acceptance).
        journey("sheets", "feedback", from: .dashboard) { app in
            self.present(app, "screen.feedback.fallback")
        }
    }

    func test_settingsPushes() {
        let screens: [(String, String)] = [
            ("general", "screen.settings.general"),
            ("premium", "screen.settings.premium"),
            ("privacy", "screen.settings.privacy"),
            ("recurring", "screen.settings.recurring"),
            ("categoriesAndAccounts", "screen.settings.categories"),
            ("reports", "screen.settings.reports"),
            // Not `reports_monthly_toggle`: on a fresh install the toggles are Premium-locked rows.
            ("reportsSettings", "screen.settings.reportsSettings"),
        ]
        for (destination, id) in screens {
            journey("settings", destination, from: .dashboard) { app in self.present(app, id) }
        }
        // From INSIDE a pushed Settings child: the route must replace a non-empty path.
        journey("settings", "alerts", from: .insideGeneral) { app in
            self.present(app, "screen.settings.alerts")
        }
    }

    func test_inScreen() {
        journey("inScreen", "dashboardQuickAdd", from: .settings) { app in
            let field = app.textFields["dashboard.quickadd.field"]
            guard field.waitForExistence(timeout: 8) else {
                XCTFail("dashboardQuickAdd: the Quick Add field never appeared"); return false
            }
            let focused = self.wait(8) { (field.value(forKey: "hasKeyboardFocus") as? Bool) == true }
            XCTAssertTrue(focused, "dashboardQuickAdd: the Quick Add field is not focused")
            XCTAssertTrue(app.keyboards.firstMatch.exists, "dashboardQuickAdd: no keyboard")
            return focused
        }
        journey("inScreen", "categoryLimits", from: .dashboard) { app in
            guard self.present(app, "screen.settings.categories") else { return false }
            XCTAssertTrue(app.descendants(matching: .any)["categories.section.expense"].exists,
                          "categoryLimits: no Expense section")
            return self.scrolledToTop(app, "categories.expense.first", "categoryLimits")
        }
        journey("inScreen", "dataImport", from: .dashboard) { app in
            guard self.present(app, "screen.settings.data") else { return false }
            // On iPhone 17 Pro the whole Data list fits one screen, so nothing can
            // scroll: the proof is that the row is ON screen on arrival. The scroll
            // is observable only on a smaller screen or larger text (recorded, STATE §13.12).
            return self.onScreen(app, "data.import.first", "dataImport")
        }
        journey("inScreen", "dataExport", from: .dashboard) { app in
            guard self.present(app, "screen.settings.data") else { return false }
            return self.onScreen(app, "data.export.first", "dataExport")
        }
    }

    func test_external() {
        journey("external", "setupSiri", from: .dashboard) { _ in
            let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
            let opened = shortcuts.wait(for: .runningForeground, timeout: 10)
            XCTAssertTrue(opened, "setupSiri: Shortcuts did not come to the foreground")
            shortcuts.terminate()
            return opened
        }
    }

    /// 2026-10-15 amendment: without the argument the harness is not in the tree
    /// in a DEBUG build either. The second half proves the id is the right one,
    /// so the absence is not vacuous.
    func test_harnessExistsOnlyWithItsArgument() {
        let plain = launch(harness: false)
        XCTAssertTrue(plain.tabBars.firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(plain.descendants(matching: .any)["guide.harness"].exists,
                       "the route harness is in the view tree without --guide-route-harness")
        plain.terminate()

        let withArg = launch(harness: true)
        XCTAssertTrue(withArg.buttons["guide.harness"].waitForExistence(timeout: 20),
                      "the route harness is missing WITH its argument (wrong id?)")
    }

    // MARK: - Journey machinery

    private func journey(_ family: String, _ destination: String, from start: Start,
                         line: UInt = #line, proof: (XCUIApplication) -> Bool) {
        XCTContext.runActivity(named: "\(destination) from \(start)") { _ in
            let app = launch(harness: true)
            go(to: start, app)
            open(family, destination, app)
            if !proof(app) {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "showme-\(destination)"
                shot.lifetime = .keepAlways
                add(shot)
            }
            app.terminate()
        }
    }

    private func go(to start: Start, _ app: XCUIApplication) {
        switch start {
        case .dashboard:
            XCTAssertTrue(app.descendants(matching: .any)["screen.dashboard"].waitForExistence(timeout: 20),
                          "start: not on the Dashboard")
        case .settings:
            app.tapTab(4)
            XCTAssertTrue(app.buttons["settings_general_row"].waitForExistence(timeout: 8), "start: Settings root")
        case .insideGeneral:
            app.tapTab(4)
            app.buttons["settings_general_row"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["screen.settings.general"].waitForExistence(timeout: 8),
                          "start: inside General")
        case .analyticsBreakdown:
            app.tapTab(3)
            app.buttons["Breakdown"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["screen.analytics.breakdown"].waitForExistence(timeout: 8),
                          "start: Analytics on Breakdown")
            app.tapTab(4)
        case .transactionsSearched:
            app.tapTab(1)
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 8), "start: Transactions search field")
            search.tap()
            // Return keeps the text and ends editing, so the tab bar takes the next tap.
            search.typeText("zzz\n")
            app.tapTab(4)
        }
    }

    /// Through the harness menu: harness → family → destination.
    private func open(_ family: String, _ destination: String, _ app: XCUIApplication) {
        let harness = app.buttons["guide.harness"]
        XCTAssertTrue(harness.waitForExistence(timeout: 8), "\(destination): harness missing")
        harness.tap()
        let familyItem = app.buttons[family]
        XCTAssertTrue(familyItem.waitForExistence(timeout: 4), "\(destination): menu '\(family)' missing")
        familyItem.tap()
        let item = app.buttons[destination]
        XCTAssertTrue(item.waitForExistence(timeout: 4), "\(destination): menu item missing")
        item.tap()
    }

    @discardableResult
    private func present(_ app: XCUIApplication, _ id: String) -> Bool {
        let found = app.descendants(matching: .any)[id].firstMatch.waitForExistence(timeout: 8)
        XCTAssertTrue(found, "Show me did not land: '\(id)' is not on screen")
        return found
    }

    /// The row is fully between the navigation bar and the tab bar AND starts in the
    /// top 40 % of the window: scrolled to, not merely somewhere in the list. (Not
    /// `isHittable`: a plain HStack row with a tap gesture is not a hittable element.)
    private func scrolledToTop(_ app: XCUIApplication, _ id: String, _ destination: String) -> Bool {
        // firstMatch: a row's identifier is inherited by its children.
        let row = app.descendants(matching: .any)[id].firstMatch
        let windowHeight = app.windows.firstMatch.frame.height
        let ok = wait(8) {
            guard row.exists else { return false }
            let top = app.navigationBars.firstMatch.frame.maxY
            let bottom = app.tabBars.firstMatch.frame.minY
            return row.frame.minY >= top && row.frame.maxY <= bottom && row.frame.minY < windowHeight * 0.4
        }
        XCTAssertTrue(ok, "\(destination): '\(id)' not scrolled to the top "
                      + "(exists=\(row.exists) frame=\(row.exists ? row.frame : .zero) "
                      + "navBar.maxY=\(app.navigationBars.firstMatch.frame.maxY) window=\(windowHeight))")
        return ok
    }

    private func onScreen(_ app: XCUIApplication, _ id: String, _ destination: String) -> Bool {
        let row = app.descendants(matching: .any)[id].firstMatch
        let ok = wait(8) { row.exists && row.isHittable }
        XCTAssertTrue(ok, "\(destination): '\(id)' is not on screen")
        return ok
    }

    private func wait(_ seconds: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    private func launch(harness: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)"
        ]
        // After the array, never inside it (see LanguageSwitchTests).
        app.launchArguments.append("--suppress-rating-prompt")
        if harness { app.launchArguments.append("--guide-route-harness") }
        app.launch()
        return app
    }
}
