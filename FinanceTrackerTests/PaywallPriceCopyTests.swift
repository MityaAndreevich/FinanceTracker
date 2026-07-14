//
//  PaywallPriceCopyTests.swift
//  FinanceTrackerTests
//
//  The paywall's per-month figure and savings badge used to be frozen English
//  strings ("$2.92/month", "Save 42%") that were true in the US storefront and
//  false in every other one. These tests pin the derivation that replaced them,
//  and — more importantly — pin the silences: when StoreKit hasn't given us the
//  facts, the claim must vanish rather than guess.
//

import XCTest
@testable import FinanceTracker

final class PaywallPriceCopyTests: XCTestCase {

    private func usd() -> Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
    }

    // MARK: - Per-month

    /// The shipping product set: $34.99/year. 34.99 ÷ 12 = 2.9158…, which the
    /// currency style rounds to the same $2.92 the old hardcoded string claimed —
    /// the number was never the problem, the fact that it couldn't change was.
    func test_perMonth_dividesTheAnnualPriceByTwelve() {
        let text = PaywallPriceCopy.perMonthText(annualPrice: 34.99, format: usd())
        XCTAssertEqual(text, "$2.92")
    }

    /// A non-USD storefront: the German user is billed in euros, and must see
    /// euros — symbol, placement and comma decimal separator all Apple's, not ours.
    func test_perMonth_formatsInTheStorefrontsOwnCurrencyAndLocale() throws {
        let eur = Decimal.FormatStyle.Currency(code: "EUR", locale: Locale(identifier: "de_DE"))
        let text = try XCTUnwrap(PaywallPriceCopy.perMonthText(annualPrice: 39.99, format: eur))

        XCTAssertTrue(text.contains("€"), "German storefront must show euros, got \(text)")
        XCTAssertTrue(text.contains("3,33"), "39.99 / 12 = 3.3325 → 3,33 (de_DE), got \(text)")
        XCTAssertFalse(text.contains("$"), "A euro price must never render a dollar sign: \(text)")
    }

    /// The pt-BR string literally read "US$ 2,92" — a dollar figure shown to a user
    /// billed in reais. Whatever the annual price is in BRL, the line is in BRL.
    func test_perMonth_brazilianStorefrontShowsReaisNotDollars() throws {
        let brl = Decimal.FormatStyle.Currency(code: "BRL", locale: Locale(identifier: "pt_BR"))
        let text = try XCTUnwrap(PaywallPriceCopy.perMonthText(annualPrice: 199.90, format: brl))

        XCTAssertTrue(text.contains("R$"), "Brazilian storefront must show reais, got \(text)")
        XCTAssertTrue(text.contains("16,66"), "199.90 / 12 = 16.658… → 16,66, got \(text)")
    }

    /// A currency with no minor unit (yen) must not sprout decimals.
    func test_perMonth_respectsCurrenciesWithoutFractionDigits() throws {
        let jpy = Decimal.FormatStyle.Currency(code: "JPY", locale: Locale(identifier: "ja_JP"))
        let text = try XCTUnwrap(PaywallPriceCopy.perMonthText(annualPrice: 5800, format: jpy))

        XCTAssertFalse(text.contains("."), "Yen has no minor unit: \(text)")
        XCTAssertTrue(text.contains("483"), "5800 / 12 = 483.33 → ¥483, got \(text)")
    }

    /// StoreKit hasn't loaded / the product is unavailable → no line at all.
    func test_perMonth_isNilWhenThereIsNoPriceToDivide() {
        XCTAssertNil(PaywallPriceCopy.perMonthText(annualPrice: 0, format: usd()))
        XCTAssertNil(PaywallPriceCopy.perMonthText(annualPrice: -1, format: usd()))
    }

    // MARK: - Savings

    /// $34.99/yr vs $4.99/mo → 1 − (34.99 / 59.88) = 41.56% → 42%.
    func test_savings_isDerivedFromBothProducts() {
        XCTAssertEqual(PaywallPriceCopy.savingsPercent(annualPrice: 34.99, monthlyPrice: 4.99), 42)
    }

    /// The percentage tracks the products. Change either price in App Store Connect
    /// and the badge follows — which is the entire point of the change.
    func test_savings_followsThePrices() {
        XCTAssertEqual(PaywallPriceCopy.savingsPercent(annualPrice: 50, monthlyPrice: 5), 17)
        XCTAssertEqual(PaywallPriceCopy.savingsPercent(annualPrice: 30, monthlyPrice: 5), 50)
        XCTAssertEqual(PaywallPriceCopy.savingsPercent(annualPrice: 599.90, monthlyPrice: 79.90), 37)
    }

    /// The monthly product didn't load, so there is nothing to compare against and
    /// the badge must not appear. This is the case that used to print "Save 42%"
    /// regardless of what the store actually said.
    func test_savings_isNilWithoutAMonthlyProductToCompareAgainst() {
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 34.99, monthlyPrice: nil))
    }

    /// If the annual plan is NOT cheaper, we say nothing. A "saving" that isn't one
    /// is a lie, and we would rather show an empty spot on the card.
    func test_savings_isNilWhenTheAnnualPlanSavesNothing() {
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 59.88, monthlyPrice: 4.99),
                     "Identical cost over a year is not a saving")
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 79.99, monthlyPrice: 4.99),
                     "The annual plan costing MORE must never be badged as a saving")
    }

    func test_savings_isNilOnNonPositivePrices() {
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 0, monthlyPrice: 4.99))
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 34.99, monthlyPrice: 0))
    }

    /// A rounding-to-zero saving (fractions of a percent) is not worth claiming.
    func test_savings_isNilWhenItRoundsAwayToNothing() {
        XCTAssertNil(PaywallPriceCopy.savingsPercent(annualPrice: 59.87, monthlyPrice: 4.99))
    }

    // MARK: - 5-locale parity

    /// Both strings are now format strings, and a placeholder that went missing in
    /// translation would print the price nowhere and the percent nowhere. The
    /// key-set parity test can't see this: it compares keys, not their contents.
    func test_bothFormatStringsCarryTheirPlaceholdersInAllFiveLocales() {
        for locale in ["en", "ru", "es", "pt-BR", "uk"] {
            guard
                let path = Bundle.main.path(forResource: "Localizable",
                                            ofType: "strings",
                                            inDirectory: nil,
                                            forLocalization: locale),
                let dict = NSDictionary(contentsOfFile: path) as? [String: String]
            else {
                XCTFail("Missing locale: \(locale)")
                continue
            }

            let perMonth = dict["paywall.yearly.per_month.format"]
            XCTAssertNotNil(perMonth, "per_month format missing in \(locale)")
            XCTAssertTrue(perMonth?.contains("%@") == true,
                          "\(locale) per_month lost its price placeholder: \(perMonth ?? "nil")")

            let savings = dict["paywall.yearly.save_amount.format"]
            XCTAssertNotNil(savings, "save_amount format missing in \(locale)")
            XCTAssertTrue(savings?.contains("%d") == true,
                          "\(locale) save_amount lost its percent placeholder: \(savings ?? "nil")")

            // The whole point of the change: no price and no percent may be frozen
            // into the copy. If someone pastes one back in, this fails.
            for (key, value) in [("per_month", perMonth ?? ""), ("save_amount", savings ?? "")] {
                XCTAssertFalse(value.contains("2.92") || value.contains("2,92"),
                               "\(locale) \(key) has a hardcoded price again: \(value)")
                XCTAssertFalse(value.contains("42"),
                               "\(locale) \(key) has a hardcoded percent again: \(value)")
                XCTAssertFalse(value.contains("$") || value.contains("€") || value.contains("R$"),
                               "\(locale) \(key) hardcodes a currency symbol: \(value)")
            }
        }
    }

    /// The old keys must be gone, not merely unused — a stale
    /// "paywall.yearly.per_month" left in the files is a loaded gun for the next
    /// person who wires up a Text() by key.
    func test_theHardcodedPriceKeysAreGoneFromEveryLocale() {
        for locale in ["en", "ru", "es", "pt-BR", "uk"] {
            guard
                let path = Bundle.main.path(forResource: "Localizable",
                                            ofType: "strings",
                                            inDirectory: nil,
                                            forLocalization: locale),
                let dict = NSDictionary(contentsOfFile: path) as? [String: String]
            else {
                XCTFail("Missing locale: \(locale)")
                continue
            }

            XCTAssertNil(dict["paywall.yearly.per_month"],
                         "\(locale) still ships the hardcoded per-month string")
            XCTAssertNil(dict["paywall.yearly.save_amount"],
                         "\(locale) still ships the hardcoded savings string")
        }
    }
}
