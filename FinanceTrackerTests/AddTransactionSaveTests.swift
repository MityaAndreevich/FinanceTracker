import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Detailed Add form: guarded insert + double-submit gate (v1.0.2 review, item 1)
//
// AddTransactionView was the last entry surface without the two protections the
// rest of the app standardized:
//
//   * SaveActionGate + isSaving at the ACTION — a fast double-tap on "Add" must
//     collapse to one row, without any content inspection (see VoiceSaveDedupTests
//     for why content dedup on a save path is data loss).
//   * The anti-poison guard at the WRITE — a thrown save() must remove the failed
//     insert so the autosaving mainContext stays clean and the retry the error
//     alert invites can actually succeed (see QuickAddSaveService.save's catch).
//
// The regression that matters most here is the RECOVERY: after a failed save the
// context holds zero ghost rows and the next save persists exactly one.

@Suite("Detailed Add: gated at the action, poison-proof at the write")
@MainActor
struct AddTransactionSaveTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func seeded() throws -> (ModelContext, FinanceTracker.Category) {
        let ctx = try makeContext()
        let category = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(category)
        try ctx.save()
        return (ctx, category)
    }

    /// Mirrors what AddTransactionView.add() builds and commits.
    private func formSave(_ ctx: ModelContext, category: FinanceTracker.Category) throws -> Transaction {
        let tx = Transaction(
            typeRaw: "expense",
            amountCents: 12_50,
            currency: "USD",
            date: .now,
            category: category,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: "Coffee",
            recurrenceRaw: nil
        )
        return try AddTransactionSaveService.save(tx, in: ctx)
    }

    // MARK: - The write layer never second-guesses the user

    @Test func testTwoDeliberateSaves_persistTwoRows() throws {
        let (ctx, category) = try seeded()

        let first = try formSave(ctx, category: category)
        let second = try formSave(ctx, category: category)

        #expect(first.uuid != second.uuid, "the save path never returns an existing row")
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "two identical coffees are two transactions — no content dedup on a save path")
    }

    // MARK: - The action layer collapses a double-fire

    @Test func testSameTickDoubleTap_isCollapsedByTheGate() throws {
        let (ctx, category) = try seeded()
        let gate = SaveActionGate()
        let now = Date()

        try gate.submit(now: now) { _ = try formSave(ctx, category: category) }
        try gate.submit(now: now) { _ = try formSave(ctx, category: category) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 1,
                "one tap, double-fired, is one save")
    }

    @Test func testDeliberateSecondEntry_isNotSwallowed() throws {
        let (ctx, category) = try seeded()
        let gate = SaveActionGate()
        let now = Date()
        let later = now.addingTimeInterval(SaveActionGate.debounceWindow + 0.01)

        try gate.submit(now: now) { _ = try formSave(ctx, category: category) }
        try gate.submit(now: later) { _ = try formSave(ctx, category: category) }

        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 2,
                "a second deliberate entry moments later must land")
    }

    // MARK: - The write layer stays clean after a failure

    /// The regression that matters: a thrown save leaves ZERO rows behind — no
    /// pending ghost insert for @Query to render — and the context is clean
    /// enough that the user's retry succeeds. Without the delete-on-throw, the
    /// poisoned pending insert makes every later save re-throw (the device
    /// duplication cascade documented in QuickAddSaveService).
    @Test func testThrownSave_leavesZeroRows_andTheRetrySucceeds() throws {
        let (ctx, category) = try seeded()

        AddTransactionSaveService._forceSaveFailureForTesting = true
        defer { AddTransactionSaveService._forceSaveFailureForTesting = false }

        #expect(throws: (any Error).self) {
            _ = try formSave(ctx, category: category)
        }
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 0,
                "a failed save must not leave a ghost row")

        // The retry the error alert invites — it must land.
        AddTransactionSaveService._forceSaveFailureForTesting = false
        _ = try formSave(ctx, category: category)
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 1,
                "the context stays saveable after a failure — recovery is the contract")
    }
}
