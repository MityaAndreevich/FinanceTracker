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
        var category: Category
        var source: Source?
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
        let prior = snapshot(of: tx)
        apply(fields, to: tx)

        do {
            if _forceSaveFailureForTesting { throw _SimulatedSaveError() }
            try context.save()
        } catch {
            apply(prior, to: tx)   // revert the object's fields
            context.rollback()     // drop any pending context state → stays saveable
            throw error
        }
    }

    private static func snapshot(of tx: Transaction) -> Fields {
        Fields(
            typeRaw: tx.typeRaw, amountCents: tx.amountCents, taxCents: tx.taxCents,
            currency: tx.currency, merchant: tx.merchant, note: tx.note,
            date: tx.date, category: tx.category, source: tx.source
        )
    }

    private static func apply(_ f: Fields, to tx: Transaction) {
        tx.typeRaw = f.typeRaw
        tx.amountCents = f.amountCents
        tx.taxCents = f.taxCents
        tx.currency = f.currency
        tx.merchant = f.merchant
        tx.note = f.note
        tx.date = f.date
        tx.category = f.category
        tx.source = f.source
        tx.updatedAt = Date()
    }
}
