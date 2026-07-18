//
//  MainThreadHangScaleTests.swift
//  FinanceTrackerUITests
//
//  In-app measurement of the main-thread hang AT SCALE (hang-brief round 2,
//  Step 0.3). Launches against a store seeded with ~8k transactions across 24
//  months (`--seed-large-dataset`) and wall-clocks the three founder actions:
//
//    (a) rapid QuickAdd entries — each save fires ModelContext.didSave TWICE
//        (transaction + merchant learning), each firing the refresher's
//        full-table fetch on the main actor;
//    (b) opening the Transactions list — the @Query full sorted fetch;
//    (c) tapping a row to Edit — the founder's frozen tap.
//
//  Wall time until the UI responds IS the measurement: while the main thread is
//  blocked, taps queue and elements don't appear. A fresh store runs the same
//  script in a fraction of the time — the delta is the hang.
//
//  Results are appended to /tmp/hang-scale-measure.txt (simulator processes
//  share the host filesystem).
//

import XCTest

final class MainThreadHangScaleTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD",
            "-monthlyBudgetCents", "400000"   // budget set → safe-to-spend hero + pace live
        ]
        // Appended AFTER the array, never inside it: these launch args are
        // NSUserDefaults `-key value` pairs, and a lone extra dash-token in
        // the middle shifts that pairing. Keeps the StoreKit rating prompt (an
        // out-of-process window that covers the app and eats taps) from firing
        // mid-suite.
        app.launchArguments.append("--suppress-rating-prompt")
        if seeded { app.launchArguments.append("--seed-large-dataset") }
        app.launch()
        return app
    }

    private func record(_ line: String) {
        print("⏱ \(line)")
        let url = URL(fileURLWithPath: "/tmp/hang-scale-measure.txt")
        let data = ("⏱ " + line + "\n").data(using: .utf8)!
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }

    private func ms(since t0: Date) -> Int { Int(Date().timeIntervalSince(t0) * 1000) }

    /// One QuickAdd entry through the + sheet; returns wall ms from the Save tap
    /// until the Dashboard tab is back and hittable (sheet dismissed, UI live).
    private func quickAddEntry(_ app: XCUIApplication, text: String) -> Int {
        let plusTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(plusTab.waitForExistence(timeout: 30), "+ tab missing")
        plusTab.tap()

        // Wait for a QuickEntry-UNIQUE element before touching any text input:
        // the Dashboard's quick-add bar shares the placeholder, so an app-wide
        // firstMatch grabs the wrong control while the sheet is still sliding in
        // on a busy main thread. 'Use detailed form' exists only in the sheet
        // (verified from a failure snapshot; XCUIElementTypeSheet doesn't match
        // SwiftUI .sheet, and 'Save & add another' doesn't carry that label).
        let sheetMarker = app.buttons["Use detailed form"]
        XCTAssertTrue(sheetMarker.waitForExistence(timeout: 90), "QuickEntry sheet never presented")

        let input = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 30), "QuickEntry input missing")

        // Focus can take several taps while the main thread is draining work.
        var focused = false
        for _ in 0..<5 where !focused {
            input.tap()
            focused = (input.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
            if !focused { usleep(500_000) }
        }
        XCTAssertTrue(focused, "QuickEntry input never took keyboard focus")
        input.typeText(text)

        let save = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Save' AND NOT (label CONTAINS 'another')")
        ).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Save button missing")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 15)

        let t0 = Date()
        save.tap()
        let dashboard = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashboard.waitForExistence(timeout: 120), "UI never came back after save")
        _ = dashboard.isHittable
        return ms(since: t0)
    }

    func test_measure_hotActions_atScale() {
        // Launch 1: seeding pass (slow by design — 8k inserts + the didSave storm
        // it triggers). Not part of the measurement.
        var app = launch(seeded: true)
        let seedT0 = Date()
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 300),
                      "app never became ready while seeding")
        record("seeding launch reached UI in \(ms(since: seedT0))ms")
        app.terminate()

        // Launch 2: the measured session — store already at ~8k rows.
        app = launch(seeded: true)   // idempotent: threshold guard skips re-seed
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 120))

        // (a) three rapid QuickAdd entries
        for (i, text) in ["12 coffee", "34 groceries", "56 taxi"].enumerated() {
            let cost = quickAddEntry(app, text: text)
            record("(a) QuickAdd save #\(i + 1) → UI live again: \(cost)ms @8k rows")
        }

        // (b) opening the Transactions list
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        var t0 = Date()
        txTab.tap()
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS ',' AND label CONTAINS '$'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 120), "Transactions list never showed rows")
        record("(b) Transactions tab tap → first row visible: \(ms(since: t0))ms @8k rows")

        // (c) tapping a row to edit — the founder's frozen tap
        t0 = Date()
        row.tap()
        let editorSave = app.buttons["Save"]
        XCTAssertTrue(editorSave.waitForExistence(timeout: 120), "editor never presented")
        record("(c) row tap → editor visible: \(ms(since: t0))ms @8k rows")
    }
}
