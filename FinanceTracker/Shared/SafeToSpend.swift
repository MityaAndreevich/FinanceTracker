//
//  SafeToSpend.swift
//  FinanceTracker
//
//  What's left of this month's budget, and the history PaceMetric needs to judge
//  spending velocity — as pure data, computable anywhere.
//
//  This used to live inside DashboardView. It was extracted because the proactive
//  alerts need the same number, and a notification that disagrees with the dashboard
//  would erode trust on a money app faster than no notification at all. One
//  computation, two consumers, no possible drift.
//

import Foundation

enum SafeToSpend {

    /// The three fields the arithmetic actually needs from a ledger row.
    ///
    /// `Transaction.init` requires a non-optional `Category`, so taking `[Transaction]`
    /// directly would drag a SwiftData `ModelContainer` into tests that are pure
    /// arithmetic. This keeps the maths testable with plain structs and confines the
    /// SwiftData dependency to one `map`.
    struct Entry: Equatable, Sendable {
        let amountCents: Int
        let date: Date
        let isIncome: Bool
    }

    /// A month's spending position. Reports the truth, including a negative
    /// `remainingCents` — deciding what to *do* about being over budget (namely: stay
    /// silent) belongs to `ProactiveAlertPolicy`, not here.
    struct Snapshot: Equatable, Sendable {
        let monthlyBudgetCents: Int
        let spentCents: Int
        /// Days elapsed this month, today inclusive — the day-to-date window.
        let elapsedDays: Int
        let daysInMonth: Int
        /// Gross expense before this month, and the day-span it covers. Feeds
        /// `PaceMetric.baselineDailyCents` for budget-less users.
        let priorExpenseCents: Int
        let priorSpanDays: Int

        /// Can be negative. Do not clamp — the caller needs to know.
        var remainingCents: Int {
            SafeToSpend.remainingCents(
                monthlyBudgetCents: monthlyBudgetCents,
                spentCents: spentCents
            )
        }

        var isBudgetSet: Bool { monthlyBudgetCents > 0 }
    }

    /// The one subtraction, in one place. `DashboardView` and the alerts both call this,
    /// so they cannot drift apart.
    static func remainingCents(monthlyBudgetCents: Int, spentCents: Int) -> Int {
        monthlyBudgetCents - spentCents
    }

    static func snapshot(
        monthlyBudgetCents: Int,
        spentThisMonthCents: Int,
        priorExpenseCents: Int,
        priorSpanDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Snapshot {
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let elapsedDays = calendar.component(.day, from: now)

        return Snapshot(
            monthlyBudgetCents: monthlyBudgetCents,
            spentCents: spentThisMonthCents,
            elapsedDays: elapsedDays,
            daysInMonth: daysInMonth,
            priorExpenseCents: priorExpenseCents,
            priorSpanDays: priorSpanDays
        )
    }

    /// Rolls a ledger up into the three figures `snapshot(...)` needs.
    static func aggregate(
        entries: [Entry],
        now: Date,
        calendar: Calendar = .current
    ) -> (spentThisMonthCents: Int, priorExpenseCents: Int, priorSpanDays: Int) {
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return (0, 0, 0) }

        let today = calendar.startOfDay(for: now)
        var spentThisMonth = 0
        var priorExpense = 0
        var earliestPriorDay: Date?

        for entry in entries where !entry.isIncome {
            let day = calendar.startOfDay(for: entry.date)
            if day < monthStart {
                priorExpense += entry.amountCents
                earliestPriorDay = earliestPriorDay.map { min($0, day) } ?? day
            } else if day <= today {
                // A future-dated expense has not been spent yet.
                spentThisMonth += entry.amountCents
            }
        }

        let priorSpanDays = earliestPriorDay
            .flatMap { calendar.dateComponents([.day], from: $0, to: monthStart).day } ?? 0

        return (spentThisMonth, priorExpense, priorSpanDays)
    }

    /// The only place this type touches SwiftData.
    static func entries(from transactions: [Transaction]) -> [Entry] {
        transactions.map {
            Entry(amountCents: $0.amountCents, date: $0.date, isIncome: $0.isIncome)
        }
    }
}
