//
//  LedgerAggregator.swift
//  FinanceTracker
//
//  Off-main ledger aggregation (hang-brief Item 1, executed at last).
//
//  Safe-to-spend's pace baseline is defined over the user's ENTIRE prior
//  history (all-time prior expense / span), so the full-table read cannot be
//  scoped away without changing the number. What it can be is moved: this
//  @ModelActor owns its own ModelContext on its own executor, performs the
//  fetch + arithmetic there, and returns a plain value type. Measured cost of
//  the same work on the main actor: ~1.0-1.2s per pass at 12k rows — paid on
//  EVERY ModelContext.didSave, twice per QuickAdd entry. Off-main it costs the
//  UI nothing.
//
//  Project rule honored: the background thread touches ModelContext only
//  through this ModelActor, and no PersistentModel crosses the boundary —
//  `SafeToSpend.Aggregate` is three Ints.
//

import Foundation
import SwiftData

extension SafeToSpend {
    /// The three figures `snapshot(...)` needs, as a Sendable value type — the
    /// only thing allowed across the actor boundary.
    struct Aggregate: Equatable, Sendable {
        let spentThisMonthCents: Int
        let priorExpenseCents: Int
        let priorSpanDays: Int
    }
}

@ModelActor
actor LedgerAggregator {

    /// Full-ledger safe-to-spend aggregation, off the main thread.
    ///
    /// The tuple-returning `SafeToSpend.aggregate` stays the single source of
    /// the arithmetic; this only relocates the fetch that feeds it.
    func safeToSpendAggregate(now: Date) -> SafeToSpend.Aggregate {
        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let agg = SafeToSpend.aggregate(
            entries: SafeToSpend.entries(from: transactions),
            now: now
        )
        return SafeToSpend.Aggregate(
            spentThisMonthCents: agg.spentThisMonthCents,
            priorExpenseCents: agg.priorExpenseCents,
            priorSpanDays: agg.priorSpanDays
        )
    }
}
