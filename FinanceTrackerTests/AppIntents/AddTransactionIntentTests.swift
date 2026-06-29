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

    // MARK: - Bug 8: sign + income-vocabulary direction detection

    @Test func test_effectiveType_incomeVocabularyPromotesDefaultExpense() {
        // "+50 paycheck": defaulted expense, but "paycheck" is income vocabulary.
        #expect(AddTransactionIntent.effectiveTypeRaw(
            explicitType: "expense", merchant: "paycheck", amount: 50) == "income")
    }

    @Test func test_effectiveType_plainMerchantStaysExpense() {
        #expect(AddTransactionIntent.effectiveTypeRaw(
            explicitType: "expense", merchant: "milk", amount: 12) == "expense")
    }

    @Test func test_effectiveType_negativeAmountForcesExpense() {
        // A negative amount is an expense even if the merchant reads like income.
        #expect(AddTransactionIntent.effectiveTypeRaw(
            explicitType: "expense", merchant: "salary", amount: -50) == "expense")
    }

    @Test func test_effectiveType_explicitIncomeAlwaysWins() {
        #expect(AddTransactionIntent.effectiveTypeRaw(
            explicitType: "income", merchant: "random", amount: 30) == "income")
    }

    @Test func test_effectiveType_nilMerchantDefaultsExpense() {
        #expect(AddTransactionIntent.effectiveTypeRaw(
            explicitType: "expense", merchant: nil, amount: 5) == "expense")
    }

    // Income "paycheck" resolves to the Income category, not Other/Food.
    @Test func test_income_paycheck_resolvesIncomeCategory() throws {
        let ctx = try makeIntentContext()
        seedCategory(name: "Income", kindRaw: "income", ctx: ctx)
        seedCategory(name: "Other", ctx: ctx)
        try ctx.save()

        // Mirrors the intent's parsed-input path: income type + Income category.
        let parsed = QuickAddParsedInput(
            amountCents: 5000,
            typeRaw: "income",
            merchant: "paycheck",
            suggestedCategoryName: "Income"
        )
        let income = seededIncome(ctx: ctx)
        let tx = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", overrideCategory: income)
        #expect(tx.typeRaw == "income")
        #expect(tx.category.name == "Income")
    }

    private func seededIncome(ctx: ModelContext) -> FinanceTracker.Category {
        let all = (try? ctx.fetch(FetchDescriptor<FinanceTracker.Category>())) ?? []
        return all.first { $0.name == "Income" }!
    }
}
