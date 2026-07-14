import XCTest
import SwiftData
@testable import FinanceTracker

// MARK: - Root-cause guard for the on-device save/duplication cascade
//
// The device repro (2026-07-02): Reset Transactions → set a monthly budget →
// Dashboard quick-add "50 coffe" → Save produced ~10 duplicate rows, totals
// disagreed across screens, and afterwards every save failed. Crucially the dupes
// VANISHED on force-quit + relaunch — proving they were never written to disk, i.e.
// UNCOMMITTED pending inserts left in the long-lived mainContext after a thrown
// save(), rendered by @Query. The in-memory test store never throws, which is why
// the suite stayed green while the device failed (the loop the brief describes).
//
// These tests (a) mirror the real flow end-to-end at the store layer, and (b) use a
// deterministic save-failure seam to prove the anti-poison guard: a failed save must
// leave ZERO ghost rows and must NOT poison later saves. Test (b) FAILS without the
// `modelContext.delete(tx)` guard in QuickAddSaveService and PASSES with it.
@MainActor
final class QuickAddPoisonGuardFlowTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func seedOther(_ ctx: ModelContext) throws -> FinanceTracker.Category {
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        try ctx.save()
        return other
    }

    private func coffeeParse() -> QuickAddParsedInput {
        // Mirrors "50 coffe" (typo → no keyword category, resolves to Other).
        QuickAddParsedInput(amountCents: 5000, typeRaw: "expense",
                            merchant: "Coffe", suggestedCategoryName: nil)
    }

    override func setUp() {
        super.setUp()
        QuickAddSaveService._forceSaveFailureForTesting = false
    }

    override func tearDown() {
        QuickAddSaveService._forceSaveFailureForTesting = false
        super.tearDown()
    }

    // (a) THE REAL FLOW: reset → set budget → quick-add save → each save adds EXACTLY
    // ONE row. The bug this pins is fan-out (one Save producing ~10 pending ghosts),
    // so the invariant is "one save, one row" — not "identical saves collapse". The
    // trailing assertion used to claim the latter, which was the content-dedup that
    // silently ate real entries; the save path now always inserts, and accidental
    // double-taps are debounced at the action (SaveActionGate).
    func testResetThenBudgetThenEachSave_addsExactlyOneRow() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seedOther(ctx)

        // Reset (empty store is the repro's starting point).
        XCTAssertEqual(TransactionResetService.reset(in: ctx), .success)

        // "Set a monthly budget" — @AppStorage-backed, does not touch the store, but
        // is part of the repro sequence so we replicate it.
        UserDefaults.standard.set(50_000, forKey: "monthlyBudgetCents")
        defer { UserDefaults.standard.removeObject(forKey: "monthlyBudgetCents") }

        _ = try QuickAddSaveService.save(parsed: coffeeParse(), modelContext: ctx,
                                         defaultCurrencyCode: "USD")

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 1,
            "One quick-add Save must persist exactly one transaction.")

        // A second Save of the same entry is a second coffee: it adds one row, and
        // exactly one — no fan-out, no ghosts.
        _ = try QuickAddSaveService.save(parsed: coffeeParse(), modelContext: ctx,
                                         defaultCurrencyCode: "USD")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 2,
            "Each Save must persist exactly one more transaction — never zero, never ten.")
    }

    // (b) ANTI-POISON GUARD: a thrown save() must leave NO uncommitted ghost row.
    // Before the guard, the failed insert lingers as a pending row (@Query would
    // render it) → this assertion fails. With the guard it is discarded → passes.
    func testFailedSaveLeavesNoGhostRow() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seedOther(ctx)

        QuickAddSaveService._forceSaveFailureForTesting = true
        XCTAssertThrowsError(
            try QuickAddSaveService.save(parsed: coffeeParse(), modelContext: ctx,
                                         defaultCurrencyCode: "USD"),
            "A simulated save failure must propagate to the caller."
        )

        // The real guarantee: NO ghost row is visible to a fetch / @Query. Without
        // the `modelContext.delete(tx)` guard the failed insert stays pending and a
        // fetch returns 1 (the rendered duplicate) — this assertion is red before the
        // fix, green after. We deliberately do NOT assert `!hasChanges`: SwiftData
        // still flags the delete-of-an-unsaved-insert as a pending (no-op) change,
        // and a full rollback() would wrongly discard unrelated pending SwiftUI edits
        // on the autosave-enabled mainContext. Context recovery is covered by
        // testContextRecoversAfterFailedSave.
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 0,
            "A failed save must not leave an uncommitted ghost transaction visible to @Query.")
    }

    // (c) NO CONTEXT POISONING: after a failed save, the very next valid save must
    // still succeed (the device symptom was 'afterwards every save fails').
    func testContextRecoversAfterFailedSave() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seedOther(ctx)

        QuickAddSaveService._forceSaveFailureForTesting = true
        XCTAssertThrowsError(try QuickAddSaveService.save(
            parsed: coffeeParse(), modelContext: ctx, defaultCurrencyCode: "USD"))

        // Recovery: next save works and produces exactly one row.
        QuickAddSaveService._forceSaveFailureForTesting = false
        _ = try QuickAddSaveService.save(parsed: coffeeParse(), modelContext: ctx,
                                         defaultCurrencyCode: "USD")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 1,
            "A save after a failed save must succeed — the context must not be poisoned.")
    }
}
