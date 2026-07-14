import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Bug 34.5 (Round 9): inline category create "save failed" at scale
//
// Device test #8: after many transactions, creating a category inline on the +
// screen showed "Не удалось сохранить транзакцию" (add.error.save_failed) — and
// it cleared after a restart. Two findings drive this commit:
//   1. AddCategorySheet showed the TRANSACTION error string for a CATEGORY save
//      failure → now uses category.error.save_failed.
//   2. The shared mainContext could be poisoned by a swallowed save error in
//      MerchantLearningService.record (no rollback), making the NEXT unrelated
//      save() throw — a restart clears it. record() now rolls back on failure.
//
// This test pins the realistic sequence: a run of Quick Add saves (each of which
// calls record()) followed by inline category creates, all of which must succeed
// — no spurious "save failed".

@Suite("Inline category create at scale (Bug 34.5 / Round 9)")
@MainActor
struct InlineCategoryCreateScaleTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Mirrors AddCategorySheet.persist(): build via the shared validated path,
    /// insert, save. Returns the created category. Throws on a real save failure.
    @discardableResult
    private func createCategoryInline(_ name: String, in ctx: ModelContext) throws -> FinanceTracker.Category {
        let existing = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        let order = (existing.filter { $0.kindRaw == "expense" }.map(\.order).max() ?? 0) + 1
        guard case .success(let cat) = NewCategoryViewModel.makeCategory(
            name: name, kindRaw: "expense", icon: nil, order: order, existing: existing
        ) else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "makeCategory failed for \(name)"])
        }
        ctx.insert(cat)
        try ctx.save()   // would throw if the shared context were poisoned
        return cat
    }

    @Test func testInlineCategoryCreate_afterManyQuickAddSaves_succeeds() throws {
        let ctx = try makeContext()
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        try ctx.save()

        // 60 Quick Add saves — each persists a transaction AND calls
        // MerchantLearningService.record() on the same shared context.
        for i in 0..<60 {
            let parsed = QuickAddParsedInput(
                amountCents: (i + 1) * 7, typeRaw: "expense",
                merchant: "Merchant\(i)", suggestedCategoryName: nil
            )
            _ = try QuickAddSaveService.save(parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD")
        }
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 60)

        // Now create three categories inline — the device-reported failure point.
        for name in ["Test1", "Test2", "Test3"] {
            let cat = try createCategoryInline(name, in: ctx)
            // File a transaction against the freshly created category and save again.
            ctx.insert(Transaction(
                typeRaw: "expense", amountCents: 999, currency: "USD",
                date: Date(), category: cat, merchant: "after-\(name)"
            ))
            try ctx.save()
        }

        let cats = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        #expect(cats.contains { $0.nameCustom == "Test1" })
        #expect(cats.contains { $0.nameCustom == "Test3" })
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 63,
                "60 quick-adds + 3 inline-category transactions all persist — no spurious save failure")
    }

    @Test func testInlineCategoryCreate_repeated_doesNotFail() throws {
        let ctx = try makeContext()
        // Rapidly create 25 distinct categories interleaved with transactions.
        for i in 0..<25 {
            let cat = try createCategoryInline("Cat\(i)", in: ctx)
            ctx.insert(Transaction(
                typeRaw: "expense", amountCents: 100 + i, currency: "USD",
                date: Date(), category: cat, merchant: "m\(i)"
            ))
            try ctx.save()
        }
        #expect(try ctx.fetchCount(FetchDescriptor<FinanceTracker.Category>()) == 25)
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 25)
    }
}
