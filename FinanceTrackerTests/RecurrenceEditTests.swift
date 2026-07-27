//
//  RecurrenceEditTests.swift
//  FinanceTrackerTests
//
//  1.0.3 — recurrence is settable when EDITING a transaction, not just when
//  creating one. Add only ever had to handle "was nothing → now recurring";
//  Edit has three transitions (set / change / remove), and the removal one has
//  side effects Add never needed: the handled boundary and the pending
//  notification both have to go with it.
//
//  These pin the two seams the edit surface leans on: the prefill derivation
//  (so the toggle round-trips) and the post-save side-effect decision (so a
//  frequency change reschedules, a removal cancels, and an untouched
//  recurrence does neither).
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Recurrence editing (1.0.3)")
@MainActor
struct RecurrenceEditTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
            TransactionSplit.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func seedOne(recurrenceRaw: String?, in ctx: ModelContext) -> (Transaction, FinanceTracker.Category) {
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        let tx = Transaction(
            typeRaw: "expense", amountCents: 5200, currency: "USD",
            date: Date(), category: cat, recurrenceRaw: recurrenceRaw
        )
        ctx.insert(tx)
        try? ctx.save()
        return (tx, cat)
    }

    /// Exactly what EditTransactionView.save() builds — the recurrence value is
    /// a full-replacement field like every other one.
    private func fields(
        from tx: Transaction,
        cat: FinanceTracker.Category,
        recurrenceRaw: String?
    ) -> TransactionEditService.Fields {
        TransactionEditService.Fields(
            typeRaw: tx.typeRaw, amountCents: tx.amountCents, taxCents: tx.taxCents,
            currency: tx.currency, merchant: tx.merchant, note: tx.note,
            date: tx.date, category: cat, source: tx.source,
            recurrenceRaw: recurrenceRaw
        )
    }

    // MARK: - Prefill (the toggle must round-trip)

    @Test func testEditState_nonRecurringTransaction_isOffAndDefaultsToMonthly() throws {
        let ctx = try makeContext()
        let (tx, _) = seedOne(recurrenceRaw: nil, in: ctx)

        let state = RecurrenceService.editState(for: tx)

        #expect(state.isRecurring == false)
        #expect(state.type == .monthly)   // the picker needs *some* selection
    }

    @Test func testEditState_recurringTransaction_reflectsItsFrequency() throws {
        let ctx = try makeContext()
        let (tx, _) = seedOne(recurrenceRaw: "yearly", in: ctx)

        let state = RecurrenceService.editState(for: tx)

        #expect(state.isRecurring == true)
        #expect(state.type == .yearly)
    }

    // MARK: - Transition: none → recurring

    @Test func testEnableRecurrence_persistsRawAndSchedules() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(recurrenceRaw: nil, in: ctx)
        defer { RecurrenceService.clearHandled(for: tx.uuid) }
        let previous = tx.recurrence

        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, recurrenceRaw: "weekly"), in: ctx)
        let outcome = RecurrenceService.applyRecurrenceSideEffects(for: tx, previous: previous)

        #expect(tx.recurrenceRaw == "weekly")
        #expect(outcome == .scheduled(.weekly))
        // No boundary yet, so the series keys off the transaction's own date —
        // the edited transaction becomes the first occurrence.
        #expect(RecurrenceService.handledDate(for: tx.uuid) == nil)
    }

    // MARK: - Transition: recurring → different frequency

    @Test func testChangeFrequency_reschedulesAndKeepsTheHandledBoundary() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(recurrenceRaw: "monthly", in: ctx)
        defer { RecurrenceService.clearHandled(for: tx.uuid) }
        let boundary = Date(timeIntervalSince1970: 1_700_000_000)
        RecurrenceService.setHandledDate(boundary, for: tx.uuid)
        let previous = tx.recurrence

        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, recurrenceRaw: "yearly"), in: ctx)
        let outcome = RecurrenceService.applyRecurrenceSideEffects(for: tx, previous: previous)

        #expect(tx.recurrenceRaw == "yearly")
        #expect(outcome == .scheduled(.yearly))
        // Changing the cadence does NOT restart the series (1.0.3 default).
        #expect(RecurrenceService.handledDate(for: tx.uuid) == boundary)
    }

    @Test func testUntouchedRecurrence_reschedulesNothing() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(recurrenceRaw: "monthly", in: ctx)
        defer { RecurrenceService.clearHandled(for: tx.uuid) }
        let boundary = Date(timeIntervalSince1970: 1_700_000_000)
        RecurrenceService.setHandledDate(boundary, for: tx.uuid)
        let previous = tx.recurrence

        // Editing the amount only — the toggle came back unchanged.
        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, recurrenceRaw: "monthly"), in: ctx)
        let outcome = RecurrenceService.applyRecurrenceSideEffects(for: tx, previous: previous)

        #expect(tx.recurrenceRaw == "monthly")
        #expect(outcome == .unchanged)
        #expect(RecurrenceService.handledDate(for: tx.uuid) == boundary)
    }

    // MARK: - Transition: recurring → off

    @Test func testDisableRecurrence_clearsRawAndTheHandledBoundary() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(recurrenceRaw: "monthly", in: ctx)
        defer { RecurrenceService.clearHandled(for: tx.uuid) }
        RecurrenceService.setHandledDate(Date(timeIntervalSince1970: 1_700_000_000), for: tx.uuid)
        let previous = tx.recurrence

        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, recurrenceRaw: nil), in: ctx)
        let outcome = RecurrenceService.applyRecurrenceSideEffects(for: tx, previous: previous)

        #expect(tx.recurrenceRaw == nil)
        #expect(outcome == .cleared)
        // Boundary must go too: a stale one would make a re-enabled series
        // start mid-period against a cadence the user no longer chose.
        #expect(RecurrenceService.handledDate(for: tx.uuid) == nil)
        // And it must drop out of the due-prompt sweep entirely.
        #expect(RecurrenceService.dueRecurring(modelContext: ctx).isEmpty)
    }

    // MARK: - The guarded write covers recurrence too

    @Test func testFailedSave_rollsBackTheRecurrenceChange() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(recurrenceRaw: "monthly", in: ctx)
        defer { RecurrenceService.clearHandled(for: tx.uuid) }

        TransactionEditService._forceSaveFailureForTesting = true
        defer { TransactionEditService._forceSaveFailureForTesting = false }

        #expect(throws: (any Error).self) {
            try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, recurrenceRaw: nil), in: ctx)
        }

        // Not persisted ⇒ not applied in memory either, or the next save flushes
        // a removal the user never got confirmation of.
        #expect(tx.recurrenceRaw == "monthly")
    }
}
