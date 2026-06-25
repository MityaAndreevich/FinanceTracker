import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Helpers (shared with CategoryEntityTests via same module)

private func makeIntentContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
        configurations: config
    )
    return ModelContext(container)
}

private func seedCategory(name: String, kindRaw: String = "expense", ctx: ModelContext) -> FinanceTracker.Category {
    let cat = FinanceTracker.Category(name: name, kindRaw: kindRaw, order: 0)
    ctx.insert(cat)
    return cat
}

// MARK: - Tests
// These tests exercise the QuickAddSaveService path that AddTransactionIntent.perform() uses,
// keeping them fast and free of AppIntents framework dependencies.

@Suite("AddTransactionIntent — save path")
@MainActor
struct AddTransactionIntentTests {

    @Test func test_save_validAmount_createsTransaction() throws {
        let ctx = try makeIntentContext()
        seedCategory(name: "Food & Drink", ctx: ctx)
        seedCategory(name: "Other", ctx: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 1200,
            typeRaw: "expense",
            merchant: nil,
            suggestedCategoryName: "Food & Drink"
        )
        let tx = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD")

        #expect(tx.amountCents == 1200)
        #expect(tx.typeRaw == "expense")
        #expect(tx.currency == "USD")
    }

    @Test func test_save_noCategory_fallsBackToOther() throws {
        let ctx = try makeIntentContext()
        seedCategory(name: "Other", ctx: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 500,
            typeRaw: "expense",
            merchant: nil,
            suggestedCategoryName: nil
        )
        let tx = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD")

        #expect(tx.category.name == "Other")
    }

    @Test func test_save_nilMerchant_savesWithoutMerchant() throws {
        let ctx = try makeIntentContext()
        seedCategory(name: "Other", ctx: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 999,
            typeRaw: "expense",
            merchant: nil,
            suggestedCategoryName: nil
        )
        let tx = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx, defaultCurrencyCode: "EUR")

        #expect(tx.merchant == nil)
        #expect(tx.currency == "EUR")
    }

    @Test func test_save_withMerchant_recordsLearning() throws {
        let ctx = try makeIntentContext()
        seedCategory(name: "Coffee", ctx: ctx)
        seedCategory(name: "Other", ctx: ctx)
        try ctx.save()

        // Use a merchant name absent from the static keyword table so the
        // resolved category comes from suggestedCategoryName, not the static map.
        let parsed = QuickAddParsedInput(
            amountCents: 450,
            typeRaw: "expense",
            merchant: "MyLocalCafe",
            suggestedCategoryName: "Coffee"
        )
        _ = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD")

        let suggested = CategorySuggestionService.suggest(forMerchant: "MyLocalCafe", in: ctx)
        #expect(suggested == "Coffee")
    }

    @Test func test_transactionTypeAppEnum_rawValues() {
        #expect(TransactionTypeAppEnum.expense.rawValue == "expense")
        #expect(TransactionTypeAppEnum.income.rawValue == "income")
    }
}
