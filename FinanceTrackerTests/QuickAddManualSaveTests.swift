import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Manual QuickAdd must never be content-deduped (data loss)
//
// Device log: repeated `QuickAddSave #N: dedup-hit (returned existing)` while the
// UI reported "saved". QuickAddSaveService held a 30-SECOND content-identity window
// keyed on amount|type|merchant, so two legitimately identical entries (two coffees,
// same price, same day) collapsed into one row — silently, because every caller
// treats a returned Transaction as success.
//
// The contract these tests lock in:
//
//  1. The SAVE PATH always inserts. It is content-blind. Two identical manual saves
//     are two transactions, because only the user knows whether they bought one
//     coffee or two — the persistence layer cannot infer it and must not guess.
//
//  2. Accidental double-submit is a UI concern, handled by SaveActionGate: a short,
//     content-INDEPENDENT debounce on a single Save action. Content-independence is
//     the whole point — a gate that never inspects the payload structurally cannot
//     drop a legitimately distinct entry, which is exactly how the old dedup failed.
//
// Import dedup is unaffected and stays where it belongs: CSVImportService.

@Suite("Manual QuickAdd save (no content dedup)")
@MainActor
struct QuickAddManualSaveTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        let ctx = ModelContext(container)
        ctx.insert(FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0))
        try ctx.save()
        return ctx
    }

    private func coffee() -> QuickAddParsedInput {
        QuickAddParsedInput(
            amountCents: 550, typeRaw: "expense", merchant: "Coffee", suggestedCategoryName: nil
        )
    }

    @discardableResult
    private func save(_ ctx: ModelContext, at now: Date = .now) throws -> Transaction {
        try QuickAddSaveService.save(
            parsed: coffee(), modelContext: ctx, defaultCurrencyCode: "USD", now: now
        )
    }

    // MARK: - 1. The save path always inserts

    /// The reported data loss: two coffees at the same price on the same day.
    @Test func test_twoIdenticalManualSaves_persistTwoRows() throws {
        let ctx = try makeContext()

        let first = try save(ctx)
        let second = try save(ctx)

        #expect(first.uuid != second.uuid, "a manual save must never return a previously-saved row")
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "two identical manual QuickAdd saves are two transactions, not one")
    }

    /// The old window was 30s, so this is the exact case that was being swallowed.
    @Test func test_identicalManualSavesSecondsApart_persistTwoRows() throws {
        let ctx = try makeContext()
        let t0 = Date()

        try save(ctx, at: t0)
        try save(ctx, at: t0.addingTimeInterval(5))

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "identical entries 5s apart are two real purchases, not a duplicate")
    }

    /// Hammering the save path is the stress case from the device log (many saves,
    /// many dedup-hits). Every one must land.
    @Test func test_manyIdenticalManualSaves_persistEveryRow() throws {
        let ctx = try makeContext()
        let t0 = Date()

        for i in 0..<20 {
            try save(ctx, at: t0.addingTimeInterval(Double(i) * 0.1))
        }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 20,
                "no manual save may be dropped, however rapid or however identical")
    }

    // Double-submit protection is the UI gate's job — see SaveActionGateTests.
}
