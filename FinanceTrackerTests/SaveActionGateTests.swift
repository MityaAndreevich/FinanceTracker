import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Double-submit protection (the safe replacement for content dedup)
//
// The save path always inserts (QuickAddManualSaveTests). Accidental double-submits
// are therefore caught at the ACTION, by SaveActionGate — a short, content-BLIND
// debounce. These tests pin both halves of the bargain:
//
//   * it collapses a double-tap,
//   * and it never becomes a new source of data loss (a deliberate re-save, or a
//     retry after a failure, must always land).

@Suite("SaveActionGate")
@MainActor
struct SaveActionGateTests {

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

    @discardableResult
    private func saveCoffee(_ ctx: ModelContext, at now: Date) throws -> Transaction {
        try QuickAddSaveService.save(
            parsed: QuickAddParsedInput(
                amountCents: 550, typeRaw: "expense", merchant: "Coffee", suggestedCategoryName: nil
            ),
            modelContext: ctx,
            defaultCurrencyCode: "USD",
            now: now
        )
    }

    // MARK: - It collapses an accidental double-tap

    /// The requested case: a rapid double-tap on Save persists ONE row. Drives the
    /// exact construct the views call — gate wrapping the real save.
    @Test func test_doubleTapWithinWindow_persistsOneRow() throws {
        let ctx = try makeContext()
        let gate = SaveActionGate()
        let tap = Date()

        let first = try gate.submit(now: tap) { try saveCoffee(ctx, at: tap) }
        let second = try gate.submit(now: tap.addingTimeInterval(0.05)) { try saveCoffee(ctx, at: tap) }

        #expect(first == true, "the first tap saves")
        #expect(second == false, "the second tap inside the window is debounced away")
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 1,
                "a double-tap is one intent and must persist exactly one transaction")
    }

    // MARK: - It never eats a real save

    /// Past the window the SAME entry is a legitimate second purchase. This is the
    /// case the old 30s content dedup destroyed.
    @Test func test_sameEntryAfterWindow_persistsTwoRows() throws {
        let ctx = try makeContext()
        let gate = SaveActionGate()
        let tap = Date()
        let later = tap.addingTimeInterval(SaveActionGate.debounceWindow + 0.01)

        try gate.submit(now: tap) { try saveCoffee(ctx, at: tap) }
        try gate.submit(now: later) { try saveCoffee(ctx, at: later) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "two identical coffees past the debounce window are two transactions")
    }

    /// A failed save must reopen the gate: the user is staring at an error and may
    /// retry immediately, and that retry has to land.
    @Test func test_retryImmediatelyAfterFailedSave_isNotDebounced() throws {
        let gate = SaveActionGate()
        let tap = Date()
        var runs = 0

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try gate.submit(now: tap) { runs += 1; throw Boom() }
        }
        gate.reset()   // what a caller does in its catch block

        let retry = try gate.submit(now: tap.addingTimeInterval(0.05)) { runs += 1 }

        #expect(retry == true, "a retry after a failure must never be debounced away")
        #expect(runs == 2)
    }

    /// Sanity: the gate is per-action, not global. Two different Save surfaces do not
    /// starve each other.
    @Test func test_separateGates_doNotBlockEachOther() throws {
        let ctx = try makeContext()
        let dashboardGate = SaveActionGate()
        let quickEntryGate = SaveActionGate()
        let t = Date()

        try dashboardGate.submit(now: t) { try saveCoffee(ctx, at: t) }
        try quickEntryGate.submit(now: t) { try saveCoffee(ctx, at: t) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "one surface's debounce must not swallow another surface's save")
    }
}
