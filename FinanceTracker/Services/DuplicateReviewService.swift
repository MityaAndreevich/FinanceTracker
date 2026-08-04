//
//  DuplicateReviewService.swift
//  FinanceTracker
//
//  Resolve the possible-duplicate flag the importer persists on foreign rows.
//
//  The honest position, and the reason this is a review flow rather than an
//  auto-merge engine: a foreign CSV row carries no stable id, so a content match
//  is genuinely ambiguous — it is either a re-import of a row we already have, or
//  a second real spend of the same amount at the same merchant on the same day.
//  Both happen. We flag; the USER decides. Keep clears the flag, Delete removes
//  the row. No heuristic gets to silently destroy a real transaction.
//

import Foundation
import SwiftData

enum DuplicateReviewService {

    /// Every mutation here goes through this. A thrown `save()` that is merely
    /// propagated leaves the pending deletes/edits sitting in the long-lived
    /// mainContext, and that is not inert: `flaggedCount` sets
    /// `includePendingChanges = true`, so the app immediately reports zero rows
    /// left to review while the store still holds every one of them — and the
    /// next ordinary save the user causes (entering a transaction, minutes or
    /// days later) commits the abandoned deletes for real, at a moment they never
    /// asked for and cannot connect to anything they did. Both halves of that are
    /// demonstrated in SaveFailureReachabilityProbe.
    ///
    /// `rollback()` is what makes a failed operation stay failed. The error is
    /// still rethrown: the caller MUST tell the user, because a silent no-op on a
    /// destructive action is indistinguishable from success.
    ///
    /// Same discipline as `TransactionResetService.reset` and
    /// `MerchantLearningService.record`.
    private static func saveOrRollback(_ modelContext: ModelContext, _ label: String) throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            logSaveFailure(label, error)
            throw error
        }
    }

    /// Every transaction the importer flagged as a possible duplicate, newest
    /// first — the review queue.
    static func flagged(in modelContext: ModelContext) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isPossibleDuplicate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor)
    }

    /// Drives the review banner. 0 → no banner.
    static func flaggedCount(in modelContext: ModelContext) throws -> Int {
        try flagged(in: modelContext).count
    }

    /// "These really are two separate spends." Keeps the row, clears the flag so
    /// it leaves the review queue for good.
    static func keep(_ tx: Transaction, in modelContext: ModelContext) throws {
        tx.isPossibleDuplicate = false
        tx.updatedAt = Date()
        try saveOrRollback(modelContext, "DuplicateReviewService.keep")
    }

    /// "That was a re-import." An ordinary delete — same path as a swipe-delete,
    /// so no special delete-rule or permission surface.
    static func delete(_ tx: Transaction, in modelContext: ModelContext) throws {
        modelContext.delete(tx)
        try saveOrRollback(modelContext, "DuplicateReviewService.delete")
    }

    /// Dismiss the whole queue without deleting anything. The safe bulk action —
    /// offered first, because the destructive one is not reversible.
    static func keepAll(in modelContext: ModelContext) throws {
        let now = Date()
        for tx in try flagged(in: modelContext) {
            tx.isPossibleDuplicate = false
            tx.updatedAt = now
        }
        try saveOrRollback(modelContext, "DuplicateReviewService.keepAll")
    }

    /// Delete every flagged row. Only the flagged COPY is ever deleted — the
    /// original it matched was already in the store and was never flagged, so
    /// this can't empty out real data.
    static func deleteAll(in modelContext: ModelContext) throws {
        let rows = try flagged(in: modelContext)
        try hangProbe("DuplicateReview.deleteAll", rows: rows.count) {
            for tx in rows {
                modelContext.delete(tx)
            }
            try saveOrRollback(modelContext, "DuplicateReviewService.deleteAll")
        }
    }
}
