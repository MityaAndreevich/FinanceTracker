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
    /// The figures `snapshot(...)` + the category-limit policy need, as a
    /// Sendable value type — the only thing allowed across the actor boundary.
    struct Aggregate: Equatable, Sendable {
        let spentThisMonthCents: Int
        let priorExpenseCents: Int
        let priorSpanDays: Int
        /// Month-to-date position of every category that HAS a limit set —
        /// tiny (limits are opt-in per category). Spend is attribution-based
        /// (splits count toward the splits' categories, §6.3); the three
        /// totals above stay parent-summed — never "unify" them.
        let limitStatuses: [CategoryLimitPolicy.Status]
    }

    /// The shared computation both the actor and the synchronous test form
    /// use, so the two paths cannot drift.
    static func makeAggregate(
        transactions: [Transaction],
        limitedCategories: [(uuid: UUID, displayName: String, limitCents: Int)],
        now: Date,
        calendar: Calendar = .current
    ) -> Aggregate {
        let agg = aggregate(entries: entries(from: transactions), now: now)

        var statuses: [CategoryLimitPolicy.Status] = []
        if !limitedCategories.isEmpty {
            let today = calendar.startOfDay(for: now)
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? today
            let rows = transactions.flatMap { CategoryAttribution.rows(for: $0) }
            let spent = CategoryLimitPolicy.spentByCategory(
                rows: rows, monthStart: monthStart, today: today, calendar: calendar
            )
            statuses = limitedCategories.map {
                CategoryLimitPolicy.Status(
                    categoryUUID: $0.uuid,
                    displayName: $0.displayName,
                    limitCents: $0.limitCents,
                    spentCents: spent[$0.uuid] ?? 0
                )
            }
        }

        return Aggregate(
            spentThisMonthCents: agg.spentThisMonthCents,
            priorExpenseCents: agg.priorExpenseCents,
            priorSpanDays: agg.priorSpanDays,
            limitStatuses: statuses
        )
    }
}

@ModelActor
actor LedgerAggregator {

    /// Full-ledger safe-to-spend + category-limit aggregation, off the main
    /// thread. One fetch pass feeds both (the hot-path budget from the hang
    /// brief still holds); only Sendable value types cross the boundary.
    ///
    /// The tuple-returning `SafeToSpend.aggregate` stays the single source of
    /// the arithmetic; this only relocates the fetch that feeds it.
    func safeToSpendAggregate(now: Date) -> SafeToSpend.Aggregate {
        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let limited = ((try? modelContext.fetch(FetchDescriptor<Category>())) ?? [])
            .compactMap { category -> (uuid: UUID, displayName: String, limitCents: Int)? in
                guard let limit = category.limitCents, limit > 0 else { return nil }
                return (category.uuid, category.displayName(), limit)
            }
        return SafeToSpend.makeAggregate(
            transactions: transactions, limitedCategories: limited, now: now
        )
    }
}
