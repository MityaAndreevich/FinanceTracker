//
//  SafeToSpendTests.swift
//  FinanceTrackerTests
//
//  Safe-to-spend used to live inside DashboardView, which meant anything else that
//  needed the number had to recompute it — and a notification that disagrees with the
//  dashboard is exactly the trust bug the alerts feature exists to avoid. These tests
//  pin the extracted maths.
//

import Testing
import Foundation
@testable import FinanceTracker

struct SafeToSpendTests {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func snapshot(
        budget: Int,
        spent: Int,
        now: Date,
        priorExpense: Int = 0,
        priorSpan: Int = 0
    ) -> SafeToSpend.Snapshot {
        SafeToSpend.snapshot(
            monthlyBudgetCents: budget,
            spentThisMonthCents: spent,
            priorExpenseCents: priorExpense,
            priorSpanDays: priorSpan,
            now: now,
            calendar: cal
        )
    }

    // MARK: - The number itself

    @Test func remainingIsBudgetMinusSpend() {
        let s = snapshot(budget: 100_000, spent: 40_000, now: date(2026, 7, 10))
        #expect(s.remainingCents == 60_000)
    }

    @Test func remainingGoesNegativeWhenOverBudget() {
        // The snapshot reports the truth. Suppressing the alert is the POLICY's job,
        // not this type's — this must not clamp to zero and hide it.
        let s = snapshot(budget: 100_000, spent: 130_000, now: date(2026, 7, 10))
        #expect(s.remainingCents == -30_000)
    }

    @Test func noBudgetIsNotSet() {
        #expect(snapshot(budget: 0, spent: 5_000, now: date(2026, 7, 10)).isBudgetSet == false)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 10)).isBudgetSet == true)
    }

    @Test func theSharedSubtractionIsTheOneDashboardUses() {
        #expect(SafeToSpend.remainingCents(monthlyBudgetCents: 100_000, spentCents: 40_000) == 60_000)
        #expect(SafeToSpend.remainingCents(monthlyBudgetCents: 100_000, spentCents: 130_000) == -30_000)
    }

    // MARK: - Calendar fields

    @Test func elapsedDaysCountsTodayInclusive() {
        // Day-to-date window: the 1st is day 1, not day 0.
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 1)).elapsedDays == 1)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 14)).elapsedDays == 14)
    }

    @Test func daysInMonthFollowsTheRealCalendar() {
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 14)).daysInMonth == 31)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 2, 14)).daysInMonth == 28)
        #expect(snapshot(budget: 1, spent: 0, now: date(2028, 2, 14)).daysInMonth == 29)  // leap
    }

    // MARK: - Aggregation over a ledger

    private func expense(_ cents: Int, _ d: Date) -> SafeToSpend.Entry {
        SafeToSpend.Entry(amountCents: cents, date: d, isIncome: false)
    }

    private func income(_ cents: Int, _ d: Date) -> SafeToSpend.Entry {
        SafeToSpend.Entry(amountCents: cents, date: d, isIncome: true)
    }

    @Test func aggregateSumsThisMonthsExpensesOnly() {
        let agg = SafeToSpend.aggregate(
            entries: [
                expense(5_000, date(2026, 7, 2)),
                expense(3_000, date(2026, 7, 10)),
                income(90_000, date(2026, 7, 5)),      // income is not spending
                expense(7_000, date(2026, 6, 20)),     // prior month
            ],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.spentThisMonthCents == 8_000)
        #expect(agg.priorExpenseCents == 7_000)
    }

    @Test func priorSpanIsMeasuredFromTheEarliestPriorExpense() {
        let agg = SafeToSpend.aggregate(
            entries: [
                expense(1_000, date(2026, 6, 1)),
                expense(1_000, date(2026, 6, 15)),
            ],
            now: date(2026, 7, 14), calendar: cal
        )
        // 1 June → 1 July is 30 days of history.
        #expect(agg.priorSpanDays == 30)
        #expect(agg.priorExpenseCents == 2_000)
    }

    @Test func noPriorHistoryIsZeroSpanNotACrash() {
        // A brand-new user has no "usual" to compare against. This must yield 0, which
        // drives PaceMetric to .unavailable rather than dividing by zero.
        let agg = SafeToSpend.aggregate(
            entries: [expense(1_000, date(2026, 7, 3))],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.priorExpenseCents == 0)
        #expect(agg.priorSpanDays == 0)
    }

    @Test func emptyLedgerAggregatesToZeros() {
        let agg = SafeToSpend.aggregate(entries: [], now: date(2026, 7, 14), calendar: cal)
        #expect(agg.spentThisMonthCents == 0)
        #expect(agg.priorExpenseCents == 0)
        #expect(agg.priorSpanDays == 0)
    }

    @Test func futureDatedExpensesDoNotCountAsSpentYet() {
        // A transaction dated later this month has not been spent as of today.
        let agg = SafeToSpend.aggregate(
            entries: [expense(9_000, date(2026, 7, 28))],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.spentThisMonthCents == 0)
    }
}
