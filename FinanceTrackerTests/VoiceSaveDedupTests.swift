import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Voice repeat-fire protection (Bug 21, reworked)
//
// HISTORY — read before re-adding dedup to the save path.
//
// Bug 4 reported a voiced "Бензин 500" creating three identical transactions, and the
// fix was a 30-second content-identity window (amount + type + merchant) inside
// QuickAddSaveService. Two things later proved that fix wrong:
//
//  1. It was aimed at a bug that largely wasn't there. This suite's own investigation
//     found the apparent ×6 was Bug 22's position-keyed ForEach (id: \.offset)
//     rendering ONE row several times — a view bug, not duplicate writes.
//
//  2. It caused a worse bug than it prevented. The window sat on the SHARED save path,
//     so it also ate typed entries: two coffees at the same price on the same day
//     collapsed into one row while the UI reported "saved" (device log:
//     `dedup-hit (returned existing)`). Silent data loss.
//
// Content identity cannot distinguish "the recognizer redelivered a final" from "the
// user bought the same thing twice", so the save path must not try: it always inserts.
// Repeat-fire is caught at the ACTION, where it is content-blind and cannot swallow a
// distinct entry:
//
//   * QuickEntryView.isSaving — in-flight re-entrancy guard (voice only live-binds the
//     transcript into the input; a human still taps Save, so a redelivered final
//     cannot itself commit).
//   * SaveActionGate — a 500ms debounce on the Save action.
//
// Import dedup is a different problem with a different answer and stays in
// CSVImportService: a file may restate rows the user already has, with no human in the
// loop to ask.

@Suite("Voice save: repeat-fire is gated, never content-deduped")
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

    private func seeded() throws -> ModelContext {
        let ctx = try makeContext()
        ctx.insert(FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0))
        try ctx.save()
        return ctx
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

    /// REVERSED from `testVoiceSave_calledTwiceInSameTick_creates1Entry`, which
    /// asserted the collapse that was losing user data.
    @Test func testVoiceSave_calledTwice_persistsTwoRows() throws {
        let ctx = try seeded()
        let now = Date()

        let first = try voiceSave(ctx, now: now)
        let second = try voiceSave(ctx, now: now)

        #expect(first.uuid != second.uuid, "the save path never returns an existing row")
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "filling up twice is two transactions — the write layer does not second-guess the user")
    }

    /// The genuine voice hazard — one action firing twice in a tick — collapsed at the
    /// gate, which never inspects what is being saved.
    @Test func testRepeatedFinalInSameTick_isCollapsedByTheGate() throws {
        let ctx = try seeded()
        let gate = SaveActionGate()
        let now = Date()

        try gate.submit(now: now) { try voiceSave(ctx, now: now) }
        try gate.submit(now: now) { try voiceSave(ctx, now: now) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 1,
                "one utterance, redelivered, is one save")
    }

    /// And the gate must still let a real second entry through moments later.
    @Test func testDeliberateSecondVoiceEntry_isNotSwallowed() throws {
        let ctx = try seeded()
        let gate = SaveActionGate()
        let now = Date()
        let later = now.addingTimeInterval(SaveActionGate.debounceWindow + 0.01)

        try gate.submit(now: now) { try voiceSave(ctx, now: now) }
        try gate.submit(now: later) { try voiceSave(ctx, now: later) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "saying the same thing again is a new entry, not a duplicate")
    }
}
