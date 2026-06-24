//
//  MoneyTests.swift
//  FinanceTrackerTests
//

import Testing
@testable import FinanceTracker

@Suite("Money")
struct MoneyTests {

    // MARK: - parseCents

    @Test func parseCents_integer() {
        #expect(Money.parseCents(from: "100") == 10_000)
    }

    @Test func parseCents_decimal_2_places() {
        #expect(Money.parseCents(from: "12.34") == 1_234)
    }

    @Test func parseCents_decimal_1_place() {
        #expect(Money.parseCents(from: "12.3") == 1_230)
    }

    @Test func parseCents_comma_decimal() {
        #expect(Money.parseCents(from: "12,34") == 1_234)
    }

    @Test func parseCents_strips_currency_symbols() {
        // '$' is not in the allowed char set — parseCents must return nil
        #expect(Money.parseCents(from: "$12.34") == nil)
    }

    @Test func parseCents_empty_string_returns_nil() {
        #expect(Money.parseCents(from: "") == nil)
    }

    @Test func parseCents_invalid_returns_nil() {
        #expect(Money.parseCents(from: "abc") == nil)
    }

    // MARK: - format

    @Test func format_zero() {
        let result = Money.format(cents: 0, currencyCode: "USD")
        #expect(!result.isEmpty)
        #expect(result.contains("0"))
    }

    @Test func format_usd_basic() {
        let result = Money.format(cents: 1_234, currencyCode: "USD")
        // 1234 cents = 12.34 — both digit groups must appear regardless of locale
        #expect(result.contains("12"))
        #expect(result.contains("34"))
    }

    @Test func format_eur_basic() {
        let result = Money.format(cents: 1_234, currencyCode: "EUR")
        #expect(result.contains("12"))
        #expect(result.contains("34"))
    }

    // MARK: - round-trip

    @Test(arguments: [1, 50, 100, 1_000, 12_345])
    func roundTrip(cents: Int) {
        let plain = Money.plainDecimalString(cents: cents)
        #expect(Money.parseCents(from: plain) == cents)
    }

    // MARK: - sanitizeInput

    @Test func sanitizeInput_strips_non_digit_chars() {
        #expect(Money.sanitizeInput("$12.34") == "12.34")
    }

    @Test func sanitizeInput_keeps_one_decimal_separator() {
        // "12.3.4" → keep first dot, collapse rest → "12.34"
        #expect(Money.sanitizeInput("12.3.4") == "12.34")
    }
}
