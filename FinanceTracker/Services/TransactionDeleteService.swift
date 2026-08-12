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

    // MARK: - Bulk delete

    /// Detach `rows` from every to-many collection that would otherwise be
    /// maintained ONE ROW AT A TIME during `save()`. Call this immediately before
    /// the delete loop. Callers keep their own save/rollback policy — this step
    /// only changes the COST of the save, never its outcome.
    ///
    /// ## Why this exists: bulk delete was quadratic, and this is the measured fix
    ///
    /// Saving a deletion has to maintain the inverse of every relationship the
    /// deleted row participates in — removing that row from its Category's to-many
    /// `transactions` array **by identity**. That is O(collection) per deleted row
    /// over a collection that stays large, which is the quadratic.
    ///
    /// Established by controlled experiment, not inference
    /// (`BulkDeleteQuadraticMechanismTests`): holding deletions, table size and
    /// survivor count all fixed and varying ONLY the size of the inverse collection,
    /// 44,664 ms → **720 ms** with `category == nil` (62×), and → ~1.2 s when merely
    /// spread across 400 categories (37×). The delete loop itself is 0.08% of the
    /// cost. So the fix is not "delete differently", it is "have nothing left to
    /// maintain" — which is exactly the state that 720 ms was measured in.
    ///
    /// Rebuilding each affected collection ONCE turns O(deleted × collection) into
    /// O(collections × collection) = O(table).
    ///
    /// ### Three collections, not one
    ///
    /// `Category.transactions` is the one that was measured. `Source.transactions`
    /// is an identical to-many with an explicit inverse, and **every row in that
    /// measurement had `source == nil`** — so the published 49.2 s at 8k is a LOWER
    /// BOUND for real user data, and detaching only the category would not reach the
    /// floor. `Category.splits` is the third: deleting a parent cascades to its
    /// splits (`Transaction.splits` is `.cascade`), and each cascaded child then has
    /// to be identity-removed from its own Category's `splits` array. No seeded row
    /// in the original measurement had splits either.
    ///
    /// ### What was rejected, and why — do not re-derive this
    ///
    /// **`context.delete(model:where:)` (batch delete) is NOT available here.** It
    /// throws on this container:
    ///
    ///     NSCocoaErrorDomain 134060 — "Entity named:TransactionSplit not found
    ///     for relationship named:category"
    ///
    /// The production container is MULTI-CONFIGURATION (`syncedConfig` +
    /// `localConfig`, `SharedModelContainer.openContainer`) and the bulk API takes
    /// no configuration, so it cannot resolve an entity that lives in one of two
    /// stores. See `LargeDatasetDebugSeed` and ARCHITECTURE.md — it already cost
    /// four days of silent failure. Separately, even if it worked: whether a
    /// store-level delete honours the `.cascade` on `Transaction.splits` is
    /// UNKNOWN, and getting it wrong leaves orphaned splits that are invisible to
    /// aggregation (`CategoryAttribution` derives from the parent) — a silently
    /// growing set of unreachable rows. And it would not update the in-memory graph
    /// that `DuplicateReviewView`'s `@Query` is holding.
    ///
    /// **Nil-ing `tx.category` per row was also rejected.** It performs the same
    /// identity-removal from the same large collection, just at assignment time.
    ///
    /// `nonisolated`, and it takes no `ModelContext`: this only rearranges object
    /// graphs, exactly like the `context.delete(tx)` loop it precedes. That is what
    /// lets `DuplicateReviewService` — which is not `@MainActor` — call it.
    nonisolated static func detachForBulkDelete(_ rows: [Transaction]) {
        // A single-row delete has nothing to gain: one identity-removal either way.
        guard rows.count > 1 else { return }

        let doomedRows = Set(rows.map(\.persistentModelID))
        let doomedSplits = Set(rows.flatMap { $0.splits ?? [] }.map(\.persistentModelID))

        // Deduplicate by identity first: with 8k rows over 7 categories this is the
        // difference between rebuilding 7 arrays and rebuilding 8,000 times.
        var categories: [PersistentIdentifier: Category] = [:]
        var sources: [PersistentIdentifier: Source] = [:]
        for tx in rows {
            if let c = tx.category { categories[c.persistentModelID] = c }
            if let s = tx.source { sources[s.persistentModelID] = s }
            for split in tx.splits ?? [] {
                if let c = split.category { categories[c.persistentModelID] = c }
            }
        }

        for category in categories.values {
            if let txs = category.transactions {
                category.transactions = txs.filter { !doomedRows.contains($0.persistentModelID) }
            }
            if let splits = category.splits {
                category.splits = splits.filter { !doomedSplits.contains($0.persistentModelID) }
            }
        }
        for source in sources.values {
            if let txs = source.transactions {
                source.transactions = txs.filter { !doomedRows.contains($0.persistentModelID) }
            }
        }
    }
}
