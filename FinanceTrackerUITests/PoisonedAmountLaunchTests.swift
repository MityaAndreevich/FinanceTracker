//
//  PoisonedAmountLaunchTests.swift
//  FinanceTrackerUITests
//
//  Closes the ENUMERATION, which is the weak link in the overflow work.
//
//  The unit tests prove that every KNOWN launch-path sum reports overflow instead
//  of trapping. They cannot prove the list is complete, and the list was wrong
//  three times in one day — twice by grep, once by inspection, and the site that
//  turned up last (the dashboard's own category accumulator) sat directly on the
//  launch screen.
//
//  So this does the only thing that settles it: seeds the store an already-
//  affected user has, launches the app, and asserts it is still running. Any
//  unlisted aggregate on the launch path traps, the process dies, and this fails.
//  There is nothing clever in the assertions on purpose — the launch IS the test.
//

import XCTest

final class PoisonedAmountLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(poisoned: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD"
        ]
        // Appended after the pairs — a lone dash-token inside the array shifts the
        // NSUserDefaults `-key value` pairing.
        app.launchArguments.append("--suppress-rating-prompt")
        if poisoned { app.launchArguments.append("--poison-amounts") }
        app.launch()
        return app
    }

    /// THE test. An app that traps during its first render never reaches
    /// `.runningForeground`, so this assertion is the crash detector.
    func test_launchWithUnsummableLedger_appStaysAlive() {
        let app = launch(poisoned: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "the app did not reach the foreground with an unsummable ledger — "
                      + "some aggregate on the launch path still traps, and it is one "
                      + "nobody enumerated")

        // Still alive a moment later: the alert refresher is scheduled on .active
        // and runs slightly after the first frame, so an immediate check could pass
        // while the process dies right behind it.
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(app.state, .runningForeground,
                       "the app died shortly after launch — the proactive-alert refresher "
                       + "path is the likely culprit; it runs on every .active transition")
    }

    /// The user must be TOLD, not shown a zero. This is the "cannot be shown"
    /// state, and it is the difference between a broken screen and a screen that
    /// explains itself.
    func test_launchWithUnsummableLedger_dashboardExplainsItself() {
        let app = launch(poisoned: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        let title = app.staticTexts["This month's totals can't be shown"]
        XCTAssertTrue(title.waitForExistence(timeout: 15),
                      "the dashboard did not surface the unavailable state — a silent zero "
                      + "or a clamped figure is exactly the defect this replaced")
    }

    /// THE WHOLE JOURNEY, which is the invariant recovery exists for:
    ///
    ///   cold launch → dashboard renders its unavailable state → Transactions →
    ///   the list renders → DELETE the offending row → totals come back
    ///
    /// "The Transactions tab renders" was the previous version of this test, and it
    /// was a PROXY for the journey. Proxies have cost us four enumeration errors in
    /// a day: the launch path was a proxy for this journey and missed the list's
    /// own day-header sum; "~2 files" was a proxy for a mechanism. So this walks
    /// the whole thing and ends on the state the user actually needs — a working
    /// app showing real numbers.
    func test_poisonedRow_canBeReachedDeletedAndTheAppRecovers() {
        let app = launch(poisoned: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "the app did not survive launch with an unsummable ledger")

        let unavailable = app.staticTexts["This month's totals can't be shown"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 15),
                      "the dashboard did not explain itself before sending the user onward")

        // → Transactions. Every sum this screen performs runs here, footer included.
        let transactions = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(transactions.waitForExistence(timeout: 15), "no tab bar to navigate with")
        transactions.tap()

        let row = app.staticTexts["poisoned 0"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "the transactions list did not render with an unsummable ledger — the "
                      + "user cannot reach the row they need to delete")
        XCTAssertEqual(app.state, .runningForeground, "the app died rendering the list")

        // → delete it. One row is enough: what cannot be represented is the SUM of
        // two, so removing either makes the month summable again.
        row.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10), "no delete affordance on the row")
        deleteButton.tap()
        // The confirmation dialog reuses the same label.
        let confirm = app.buttons["Delete"].firstMatch
        if confirm.waitForExistence(timeout: 5) { confirm.tap() }

        XCTAssertEqual(app.state, .runningForeground, "the app died deleting the row")

        // → back to the dashboard. Two assertions, and the POSITIVE one is the load
        // bearing half: "the unavailable card is gone" can pass vacuously if we
        // simply are not on the dashboard, and an absence-only check is the same
        // kind of proxy that has cost us four errors today. The hero label only
        // renders inside the money area, which only renders when the totals are
        // real — so its presence IS the recovery.
        app.tabBars.buttons.element(boundBy: 0).tap()

        let heroLabel = app.staticTexts["Spent"].firstMatch
        XCTAssertTrue(heroLabel.waitForExistence(timeout: 15),
                      "the dashboard's money area did not come back after the offending row "
                      + "was deleted — the user did everything right and the app did not recover")
        XCTAssertFalse(unavailable.exists,
                       "the unavailable card is still on screen alongside real totals")
        XCTAssertEqual(app.state, .runningForeground, "the app died returning to the dashboard")
    }

    /// The seed must not leak into later runs, and an ordinary launch must be
    /// unaffected by any of this.
    func test_ordinaryLaunchIsUnaffected() {
        let app = launch(poisoned: false)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertFalse(
            app.staticTexts["This month's totals can't be shown"].waitForExistence(timeout: 5),
            "an ordinary launch shows the unavailable state — either the seed leaked or "
            + "the guard fires on in-range data")
    }
}
