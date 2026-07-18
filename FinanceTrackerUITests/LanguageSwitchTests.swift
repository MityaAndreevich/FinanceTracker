//
//  LanguageSwitchTests.swift
//  FinanceTrackerUITests
//
//  Regression coverage for **Bug 2** — the language-switch first-tap problem
//  ("при первой попытке экран падает вниз, со второй работает").
//
//  ──────────────────────────────────────────────────────────────────────────
//  KEY FINDING (2026-06-28, iPhone 16 Pro Max, iOS 18.6 — verified across
//  several serial runs):
//
//  The language picker's presentation on the FIRST tap of the Language row is
//  INTERMITTENT. Sometimes it opens immediately; sometimes the first tap does
//  nothing and a second tap is required. Observed roughly ~50% first-tap failure
//  in serial runs (e.g. one run: EN→RU ✗, ES→PT-BR ✗, PT-BR→EN ✓, RU→ES ✓;
//  a diagnostic run: EN→RU ✗ twice). This matches the original user report and
//  points to a SwiftUI `.sheet(item:)` PRESENTATION RACE — NOT the dismiss-time
//  "apply" path that the earlier deferred-apply fix addressed. The first-tap race
//  is therefore still OPEN. Root-causing/fixing is intentionally NOT done here.
//
//  Because the failure is intermittent, asserting "opens on the first tap" would
//  make this suite FLAKY (random red), which is worse than the bug it documents.
//  So each test instead:
//    • RECORDS the first-tap outcome every run (printed as `[Bug2 first-tap] …` and
//      attached to the result bundle) so the race rate stays visible, and
//    • RELIABLY ASSERTS the stable contract that the prior fix is meant to keep:
//      the picker becomes reachable (≤3 taps), DISMISSES cleanly after selection,
//      the Settings list SURVIVES (language row present + hittable), and the app
//      stays RESPONSIVE (picker can be reopened).
//  When the presentation race is fixed, tighten `maxOpenTaps` to 1 to convert the
//  observation into a hard first-tap guarantee.
//
//  LIMITATION — XCUITest cannot observe the *visual* bounce/drop itself (a sub-
//  frame animation artifact needing pixel-diff / screen-recording). It also can't
//  read the app's os_log, so "no presentation conflict in console" is only
//  approximated: a wedged presentation would fail the element queries here.
//  ──────────────────────────────────────────────────────────────────────────
//

import XCTest

final class LanguageSwitchTests: XCTestCase {

    /// Max taps allowed to open the picker. Confirmed 1 after moving .sheet(item:) to
    /// the view root (Fix #12, 2026-06-28) — first-tap race resolved.
    private let maxOpenTaps = 1

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLanguageSwitchNoBounce_EN_to_RU() throws {
        runSwitch(startCode: "en", targetCode: "ru")
    }

    func testLanguageSwitchNoBounce_RU_to_ES() throws {
        runSwitch(startCode: "ru", targetCode: "es")
    }

    func testLanguageSwitchNoBounce_ES_to_PT_BR() throws {
        runSwitch(startCode: "es", targetCode: "pt")   // "pt" enum case → pt-BR.lproj
    }

    func testLanguageSwitchNoBounce_PT_BR_to_EN() throws {
        runSwitch(startCode: "pt", targetCode: "en")
    }

    func testLanguageSwitchNoBounce_RU_to_UK() throws {
        runSwitch(startCode: "ru", targetCode: "uk")
    }

    func testLanguageSwitchNoBounce_UK_to_EN() throws {
        runSwitch(startCode: "uk", targetCode: "en")
    }

    // MARK: - Shared flow

    private func runSwitch(startCode: String,
                           targetCode: String,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", startCode,
            "-AppleLanguages", "(\(appleLanguage(for: startCode)))"
        ]
        // Appended AFTER the array, never inside it: these launch args are
        // NSUserDefaults `-key value` pairs, and a lone extra dash-token in
        // the middle shifts that pairing. Keeps the StoreKit rating prompt (an
        // out-of-process window that covers the app and eats taps) from firing
        // mid-suite.
        app.launchArguments.append("--suppress-rating-prompt")
        app.launch()

        // Settings is the 5th tab item (index 4): Dashboard, Transactions, +, Analytics, Settings.
        let settingsTab = app.tabBars.buttons.element(boundBy: 4)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15),
                      "Settings tab never appeared", file: file, line: line)
        settingsTab.tap()

        // "General" is the first row of the Settings list.
        let generalRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(generalRow.waitForExistence(timeout: 8),
                      "General row never appeared", file: file, line: line)
        generalRow.tap()

        let languageRow = element(app, "settings.language.row")
        XCTAssertTrue(languageRow.waitForExistence(timeout: 8),
                      "Language row (settings.language.row) never appeared", file: file, line: line)

        let targetRowID = "picker.locale.\(targetCode)"

        // Open the picker, recording how many taps it took (the first-tap race).
        let tapsToOpen = openPicker(app, languageRow: languageRow, rowID: targetRowID)
        recordFirstTapOutcome(opened: tapsToOpen == 1, taps: tapsToOpen, target: targetCode)
        XCTAssertGreaterThan(tapsToOpen, 0,
                             "Language picker never presented within \(maxOpenTaps) taps (\(targetRowID))",
                             file: file, line: line)

        // Select the locale.
        element(app, targetRowID).tap()

        // (1) Sheet dismisses cleanly after selection.
        XCTAssertTrue(waitForGone(element(app, targetRowID), timeout: 6),
                      "Picker did not dismiss after selecting \(targetRowID)", file: file, line: line)

        // (2) Settings list survived: language row is back and interactive
        //     (not popped/bounced away — the dismiss-time symptom).
        XCTAssertTrue(languageRow.waitForExistence(timeout: 6),
                      "Language row missing after switch — list bounced/popped", file: file, line: line)
        XCTAssertTrue(languageRow.isHittable,
                      "Language row present but not hittable — list left in a bad state", file: file, line: line)

        // (3) App still responsive: the picker can be reopened after the switch.
        let reopenTaps = openPicker(app, languageRow: languageRow, rowID: targetRowID)
        XCTAssertGreaterThan(reopenTaps, 0,
                             "Could not reopen language picker after switch — app unresponsive",
                             file: file, line: line)
    }

    // MARK: - Helpers

    /// Taps the language row until the picker presents (its target row appears),
    /// up to `maxOpenTaps` times. Returns the tap count that opened it, or 0 if it
    /// never opened. (Tolerates the open first-tap presentation race.)
    private func openPicker(_ app: XCUIApplication, languageRow: XCUIElement, rowID: String) -> Int {
        for tap in 1...maxOpenTaps {
            languageRow.tap()
            if element(app, rowID).waitForExistence(timeout: 4) {
                return tap
            }
        }
        return 0
    }

    /// Surfaces the first-tap result every run (console + result-bundle attachment)
    /// so the intermittent race stays visible without making the test flaky.
    private func recordFirstTapOutcome(opened: Bool, taps: Int, target: String) {
        let verdict = opened
            ? "OPENED on first tap"
            : "DID NOT open on first tap — took \(taps) tap(s) (Bug 2 first-tap race)"
        print("[Bug2 first-tap] target=\(target) opened=\(opened) taps=\(taps)")
        XCTContext.runActivity(named: "First-tap (\(target)): \(verdict)") { activity in
            let att = XCTAttachment(string: verdict)
            att.name = "first-tap-\(target)"
            att.lifetime = .keepAlways
            activity.add(att)
        }
    }

    /// Match by accessibility identifier across any element type (SwiftUI List
    /// rows surface inconsistently as button vs. cell).
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Wait until an element no longer exists (works on all Xcode versions).
    private func waitForGone(_ el: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: gone, object: el)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    /// Maps the app's language enum case to the AppleLanguages locale used to force
    /// the launch render language (mirrors GeneralSettingView's mapping).
    private func appleLanguage(for code: String) -> String {
        switch code {
        case "pt": return "pt-BR"
        case "es": return "es-MX"
        default:   return code      // en, ru
        }
    }
}
