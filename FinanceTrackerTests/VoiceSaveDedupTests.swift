import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Bug 21: voice "Бензин 500" duplicated ×6 on the Dashboard
//
// Sprint A (9d4c316) added the idempotency key in QuickAddSaveService. Device
// test #7 still reported ×6 voice duplicates. Investigation: the voice path
// (QuickEntryView → handleSave → QuickAddSaveService.save, and Dashboard quick
// add → the same service) is the ONLY voice write path — there is no bypass
// that inserts a Transaction directly. The apparent ×6 was Bug 22's
// position-keyed ForEach (id: \.offset) rendering one real row as several
// stale/duplicated rows; fixed in the Bug 22 commit.
//
// These tests lock in the two halves of the contract that must hold for voice:
//  1. repeated final-transcript saves in the same instant collapse to one row;
//  2. the dedup gate is an in-memory, time-boxed window — after a restart (which
//     wipes the cache) the same input is a legitimate new entry, not swallowed.

@Suite("Voice save dedup (Bug 21)")
@MainActor
struct VoiceSaveDedupTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Mirrors the QuickEntryView voice save: a parsed input committed through the
    /// shared service with the preview category passed as an override.
    @discardableResult
    private func voiceSave(_ ctx: ModelContext, now: Date) throws -> Transaction {
        let parsed = QuickAddParsedInput(
            amountCents: 50_000, typeRaw: "expense", merchant: "Бензин", suggestedCategoryName: nil
        )
        let override = QuickAddSaveService.previewCategory(for: parsed, in: ctx)
        return try QuickAddSaveService.save(
            parsed: parsed,
            modelContext: ctx,
            defaultCurrencyCode: "USD",
            overrideCategory: override,
            now: now
        )
    }

    @Test func testVoiceSave_calledTwiceInSameTick_creates1Entry() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        try ctx.save()

        // The recognizer can deliver the same final result repeatedly; both races
        // hit the shared gate in the same instant.
        let now = Date()
        let first = try voiceSave(ctx, now: now)
        let second = try voiceSave(ctx, now: now)

        #expect(first.uuid == second.uuid, "a repeated voice final in the same tick must return the existing row")
        let count = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(count == 1, "voice ×N in the dedup window persists exactly one transaction")
    }

    @Test func testVoiceSave_calledTwiceAcrossRestart_creates2Entries() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let ctx = try makeContext()
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        try ctx.save()

        let now = Date()
        let first = try voiceSave(ctx, now: now)

        // Simulate an app restart: the dedup window lives in process memory only, so
        // a relaunch clears it. The same input is then a legitimate new entry.
        QuickAddSaveService._resetDedupCacheForTesting()
        let second = try voiceSave(ctx, now: now)

        #expect(first.uuid != second.uuid, "after a restart the gate is empty — the same voice input is a new row")
        let count = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(count == 2, "voicing the same thing again after a restart is intentional, not a duplicate")
    }
}
