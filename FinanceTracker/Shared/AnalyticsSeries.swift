//
//  AnalyticsSeries.swift
//  FinanceTracker
//
//  The Analytics time-series accumulations (Pulse daily net + gross totals,
//  Horizon 12-month income/expense), extracted from AnalyticsView (design doc
//  §8.1) so the SplitCanary suite pins the PRODUCTION formulas instead of a
//  copy. Behavior-identical to the loops they replace.
//
//  ⚠️ CATEGORY-BLIND BY DESIGN — parent transactions only, never
//  CategoryAttribution rows (splits carry no date/direction of their own and
//  adding them here double-counts). Canary:
//  SplitCanaryTests.timeSeriesAreUnchangedBySplitting (design doc §8.2 C4).
//

import Foundation

enum AnalyticsSeries {

    // MARK: - Pulse (this-month daily net + gross totals)

    struct DayNet: Equatable, Sendable {
        let date: Date
        let cents: Int
    }

    struct PulseTotals: Equatable, Sendable {
        let daily: [DayNet]
        let earnedCents: Int
        let spentCents: Int
        var netCents: Int { daily.reduce(0) { $0 + $1.cents } }
    }

    /// Daily net series from `monthStart` through `today` (zero-filled), plus
    /// gross earned/spent accumulated per-transaction so same-day income +
    /// larger expenses never cancel out.
    static func pulse(
        transactions: [Transaction],
        calendar cal: Calendar,
        monthStart: Date,
        today: Date
    ) -> PulseTotals {
        var dayNet: [Date: Int] = [:]
        var earned = 0
        var spent = 0
        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            dayNet[day, default: 0] += tx.signedAmountCents
            if tx.isIncome {
                earned += tx.amountCents
            } else {
                spent += tx.amountCents
            }
        }

        var out: [DayNet] = []
        var cursor = monthStart
        while cursor <= today {
            out.append(DayNet(date: cursor, cents: dayNet[cursor] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return PulseTotals(daily: out, earnedCents: earned, spentCents: spent)
    }

    // MARK: - Horizon (12-month income/expense magnitudes)

    struct MonthNet: Equatable, Sendable {
        let monthStart: Date
        let incomeCents: Int
        let expenseCents: Int
    }

    /// Income and expense magnitudes per month for the 12 months ending at
    /// `monthStart` (zero-filled) — net is derived by the view as income − expense.
    static func horizon(
        transactions: [Transaction],
        calendar cal: Calendar,
        monthStart: Date
    ) -> [MonthNet] {
        guard let horizonStart = cal.date(byAdding: .month, value: -11, to: monthStart) else {
            return []
        }

        struct MonthAcc { var income = 0; var expense = 0 }
        var monthAcc: [Date: MonthAcc] = [:]
        for tx in transactions {
            guard let mStart = cal.date(from: cal.dateComponents([.year, .month], from: tx.date)) else { continue }
            guard mStart >= horizonStart && mStart <= monthStart else { continue }
            if tx.isIncome {
                monthAcc[mStart, default: MonthAcc()].income += tx.amountCents
            } else {
                monthAcc[mStart, default: MonthAcc()].expense += tx.amountCents
            }
        }

        var out: [MonthNet] = []
        var cursor = horizonStart
        while cursor <= monthStart {
            let acc = monthAcc[cursor] ?? MonthAcc()
            out.append(MonthNet(monthStart: cursor, incomeCents: acc.income, expenseCents: acc.expense))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }
}
