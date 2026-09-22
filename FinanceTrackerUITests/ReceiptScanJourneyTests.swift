//
//  ReceiptScanJourneyTests.swift
//  FinanceTrackerUITests
//
//  DESIGN_RECEIPT_SCAN.md §9, founder's Phase 2 item 2. The picker and the
//  camera cannot be driven from XCUITest, so `--scan-fixture-text` (DEBUG-only,
//  ReceiptScanDebugSeam) renders a receipt image in-process and hands it to the
//  REAL Vision recogniser and the REAL parser — nothing downstream is stubbed.
//
//  Journey: Quick Entry → scan → "Choose screenshot" (the seam) → review sheet
//  shows the scanned amount → Use these → the form is prefilled → Add → the
//  transaction exists → a SECOND scan of the same merchant prefills the
//  category chip, which is merchant learning having fired on the first save.
//
//  Cap (S1): 5th scan works, 6th meets the paywall (PRESENCE of the paywall
//  title, not absence of the review sheet); a count from LAST month is ignored.
//
//  Erase the simulator before a full run (scripts/run-tests.sh:161).
//

import XCTest

final class ReceiptScanJourneyTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private static let fixture = "Corner Shop|Milk 2.49|Bread 3.10|Subtotal 5.59|Tax 0.45|Total 6.04"

    private func monthKey(offsetMonths: Int = 0) -> String {
        let cal = Calendar.current
        let d = cal.date(byAdding: .month, value: offsetMonths, to: Date())!
        let c = cal.dateComponents([.year, .month], from: d)
        return String(format: "receiptScan.count.%04d-%02d", c.year!, c.month!)
    }

    /// Every launch pins THIS month's scan count through the DEBUG seam (which
    /// also wipes any other month's key), because the app's writes persist in
    /// the shared container across tests — a `-key value` launch pair would only
    /// mask reads in this process while the next test inherited the writes.
    private func launch(quotaCount: Int = 0, extra: [String] = [], lapsedFreeUser: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasSeenFeatureTour", "YES",
            "-appLanguageCode", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-defaultCurrencyCode", "USD",
        ]
        app.launchArguments += extra
        app.launchArguments.append("--suppress-rating-prompt")
        app.launchArguments += ["--scan-quota-count", String(quotaCount)]
        if lapsedFreeUser { app.launchArguments.append("--expire-reverse-trial") }
        app.launchArguments += ["--scan-fixture-text", Self.fixture]
        app.launch()
        if lapsedFreeUser {
            // A lapsed launch auto-raises the trial-end paywall over everything
            // (MonetizationGateFlowTests.dismissTrialEndPaywall). Close it first.
            let notice = app.staticTexts["Your 14-day preview has ended"]
            if notice.waitForExistence(timeout: 25) { app.buttons["Close"].firstMatch.tap() }
        }
        return app
    }

    /// A SwiftUI `Menu` is exposed to XCUITest by its accessibility LABEL, not its
    /// identifier — so the query is by the localized label with the identifier as
    /// a fallback.
    private func scanButton(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Scan a receipt' OR identifier == 'receipt_scan_button'"))
            .firstMatch
    }

    /// + tab → Quick Entry → scan menu → "Choose screenshot" (the seam).
    private func startScan(_ app: XCUIApplication) {
        let plus = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(plus.waitForExistence(timeout: 20), "+ tab never appeared")
        plus.tap()
        let scan = scanButton(app)
        XCTAssertTrue(scan.waitForExistence(timeout: 10), "scan button missing from Quick Entry")
        scan.tap()
        let choose = app.buttons["Choose screenshot"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5), "the scan menu did not open")
        choose.tap()
    }

    func test_scanJourney_prefillsSavesAndLearnsTheMerchant() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        // 1st scan: the review sheet shows the parsed grand total, not the subtotal.
        startScan(app)
        let amount = app.staticTexts["scan_review_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 30), "the review sheet did not show an amount — recognition or parsing failed")
        XCTAssertTrue(amount.label.contains("6.04"), "expected the grand total 6.04, got \(amount.label)")
        // LabeledContent exposes "Merchant, Corner Shop" as one label.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Corner Shop'")).firstMatch.exists,
                      "merchant not recognised")

        app.buttons["scan_review_use"].tap()

        // The form is prefilled from the scan.
        let amountField = app.textFields["0.00"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 10), "the form did not open")
        // The prefill is applied in .onAppear — one render after the field exists.
        let prefilled = expectation(for: NSPredicate(format: "value == '6.04'"), evaluatedWith: amountField)
        wait(for: [prefilled], timeout: 5)
        XCTAssertEqual(amountField.value as? String, "6.04", "the amount was not prefilled")
        // Two "Add" buttons exist (toolbar, "Add category"); the toolbar's is in the nav bar.
        let addButton = app.navigationBars.buttons["Add"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addButton.isEnabled, "Add is disabled — the prefill left the form invalid")
        addButton.tap()

        // The transaction exists.
        let txTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(txTab.waitForExistence(timeout: 10))
        txTab.tap()
        XCTAssertTrue(app.staticTexts["Corner Shop"].waitForExistence(timeout: 15), "the saved transaction is not in the list")

        // 2nd scan of the same merchant: the category chip is prefilled — that is
        // MerchantLearningService.record having fired on the first save.
        startScan(app)
        XCTAssertTrue(app.staticTexts["scan_review_amount"].waitForExistence(timeout: 30))
        app.buttons["scan_review_use"].tap()
        let chip = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Auto-detected:'")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "no 'Auto-detected' chip — merchant learning did not fire on the first save")
    }

    func test_cap_fifthScanWorks_sixthMeetsThePaywall() {
        // A lapsed free user who has already scanned four times this month.
        let app = launch(quotaCount: 4, lapsedFreeUser: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        startScan(app)
        XCTAssertTrue(app.staticTexts["scan_review_amount"].waitForExistence(timeout: 30), "the 5th scan must work")
        app.buttons["Cancel"].firstMatch.tap()

        // 6th: the paywall, asserted by its title's PRESENCE.
        let scan = scanButton(app)
        XCTAssertTrue(scan.waitForExistence(timeout: 10))
        scan.tap()
        let choose = app.buttons["Choose screenshot"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        XCTAssertTrue(app.staticTexts["Own your money, on your iPhone forever"].waitForExistence(timeout: 15),
                      "the 6th scan did not meet the paywall")
    }

    func test_cap_lastMonthsCountDoesNotCarryOver() {
        // Last month's key is written persistently by a `-key value` pair (it is
        // never written by the app, so the argument domain is the only source);
        // this month's is pinned to 0 by the seam.
        let app = launch(quotaCount: 0, extra: ["-\(monthKey(offsetMonths: -1))", "5"], lapsedFreeUser: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        startScan(app)
        XCTAssertTrue(app.staticTexts["scan_review_amount"].waitForExistence(timeout: 30),
                      "last month's five scans blocked this month's first")
    }
}
