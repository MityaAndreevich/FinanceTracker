//
//  AddTransactionSaveService.swift
//  FinanceTracker
//
//  Single guarded write for the detailed Add Transaction form — the third entry
//  surface, and the insert analogue of TransactionEditService (which guards the
//  edit path) and QuickAddSaveService (which guards the Quick Add path).
//
//  Why this exists (v1.0.2 release review, item 1): AddTransactionView used to
//  insert + save inline. A thrown save() left the freshly-inserted Transaction
//  as an UNCOMMITTED pending insert in the long-lived autosaving mainContext —
//  @Query rendered it as a ghost row, every later save re-threw trying to flush
//  it, and the "save failed" alert invited the retry that stacked the next
//  orphan. That is the exact device duplication cascade documented in
//  QuickAddSaveService.save; this file closes the same hole on this surface.
//
//  Like the other two: no dedup, no content inspection. A save is an explicit
//  instruction — it always inserts. Double-submit is gated at the ACTION in the
//  view (SaveActionGate + isSaving), which is content-blind.
//

import Foundation
import SwiftData

@MainActor
enum AddTransactionSaveService {

    /// Test seam: forces the next `save()` to throw AFTER the insert, so the
    /// anti-poison guard (delete-the-failed-insert) can be exercised
    /// deterministically — the in-memory store used in tests never throws on its
    /// own. Mirrors `QuickAddSaveService._forceSaveFailureForTesting`.
    static var _forceSaveFailureForTesting = false
    private struct _SimulatedSaveError: Error {}

    /// Inserts `tx` and persists it through the guarded save path.
    ///
    /// On a thrown save the insert is removed again, returning the context to a
    /// clean, saveable state — no ghost row leaks and the user's deliberate
    /// retry can succeed. The error is rethrown for the caller to surface
    /// (never fail silently).
    @discardableResult
    static func save(_ tx: Transaction, in context: ModelContext) throws -> Transaction {
        context.insert(tx)
        do {
            if _forceSaveFailureForTesting { throw _SimulatedSaveError() }
            try context.save()
        } catch {
            persistenceLog.error("AddTransactionSave: save() threw — discarding failed insert to keep context clean")
            context.delete(tx)
            throw error
        }
        return tx
    }
}
