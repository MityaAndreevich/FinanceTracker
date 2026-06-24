//
//  QuickAddParserTests.swift
//  FinanceTrackerTests
//

import Testing
@testable import FinanceTracker

@Suite("QuickAddParser")
struct QuickAddParserTests {

    @Test func parse_amount_only_no_merchant() {
        let result = QuickAddParser.parse("$5.50")
        #expect(result?.amountCents == 550)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == nil)
        #expect(result?.suggestedCategoryName == nil)
    }

    @Test func parse_amount_merchant_category() {
        let result = QuickAddParser.parse("$5.50 Starbucks")
        #expect(result?.amountCents == 550)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Starbucks")
        // Starbucks is a coffee brand now mapped to the consolidated Food & Drink category
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_income_with_plus_sign() {
        let result = QuickAddParser.parse("+2800 paycheck")
        #expect(result?.amountCents == 280000)
        #expect(result?.typeRaw == "income")
    }

    @Test func parse_european_decimal() {
        let result = QuickAddParser.parse("12,99 spotify")
        #expect(result?.amountCents == 1299)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "spotify")
        #expect(result?.suggestedCategoryName == "Subscriptions")
    }

    @Test func parse_empty_returns_nil() {
        #expect(QuickAddParser.parse("") == nil)
    }

    @Test func parse_no_amount_returns_nil() {
        #expect(QuickAddParser.parse("just text") == nil)
    }
}
