import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - In-memory container helper

private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
        configurations: config
    )
    return ModelContext(container)
}

private func makeCategory(name: String, kindRaw: String, in ctx: ModelContext) -> FinanceTracker.Category {
    let cat = FinanceTracker.Category(name: name, kindRaw: kindRaw, order: 0)
    ctx.insert(cat)
    return cat
}

// MARK: - QuickAddSaveService tests

@Suite("QuickAddSaveService")
@MainActor
struct QuickAddSaveServiceTests {

    // MARK: - save

    @Test func test_save_validInput_createsTransaction() throws {
        let ctx = try makeContext()
        let _ = makeCategory(name: "Food & Drink", kindRaw: "expense", in: ctx)
        let _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 550,
            typeRaw: "expense",
            merchant: "Starbucks",
            suggestedCategoryName: "Food & Drink"
        )
        let tx = try QuickAddSaveService.save(
            parsed: parsed,
            modelContext: ctx,
            defaultCurrencyCode: "USD"
        )

        #expect(tx.amountCents == 550)
        #expect(tx.typeRaw == "expense")
        #expect(tx.merchant == "Starbucks")
        #expect(tx.currency == "USD")
    }

    @Test func test_save_validInput_recordsLearning() throws {
        let ctx = try makeContext()
        let _ = makeCategory(name: "Food & Drink", kindRaw: "expense", in: ctx)
        let _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 1200,
            typeRaw: "expense",
            merchant: "Starbucks",
            suggestedCategoryName: "Food & Drink"
        )
        _ = try QuickAddSaveService.save(
            parsed: parsed,
            modelContext: ctx,
            defaultCurrencyCode: "USD"
        )

        let learned = MerchantLearningService.suggestedCategoryName(for: "Starbucks", in: ctx)
        #expect(learned == "Food & Drink")
    }

    /// Contract behind QuickEntry's "Save & add another": the button re-runs the SAME
    /// guarded save path and stays on-screen, so logging several entries in a row must
    /// persist one row per successful save, and a failed save in the middle must roll
    /// back (leaving the earlier rows intact) rather than advancing. The view-level
    /// form-clear / re-focus is SwiftUI state and not unit-testable; this pins the
    /// persistence guarantee the feature depends on.
    @Test func test_saveAddAnother_sequencePersistsOnePerSave_andFailureRollsBack() throws {
        let ctx = try makeContext()
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // Two successful "Save & add another" taps (distinct entries to avoid the 30s
        // dedup window) → exactly two rows.
        _ = try QuickAddSaveService.save(
            parsed: QuickAddParsedInput(amountCents: 550, typeRaw: "expense", merchant: "Coffee", suggestedCategoryName: nil),
            modelContext: ctx, defaultCurrencyCode: "USD"
        )
        _ = try QuickAddSaveService.save(
            parsed: QuickAddParsedInput(amountCents: 900, typeRaw: "expense", merchant: "Lunch", suggestedCategoryName: nil),
            modelContext: ctx, defaultCurrencyCode: "USD"
        )
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2)

        // A failed save (guarded rollback path) must NOT clear/advance: it throws and
        // leaves the store at the two already-persisted rows.
        QuickAddSaveService._forceSaveFailureForTesting = true
        defer { QuickAddSaveService._forceSaveFailureForTesting = false }
        #expect(throws: (any Error).self) {
            _ = try QuickAddSaveService.save(
                parsed: QuickAddParsedInput(amountCents: 1300, typeRaw: "expense", merchant: "Taxi", suggestedCategoryName: nil),
                modelContext: ctx, defaultCurrencyCode: "USD"
            )
        }
        QuickAddSaveService._forceSaveFailureForTesting = false
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2)
    }

    @Test func test_save_unresolvableCategory_throws() throws {
        let ctx = try makeContext()
        // No categories at all — resolveCategory returns nil

        let parsed = QuickAddParsedInput(
            amountCents: 500,
            typeRaw: "expense",
            merchant: nil,
            suggestedCategoryName: nil
        )
        #expect(throws: QuickAddSaveService.SaveError.noCategoryResolvable) {
            _ = try QuickAddSaveService.save(
                parsed: parsed,
                modelContext: ctx,
                defaultCurrencyCode: "USD"
            )
        }
    }

    // MARK: - Idempotency / dedup (Bug 4)

    @Test func test_duplicateWithin30s_returnsExisting() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let now = Date()
        let first = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", now: now
        )
        let second = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", now: now.addingTimeInterval(5)
        )

        #expect(first.uuid == second.uuid, "second save within 30s must return the same transaction")
        let count = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(count == 1, "only one row should exist after a duplicate save")
    }

    @Test func test_sameAmountDifferentMerchant_savesBoth() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let now = Date()
        let a = QuickAddParsedInput(amountCents: 550, typeRaw: "expense", merchant: "Starbucks", suggestedCategoryName: nil)
        let b = QuickAddParsedInput(amountCents: 550, typeRaw: "expense", merchant: "Costa", suggestedCategoryName: nil)
        let txA = try QuickAddSaveService.save(parsed: a, modelContext: ctx, defaultCurrencyCode: "USD", now: now)
        let txB = try QuickAddSaveService.save(parsed: b, modelContext: ctx, defaultCurrencyCode: "USD", now: now)

        #expect(txA.uuid != txB.uuid)
        let count = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(count == 2, "same amount but different merchant are distinct transactions")
    }

    @Test func test_sameTransactionAfter31s_savesAgain() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let now = Date()
        let first = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", now: now
        )
        let second = try QuickAddSaveService.save(
            parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", now: now.addingTimeInterval(31)
        )

        #expect(first.uuid != second.uuid, "after the 30s window the same input creates a new transaction")
        let count = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(count == 2)
    }

    // MARK: - resolveCategory

    @Test func test_resolveCategory_learnedWins_overParsedSuggestion() throws {
        let ctx = try makeContext()
        let foodCat = makeCategory(name: "Food & Drink", kindRaw: "expense", in: ctx)
        let otherCat = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // Pre-record Starbucks → Other (user override)
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Other", in: ctx)

        // Parser would suggest "Food & Drink" for Starbucks, but learned should win
        let parsed = QuickAddParsedInput(
            amountCents: 550,
            typeRaw: "expense",
            merchant: "Starbucks",
            suggestedCategoryName: foodCat.name
        )
        let resolved = QuickAddSaveService.resolveCategory(for: parsed, in: ctx)
        #expect(resolved?.name == otherCat.name, "learned mapping should override parser suggestion")
    }

    @Test func test_resolveCategory_parsedSuggestion_whenNoLearning() throws {
        let ctx = try makeContext()
        let foodCat = makeCategory(name: "Food & Drink", kindRaw: "expense", in: ctx)
        let _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        let parsed = QuickAddParsedInput(
            amountCents: 550,
            typeRaw: "expense",
            merchant: "SomeNewCafe",
            suggestedCategoryName: "Food & Drink"
        )
        let resolved = QuickAddSaveService.resolveCategory(for: parsed, in: ctx)
        #expect(resolved?.name == foodCat.name)
    }

    @Test func test_resolveCategory_otherFallback_whenNoSuggestion() throws {
        let ctx = try makeContext()
        let otherCat = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // No merchant, no suggestion → should fall back to "Other"
        let parsed = QuickAddParsedInput(
            amountCents: 500,
            typeRaw: "expense",
            merchant: nil,
            suggestedCategoryName: nil
        )
        let resolved = QuickAddSaveService.resolveCategory(for: parsed, in: ctx)
        #expect(resolved?.name == otherCat.name, "should fall back to Other when no suggestion")
    }

    // MARK: - previewCategory (voice / + screen) — Sprint B patch (device test #5)

    @Test func test_previewCategory_learnedMerchant_returnsLearned_notOther() throws {
        let ctx = try makeContext()
        let mashina = makeCategory(name: "Машина", kindRaw: "expense", in: ctx)
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // User taught Бензин → Машина (e.g. by manually picking it once).
        MerchantLearningService.record(merchant: "Бензин", categoryName: "Машина", in: ctx)

        let parsed = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let preview = QuickAddSaveService.previewCategory(for: parsed, in: ctx)
        #expect(preview?.name == mashina.name, "voice preview must honor the learned merchant mapping")
    }

    @Test func test_previewCategory_unknownMerchant_fallsBackToOther_noKeywordGuess() throws {
        let ctx = try makeContext()
        _ = makeCategory(name: "Food & Drink", kindRaw: "expense", in: ctx)
        let other = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // "coffee" keyword-maps to Food & Drink, but the + screen must NOT apply a
        // mere keyword guess to an untaught merchant (Round 8) — it stays Other.
        let parsed = QuickAddParsedInput(
            amountCents: 500, typeRaw: "expense", merchant: "coffee", suggestedCategoryName: "Food & Drink"
        )
        let preview = QuickAddSaveService.previewCategory(for: parsed, in: ctx)
        #expect(preview?.name == other.name, "untaught expense stays Other on the + screen — no keyword guess")
    }

    @Test func testVoicePath_remembersAndLookups() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        let mashina = makeCategory(name: "Машина", kindRaw: "expense", in: ctx)
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()

        // First voice save: the user manually picked Машина (overrideCategory),
        // which the save path records as learning for "Бензин".
        let first = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        _ = try QuickAddSaveService.save(
            parsed: first, modelContext: ctx, defaultCurrencyCode: "USD",
            overrideCategory: mashina, now: Date()
        )

        // Next voice entry of the same merchant, no override: previewCategory must
        // now look up the learned mapping → Машина, not Без категории.
        let second = QuickAddParsedInput(
            amountCents: 20_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let preview = QuickAddSaveService.previewCategory(for: second, in: ctx)
        #expect(preview?.name == mashina.name, "voice learns: a taught merchant suggests Машина next time")
    }

    @Test func testInconsistency_DashboardAndVoice_sameMerchant_sameCategory() throws {
        let ctx = try makeContext()
        let mashina = makeCategory(name: "Машина", kindRaw: "expense", in: ctx)
        _ = makeCategory(name: "Other", kindRaw: "expense", in: ctx)
        try ctx.save()
        MerchantLearningService.record(merchant: "Бензин", categoryName: "Машина", in: ctx)

        let parsed = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let dashboard = QuickAddSaveService.resolveCategory(for: parsed, in: ctx)
        let voice = QuickAddSaveService.previewCategory(for: parsed, in: ctx)
        #expect(dashboard?.name == mashina.name)
        #expect(voice?.name == mashina.name)
        #expect(dashboard?.uuid == voice?.uuid, "Dashboard and voice resolve the same learned category")
    }
}
