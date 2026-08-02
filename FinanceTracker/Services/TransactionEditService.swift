//
//  TransactionEditService.swift
//  FinanceTracker
//
//  Single guarded write for editing an EXISTING transaction — the edit analogue
//  of QuickAddSaveService (which guards the insert path). Device QA round 2 #4.
//
//  A raw `modelContext.save()` after mutating a @Model leaves the long-lived
//  mainContext holding the dirty edit if it throws. That poisons the context:
//  every later save() re-throws trying to flush the pending mutation, so to the
//  user "editing does nothing / Save is broken" and unrelated saves start
//  failing too. On failure we roll the edit back to the last clean saved state
//  and rethrow — never poison, never fail silently.
//

import Foundation
import SwiftData

@MainActor
enum TransactionEditService {

    /// Validated field set to apply to an existing transaction.
    struct Fields {
        var typeRaw: String
        var amountCents: Int
        var taxCents: Int?
        var currency: String
        var merchant: String?
        var note: String?
        var date: Date
        var category: Category?   // optional as of V2; the editor always passes one
        var source: Source?
        /// The series cadence, or nil for a one-time transaction. A FULL
        /// replacement like every other field — pass the transaction's current
        /// raw to keep an existing series, nil to end it. It rides through the
        /// guarded save so a failed edit can't leave a half-removed series
        /// (recurrence lives on the row; the notification and period boundary
        /// are reconciled afterwards by `RecurrenceService`).
        var recurrenceRaw: String?
        /// The purchase's split decomposition, in display order. Empty = not
        /// split (today's behavior). The EDITOR is responsible for the
        /// Σ splits ≤ amountCents invariant — over-sum must be impossible to
        /// even reach this service (design §2.2; read-side truncation is the
        /// safety net, never the mechanism).
        var splits: [SplitInput] = []

        struct SplitInput {
            var amountCents: Int
            var category: Category?
            var note: String?
        }
    }

    /// Test seam: force `save()` to throw AFTER the mutation so the rollback
    /// guard can be exercised deterministically (the in-memory store never
    /// throws on its own). Mirrors `QuickAddSaveService._forceSaveFailureForTesting`.
    static var _forceSaveFailureForTesting = false
    private struct _SimulatedSaveError: Error {}

    /// Applies `fields` to `tx` and persists through the guarded save path.
    /// On a thrown save the edit is fully reverted — the object's fields are
    /// restored to their pre-edit values AND the context is rolled back — then
    /// the error is rethrown for the caller to show.
    static func update(_ tx: Transaction, with fields: Fields, in context: ModelContext) throws {
        // Snapshot the persisted values first. ModelContext.rollback() alone does
        // NOT reliably restore mutated attribute values on a live SwiftData object
        // (verified in TransactionEditServiceTests), so a bare rollback could leave
        // the bad edit sitting in memory to be flushed by the next save. Restoring
        // the snapshot guarantees the object returns to its clean pre-edit state.
        // (Split objects need no snapshot: they are reconciled by delete+insert,
        // both PENDING operations that rollback() genuinely reverses.)
        let prior = snapshot(of: tx)
        apply(fields, to: tx, in: context)

        do {
            if _forceSaveFailureForTesting { throw _SimulatedSaveError() }
            try context.save()
        } catch {
            apply(prior, to: tx, in: context)  // revert the object's fields
            context.rollback()                 // drop any pending context state
                                               // (incl. the split delete+insert
                                               // churn) → stays saveable
            throw error
        }
    }

    private static func snapshot(of tx: Transaction) -> Fields {
        Fields(
            typeRaw: tx.typeRaw, amountCents: tx.amountCents, taxCents: tx.taxCents,
            currency: tx.currency, merchant: tx.merchant, note: tx.note,
            date: tx.date, category: tx.category, source: tx.source,
            recurrenceRaw: tx.recurrenceRaw,
            splits: CategoryAttribution.orderedSplits(of: tx).map {
                Fields.SplitInput(amountCents: $0.amountCents, category: $0.category, note: $0.note)
            }
        )
    }

    private static func apply(_ f: Fields, to tx: Transaction, in context: ModelContext) {
        tx.typeRaw = f.typeRaw
        tx.amountCents = f.amountCents
        tx.taxCents = f.taxCents
        tx.currency = f.currency
        tx.merchant = f.merchant
        tx.note = f.note
        tx.date = f.date
        tx.category = f.category
        tx.source = f.source
        tx.recurrenceRaw = f.recurrenceRaw
        tx.updatedAt = Date()

        // Reconcile splits by replacement (delete old, insert new) — simpler
        // to reason about under rollback than in-place mutation, and split
        // rows are tiny.
        for stale in tx.splits ?? [] {
            context.delete(stale)
        }
        for (index, input) in f.splits.enumerated() {
            let split = TransactionSplit(
                amountCents: input.amountCents,
                category: input.category,
                note: input.note,
                order: index
            )
            context.insert(split)
            split.parent = tx
        }

        // The editor is the only user-facing path that creates a split (import
        // and recurrence copies are derivative), so this is where "ever split
        // a purchase" gets recorded for the 1.0.3 pre-test. Local only — see
        // FeatureUsageSignals.
        if !f.splits.isEmpty {
            FeatureUsageSignals.markUsed(.splits)
        }
        if f.recurrenceRaw != nil {
            FeatureUsageSignals.markUsed(.recurring)
        }
    }
}
