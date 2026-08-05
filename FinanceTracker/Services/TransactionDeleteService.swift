//
//  TransactionDeleteService.swift
//  FinanceTracker
//
//  The guarded delete, and the delete analogue of TransactionEditService /
//  QuickAddSaveService. Both user-facing single-row delete paths route through
//  here — swipe-to-delete on Transactions, and shake-to-undo on the Dashboard.
//
//  WHY a service rather than two `try? modelContext.save()` calls: a thrown save
//  after `context.delete(_:)` leaves the delete PENDING in the long-lived
//  mainContext, and a pending delete is not inert. The next ordinary save the
//  user causes — entering a transaction, minutes or days later — commits it for
//  real, at a moment they never asked for and cannot connect to anything they
//  did. That is not an argument; it is demonstrated against a real store in
//  `SaveFailureReachabilityProbe.pendingDeletesRideAlongOnTheNextSave` (50 rows
//  on disk before an unrelated save, 0 after).
//
//  `rollback()` is what makes a failed delete stay failed. The error is still
//  rethrown, because a silent no-op on a destructive action is indistinguishable
//  from success — the same discipline as `DuplicateReviewService`.
//

import Foundation
import SwiftData

@MainActor
enum TransactionDeleteService {

    /// Deletes one transaction and commits it, or leaves the store exactly as it
    /// was and throws. There is no third outcome — in particular there is no
    /// "deleted in memory, not on disk" state for a later save to discover.
    ///
    /// Child splits ride the `.cascade` rule on `Transaction.splits`, so they are
    /// part of the same save and the same rollback.
    static func delete(_ tx: Transaction, in context: ModelContext) throws {
        context.delete(tx)
        do {
            try context.save()
        } catch {
            context.rollback()
            logSaveFailure("TransactionDeleteService.delete", error)
            throw error
        }
    }
}
