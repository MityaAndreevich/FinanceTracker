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

    // MARK: - Pulse (daily net + gross totals over a day range)

    struct DayNet: Equatable, Sendable {
        let date: Date
        let cents: Int
    }

    struct PulseTotals: Equatable, Sendable {
        let daily: [DayNet]
        let earnedCents: Int
        let spentCents: Int
        /// Sum of the daily nets. Nil when it cannot be represented — every
        /// daily cent was representable individually, their sum need not be.
        var netCents: Int? {
            var acc = 0
            for d in daily {
                let (sum, overflow) = acc.addingReportingOverflow(d.cents)
                if overflow { return nil }
                acc = sum
            }
            return acc
        }
    }

    /// Daily net series from `monthStart` through `today` (zero-filled), plus
    /// gross earned/spent accumulated per-transaction so same-day income +
    /// larger expenses never cancel out.
    ///
    /// **Nil means unavailable** (D5): a sum that cannot be represented. Never a
    /// wrapped, saturated or zeroed number — the caller shows the unavailable
    /// state, the way the Dashboard does for `MonthTotals`.
    static func pulse(
        transactions: [Transaction],
        calendar cal: Calendar,
        monthStart: Date,
        today: Date
    ) -> PulseTotals? {
        pulse(entries: SafeToSpend.entries(from: transactions), calendar: cal, monthStart: monthStart, today: today)
    }

    /// The pure form: parent rows only (category-blind by design, see the header).
    /// `monthStart`/`today` are the inclusive day bounds of the series — despite
    /// the parameter names, any day range works; Reports pass a week or a year.
    static func pulse(
        entries: [SafeToSpend.Entry],
        calendar cal: Calendar,
        monthStart: Date,
        today: Date
    ) -> PulseTotals? {
        var dayNet: [Date: Int] = [:]
        var earned = 0
        var spent = 0
        for e in entries {
            let day = cal.startOfDay(for: e.date)
            guard day >= monthStart && day <= today else { continue }
            let signed = e.isIncome ? e.amountCents : -e.amountCents
            let (dayTotal, dayOverflow) = (dayNet[day] ?? 0).addingReportingOverflow(signed)
            if dayOverflow { return nil }
            dayNet[day] = dayTotal
            if e.isIncome {
                let (sum, overflow) = earned.addingReportingOverflow(e.amountCents)
                if overflow { return nil }
                earned = sum
            } else {
                let (sum, overflow) = spent.addingReportingOverflow(e.amountCents)
                if overflow { return nil }
                spent = sum
            }
        }

        var out: [DayNet] = []
        var cursor = cal.startOfDay(for: monthStart)
        let last = cal.startOfDay(for: today)
        while cursor <= last {
            out.append(DayNet(date: cursor, cents: dayNet[cursor] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return PulseTotals(daily: out, earnedCents: earned, spentCents: spent)
    }

    // MARK: - Horizon (monthly income/expense magnitudes)

    struct MonthNet: Equatable, Sendable {
        let monthStart: Date
        let incomeCents: Int
        let expenseCents: Int
    }

    /// Income and expense magnitudes per month for the 12 months ending at
    /// `monthStart` (zero-filled) — net is derived by the view as income − expense.
    /// **Nil means unavailable** (D5).
    static func horizon(
        transactions: [Transaction],
        calendar cal: Calendar,
        monthStart: Date
    ) -> [MonthNet]? {
        guard let horizonStart = cal.date(byAdding: .month, value: -11, to: monthStart) else {
            return []
        }
        return months(entries: SafeToSpend.entries(from: transactions), calendar: cal,
                      firstMonthStart: horizonStart, lastMonthStart: monthStart)
    }

    /// The pure form, over an explicit inclusive range of month starts. Horizon
    /// is the trailing-12 instance; a year report is the Jan…Dec instance —
    /// the same accumulation, so the two cannot disagree on a shared month.
    static func months(
        entries: [SafeToSpend.Entry],
        calendar cal: Calendar,
        firstMonthStart: Date,
        lastMonthStart: Date
    ) -> [MonthNet]? {
        struct MonthAcc { var income = 0; var expense = 0 }
        var monthAcc: [Date: MonthAcc] = [:]
        for e in entries {
            guard let mStart = cal.date(from: cal.dateComponents([.year, .month], from: e.date)) else { continue }
            guard mStart >= firstMonthStart && mStart <= lastMonthStart else { continue }
            var acc = monthAcc[mStart] ?? MonthAcc()
            if e.isIncome {
                let (sum, overflow) = acc.income.addingReportingOverflow(e.amountCents)
                if overflow { return nil }
                acc.income = sum
            } else {
                let (sum, overflow) = acc.expense.addingReportingOverflow(e.amountCents)
                if overflow { return nil }
                acc.expense = sum
            }
            monthAcc[mStart] = acc
        }

        var out: [MonthNet] = []
        var cursor = firstMonthStart
        while cursor <= lastMonthStart {
            let acc = monthAcc[cursor] ?? MonthAcc()
            out.append(MonthNet(monthStart: cursor, incomeCents: acc.income, expenseCents: acc.expense))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }
}
