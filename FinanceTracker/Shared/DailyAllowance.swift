//
//  DailyAllowance.swift
//  FinanceTracker
//
//  The Velocity Dashboard's forward-looking numbers (1.0.3 Item 2): what's safe
//  to spend TODAY, how much of the monthly budget is used (the non-numeric
//  status donut), and whether the month is on pace to finish under budget
//  (forecast = spent ÷ days elapsed × days in month, vs the stored budget).
//
//  Research note behind the shape: budgets fail because they're monthly limits
//  but life is lived in daily decisions — the daily number is the retention
//  lever, so it is the hero; the monthly budget degrades to a percentage ring,
//  never a second competing currency figure.
//
//  Pure and guarded the ChartGuards way: every emitted value is finite, the
//  fraction is clamped 0…1, day counts are floored at 1 — no NaN can escape,
//  across month boundaries, a zero budget, or a fully-spent budget.
//

import Foundation

enum DailyAllowance {

    struct Snapshot: Equatable, Sendable {
        /// What's safe to spend today (and each remaining day). 0 when the
        /// budget is exhausted — the truth, calmly.
        let perDayCents: Int
        /// Days remaining in the month, today inclusive. ≥ 1.
        let daysLeft: Int
        /// Budget used, clamped 0…1 — drives the status donut fill.
        let fractionUsed: Double
        /// Budget used as a display percentage (can exceed 100 when over).
        let percentUsed: Int
        let isOverBudget: Bool
        /// Month-end spend at the current daily rate (spent ÷ elapsed × days).
        let forecastCents: Int
        /// Gain-framed pace verdict: at the current rate, does the month land
        /// within the budget?
        let onPaceToStayUnder: Bool
    }

    /// nil when no budget is set — the Velocity hero only exists against a budget.
    static func compute(
        monthlyBudgetCents: Int,
        spentThisMonthCents: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Snapshot? {
        guard monthlyBudgetCents > 0 else { return nil }

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = max(1, calendar.component(.day, from: now))
        let daysLeft = max(1, daysInMonth - dayOfMonth + 1)

        // nil = this allowance cannot be computed. Snapshot is ALREADY optional —
        // the hero simply falls back to its non-allowance path — so reporting
        // costs nothing here and a wrong daily number would cost a lot.
        let (remaining, remainingOverflow) =
            monthlyBudgetCents.subtractingReportingOverflow(spentThisMonthCents)
        guard !remainingOverflow else { return nil }
        let perDay = remaining > 0 ? remaining / daysLeft : 0

        let spent = max(0, spentThisMonthCents)
        let rawFraction = Double(spent) / Double(monthlyBudgetCents)
        let fraction = rawFraction.isFinite ? min(max(rawFraction, 0), 1) : 0
        let percent = rawFraction.isFinite ? Int((rawFraction * 100).rounded()) : 0

        // Multiply before dividing: `spent / dayOfMonth` truncates first and
        // understates the projection by up to daysInMonth−1 cents. The multiply is
        // exactly why this trapped — `spent` is a month's total, so a ledger the
        // dashboard CAN sum can still overflow when projected forward.
        //
        // The 25th site, and the one that proved the point about proxies: the
        // journey test only reached it once its final assertion became POSITIVE
        // (the hero label must be back). "The unavailable card is gone" had been
        // passing while the app crashed rendering the hero right behind it.
        let (scaled, forecastOverflow) = spent.multipliedReportingOverflow(by: daysInMonth)
        guard !forecastOverflow else { return nil }
        let forecast = scaled / dayOfMonth

        return Snapshot(
            perDayCents: perDay,
            daysLeft: daysLeft,
            fractionUsed: fraction,
            percentUsed: percent,
            isOverBudget: remaining < 0,
            forecastCents: forecast,
            onPaceToStayUnder: forecast <= monthlyBudgetCents
        )
    }
}
