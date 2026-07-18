//
//  SecondTransactionCrashTests.swift
//  FinanceTrackerUITests
//
//  REGRESSION GUARD for a fixed bug — not a live repro. The device-confirmed
//  launch blocker (EXC_BREAKPOINT during a SwiftUI render pass when the SECOND
//  transaction was saved) was root-caused to a degenerate chart frame and fixed.
//  These tests exist so it cannot come back.
//
//  Consequently: each test asserts that the app STAYS ALIVE and returns to the
//  Dashboard across a save flow. Name them for that, never `...doesNotCrash` —
//  a harness failure under such a name reads as "the crash is back" and costs
//  someone an afternoon proving it isn't. If one of these fails, read the
//  failure message before drawing any conclusion.
//
//  This has to be a UI test, not a unit test. Hosting the chart views directly
//  with a synthetic ModelContainer does NOT reproduce it — the crash needs the
//  real app: the real SharedModelContainer, the QuickEntry sheet dismissing, the
//  merchant-learning write, the `ModelContext.didSave` alert refresher, and the
//  widget reload all landing on the same run loop as the Dashboard re-render.
//
//  Precondition: a store with ZERO transactions (fresh install). The runner
//  uninstalls the app first — see the crash-repro invocation in the brief.
//

import XCTest

final class SecondTransactionCrashTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchClean(
        language: String = "en",
        locale: String = "en_US",
        currency: String = "USD",
        budgetCents: Int? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            // NOTE: deliberately NOT --demo-mode. The bug is about going from an
            // empty store to 1 → 2 real transactions.
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-defaultCurrencyCode", currency
        ]
        // Appended AFTER the array, never inside it: these launch args are
        // NSUserDefaults `-key value` pairs, and a lone extra dash-token in
        // the middle shifts that pairing. Keeps the StoreKit rating prompt (an
        // out-of-process window that covers the app and eats taps) from firing
        // mid-suite.
        app.launchArguments.append("--suppress-rating-prompt")
        if let budgetCents {
            // A budget makes the safe-to-spend hero (and the pace cue) live.
            app.launchArguments += ["-monthlyBudgetCents", String(budgetCents)]
        }
        app.launch()
        return app
    }

    /// Tap a text input and type into it, only once it genuinely holds keyboard
    /// focus.
    ///
    /// `tap()` merely *requests* first responder and returns before the
    /// responder change and keyboard animation finish; typing into that gap
    /// fails with "Neither element nor any descendant has keyboard focus". The
    /// wait also turns a stolen tap into an honest error message — see
    /// `suppressRatingPrompt` in `launchClean`, which is what actually used to
    /// steal them.
    private func focusAndType(_ app: XCUIApplication, _ input: XCUIElement, _ text: String) {
        input.tap()

        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10),
                      "keyboard never appeared for the QuickEntry input — "
                      + "something is covering the app and swallowing taps")

        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        expectation(for: focused, evaluatedWith: input)
        waitForExpectations(timeout: 10)

        input.typeText(text)
    }

    /// Type an entry into QuickAdd and commit it, returning to the Dashboard.
    /// `savePrefix` is the localized "Save" — the button's a11y label becomes the
    /// dynamic "Save $12.00 in Food" once the entry parses, so we match a prefix
    /// and exclude the subordinate "Save & add another".
    private func addTransaction(
        _ app: XCUIApplication,
        text: String,
        index: Int,
        savePrefix: String = "Save",
        addAnotherMarker: String = "another"
    ) {
        // Tabs: Dashboard(0), Transactions(1), +(2), Analytics(3), Settings(4).
        let plusTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(plusTab.waitForExistence(timeout: 20), "+ tab never appeared")
        plusTab.tap()

        // The QuickEntry input is a multiline TextField (axis: .vertical), which
        // UIKit exposes as a text view.
        let input = app.textViews.firstMatch.exists
            ? app.textViews.firstMatch
            : app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10), "QuickEntry input missing")
        focusAndType(app, input, text)

        let save = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND NOT (label CONTAINS %@)",
                        savePrefix, addAnotherMarker)
        ).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save button missing for entry #\(index)")
        // The button is disabled until the input parses.
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: save)
        waitForExpectations(timeout: 10)
        save.tap()

        // Back on the Dashboard: the sheet dismisses and the Dashboard (donut +
        // hero) re-renders with the new data. This is where the device crashes.
        let dashTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashTab.waitForExistence(timeout: 15),
                      "app died after saving transaction #\(index) — sheet never returned to the Dashboard")
    }

    /// The exact reported flow: fresh store → save #1 → save #2 (crash) → save #3.
    func test_savingThreeConsecutiveTransactions_appStaysAliveAndReturnsToDashboard() {
        let app = launchClean()

        addTransaction(app, text: "12 coffee", index: 1)
        XCTAssertEqual(app.state, .runningForeground, "app died after transaction #1")

        addTransaction(app, text: "34 groceries", index: 2)
        XCTAssertEqual(app.state, .runningForeground, "app CRASHED after transaction #2")

        addTransaction(app, text: "56 taxi", index: 3)
        XCTAssertEqual(app.state, .runningForeground, "app died after transaction #3")
    }

    /// The SAME merchant twice. Save #2 is the first write that takes
    /// MerchantLearningService's *update existing row* branch (save #1 inserts).
    /// A failure there calls `rollback()` on the shared mainContext, which can
    /// destroy model instances the Dashboard is mid-render on.
    func test_secondSaveWithSameMerchant_appStaysAlive() {
        let app = launchClean()

        addTransaction(app, text: "12 coffee", index: 1)
        XCTAssertEqual(app.state, .runningForeground, "app died after transaction #1")

        addTransaction(app, text: "34 coffee", index: 2)
        XCTAssertEqual(app.state, .runningForeground,
                       "app CRASHED after a SECOND transaction with the same merchant")
    }

    /// The reporter's real device configuration: Russian UI, RUB, and a monthly
    /// budget set (so the safe-to-spend hero and the pace cue are both live —
    /// neither is exercised by the default en/no-budget launch).
    func test_savingTransactions_inRussianLocaleWithBudget_appStaysAlive() {
        let app = launchClean(language: "ru", locale: "ru_RU", currency: "RUB", budgetCents: 5_000_000)

        let ru = "Сохранить"
        let another = "добавить"

        addTransaction(app, text: "12 кофе", index: 1, savePrefix: ru, addAnotherMarker: another)
        XCTAssertEqual(app.state, .runningForeground, "app died after transaction #1 (ru/RUB/budget)")

        addTransaction(app, text: "34 продукты", index: 2, savePrefix: ru, addAnotherMarker: another)
        XCTAssertEqual(app.state, .runningForeground, "app CRASHED after transaction #2 (ru/RUB/budget)")

        addTransaction(app, text: "56 такси", index: 3, savePrefix: ru, addAnotherMarker: another)
        XCTAssertEqual(app.state, .runningForeground, "app died after transaction #3 (ru/RUB/budget)")
    }

    /// Same flow, but with the Analytics tab (Pulse/Horizon/Breakdown charts) as
    /// the visible screen when the writes land.
    func test_savingTransactions_withAnalyticsVisible_appStaysAlive() {
        let app = launchClean()

        addTransaction(app, text: "12 coffee", index: 1)

        let analyticsTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(analyticsTab.waitForExistence(timeout: 15))
        analyticsTab.tap()
        XCTAssertEqual(app.state, .runningForeground, "app died rendering Analytics with 1 transaction")

        addTransaction(app, text: "34 groceries", index: 2)
        XCTAssertEqual(app.state, .runningForeground, "app CRASHED after transaction #2 with Analytics visible")

        analyticsTab.tap()
        XCTAssertEqual(app.state, .runningForeground, "app died rendering Analytics with 2 transactions")
    }
}
