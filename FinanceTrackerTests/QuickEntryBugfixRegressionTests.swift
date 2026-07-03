import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// Regression guards for the Quick Entry / save / parse / i18n bug-fix pass.
//
//  B1 — one Save writes exactly one row (with the previewed category).
//  B4 — a valid NL entry ("50 кофе") parses to amount + merchant + category.
//  B5 — seeded category names resolve to their LOCALIZED display name (no raw
//       English "Food & Drink" leaking under a Russian UI).
@Suite("QuickEntry bug-fix regressions")
@MainActor
struct QuickEntryBugfixRegressionTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
            MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @discardableResult
    private func seed(name: String, nameKey: String? = nil, kind: String, in ctx: ModelContext)
        -> FinanceTracker.Category {
        let cat = FinanceTracker.Category(name: name, kindRaw: kind, order: 0, nameKey: nameKey)
        ctx.insert(cat)
        return cat
    }

    // MARK: - B4: NL parse detects amount + merchant + category

    @Test func parse_ru_amount_then_merchant_detectsCategory() {
        let p = QuickAddParser.parse("50 кофе")
        #expect(p?.amountCents == 5_000)
        #expect(p?.typeRaw == "expense")
        #expect(p?.merchant == "Кофе")
        #expect(p?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_ru_merchant_then_amount_detectsCategory() {
        let p = QuickAddParser.parse("Кофе 1000")
        #expect(p?.amountCents == 100_000)
        #expect(p?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_ru_currencyWord_stripped_detectsCategory() {
        // "350₽ кофе" — the ₽ symbol must not defeat amount or category detection.
        let p = QuickAddParser.parse("350₽ кофе")
        #expect(p?.amountCents == 35_000)
        #expect(p?.suggestedCategoryName == "Food & Drink")
    }

    // MARK: - B1: one Save == one row, using the previewed category

    @Test func save_withOverrideCategory_writesExactlyOneRow() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        let food = seed(name: "Food & Drink", nameKey: "category.food_drink", kind: "expense", in: ctx)
        seed(name: "Other", nameKey: "category.other", kind: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 5_000, typeRaw: "expense", merchant: "Кофе",
            suggestedCategoryName: "Food & Drink"
        )
        let tx = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "RUB",
            overrideCategory: food
        )

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == 1)
        #expect(tx.amountCents == 5_000)
        #expect(tx.category.uuid == food.uuid)   // saved category == the previewed one
    }

    @Test func save_sameEntryTwiceWithin30s_staysOneRow() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        let food = seed(name: "Food & Drink", nameKey: "category.food_drink", kind: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 5_000, typeRaw: "expense", merchant: "Кофе",
            suggestedCategoryName: "Food & Drink"
        )
        let now = Date()
        _ = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx,
                                         defaultCurrencyCode: "RUB", overrideCategory: food, now: now)
        _ = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx,
                                         defaultCurrencyCode: "RUB", overrideCategory: food, now: now)

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == 1)   // idempotent — no accidental double
    }

    // MARK: - B5: localized category display name (no English leak in RU)

    @Test func categoryDisplayName_resolvesLocalized_ru() throws {
        let ctx = try makeContext()
        let food = seed(name: "Food & Drink", nameKey: "category.food_drink", kind: "expense", in: ctx)

        let ruLproj = Bundle.main.path(forResource: "ru", ofType: "lproj")
        let ruBundle = try #require(ruLproj.flatMap { Bundle(path: $0) })

        let localized = food.displayName(bundle: ruBundle)
        #expect(localized == "Еда и напитки")
        #expect(localized != "Food & Drink")   // the raw English seed name must not leak
    }
}
