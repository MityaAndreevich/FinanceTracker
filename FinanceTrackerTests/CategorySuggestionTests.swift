//
//  CategorySuggestionTests.swift
//  FinanceTrackerTests
//

import Testing
import SwiftData
@testable import FinanceTracker

@Suite("CategorySuggestionService")
struct CategorySuggestionTests {

    // MARK: - QuickAdd regression (the "67$ gas" bug)

    @Test func parse_67gas_suggestsTransport() {
        let result = QuickAddParser.parse("67$ gas")
        #expect(result?.suggestedCategoryName == "Transport",
                "bare word 'gas' should map to Transport, not nil or Food")
    }

    @Test func parse_lunch12_suggestsFoodDrink() {
        let result = QuickAddParser.parse("lunch 12")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_haircut25_suggestsHealth() {
        let result = QuickAddParser.parse("haircut 25")
        #expect(result?.suggestedCategoryName == "Health")
    }

    @Test func parse_unknownWord_suggestsNil() {
        let result = QuickAddParser.parse("xyzqrs 5")
        #expect(result?.suggestedCategoryName == nil,
                "completely unknown input must not produce a false positive")
    }

    // MARK: - Word-boundary matching

    @Test func containsWord_exactWord() {
        let result = CategorySuggestionService.suggest(forMerchant: "67 gas")
        #expect(result == "Transport")
    }

    @Test func containsWord_wordInPhrase() {
        let result = CategorySuggestionService.suggest(forMerchant: "gas station")
        #expect(result == "Transport")
    }

    @Test func containsWord_substring_noMatch() {
        // "gas" inside "gassed" should NOT match
        let result = CategorySuggestionService.suggest(forMerchant: "gassed up")
        // "gassed" doesn't hit word boundary for "gas"; may return nil or a different match
        #expect(result != "Transport")
    }

    @Test func containsWord_caseInsensitive() {
        let result = CategorySuggestionService.suggest(forMerchant: "GAS")
        #expect(result == "Transport")
    }

    @Test func containsWord_russian() {
        let result = CategorySuggestionService.suggest(forMerchant: "купил кофе")
        #expect(result == "Food & Drink")
    }

    // MARK: - Category consolidation (new taxonomy)

    @Test func starbucks_mapsTo_foodDrink() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Starbucks") == "Food & Drink")
    }

    @Test func wholefoods_mapsTo_foodDrink() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Whole Foods") == "Food & Drink")
    }

    @Test func shell_mapsTo_transport() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Shell") == "Transport")
    }

    @Test func uber_mapsTo_transport() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Uber") == "Transport")
    }

    @Test func comcast_mapsTo_housing() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Comcast") == "Housing")
    }

    @Test func amazon_mapsTo_shopping() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Amazon") == "Shopping")
    }

    @Test func netflix_mapsTo_subscriptions() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Netflix") == "Subscriptions")
    }

    @Test func walgreens_mapsTo_health() {
        #expect(CategorySuggestionService.suggest(forMerchant: "Walgreens") == "Health")
    }

    @Test func amc_mapsTo_entertainment() {
        #expect(CategorySuggestionService.suggest(forMerchant: "AMC") == "Entertainment")
    }

    // MARK: - Bare words

    @Test func bareWord_coffee_foodDrink() {
        #expect(CategorySuggestionService.suggest(forMerchant: "coffee") == "Food & Drink")
    }

    @Test func bareWord_dinner_foodDrink() {
        #expect(CategorySuggestionService.suggest(forMerchant: "dinner") == "Food & Drink")
    }

    @Test func bareWord_taxi_transport() {
        #expect(CategorySuggestionService.suggest(forMerchant: "taxi") == "Transport")
    }

    @Test func bareWord_rent_housing() {
        #expect(CategorySuggestionService.suggest(forMerchant: "rent") == "Housing")
    }

    @Test func bareWord_subscription_subscriptions() {
        #expect(CategorySuggestionService.suggest(forMerchant: "subscription") == "Subscriptions")
    }

    @Test func bareWord_doctor_health() {
        #expect(CategorySuggestionService.suggest(forMerchant: "doctor") == "Health")
    }

    @Test func emptyInput_returnsNil() {
        #expect(CategorySuggestionService.suggest(forMerchant: "") == nil)
    }

    @Test func singleCharInput_returnsNil() {
        #expect(CategorySuggestionService.suggest(forMerchant: "x") == nil)
    }

    // MARK: - Learned priority integration

    @Test func test_suggest_priority_learnedBeatsKeyword() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MerchantCategoryLearning.self, configurations: config)
        let ctx = ModelContext(container)
        MerchantLearningService.record(merchant: "starbucks", categoryName: "Other", in: ctx)
        let result = CategorySuggestionService.suggest(forMerchant: "starbucks", in: ctx)
        #expect(result == "Other",
                "learned mapping must beat brand lookup (brand lookup would return 'Food & Drink')")
    }

    @Test func test_suggest_priority_learnedBeatsBareword() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MerchantCategoryLearning.self, configurations: config)
        let ctx = ModelContext(container)
        MerchantLearningService.record(merchant: "gas", categoryName: "Other", in: ctx)
        let result = CategorySuggestionService.suggest(forMerchant: "gas", in: ctx)
        #expect(result == "Other",
                "learned mapping must beat shortKeywords bare-word match (which would return 'Transport')")
    }
}
