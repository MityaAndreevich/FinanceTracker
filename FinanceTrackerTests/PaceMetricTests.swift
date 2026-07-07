//
//  PaceMetricTests.swift
//  FinanceTrackerTests
//
//  Locks the spending-velocity math (Item 3): pace is judged against the user's
//  own prior daily baseline, must not divide by zero, and degrades to
//  `.unavailable` (hidden cue) when there's nothing to compare against.
//

import XCTest
@testable import FinanceTracker

final class PaceMetricTests: XCTestCase {

    // MARK: - Direction

    func test_aboveBaselineBeyondTolerance_isFaster() {
        // 200/day vs 100/day baseline → clearly faster.
        let s = PaceMetric.evaluate(spentThisPeriodCents: 2000, elapsedDays: 10,
                                    baselineDailyCents: 100)
        XCTAssertEqual(s, .faster)
    }

    func test_belowBaselineBeyondTolerance_isUnder() {
        // 50/day vs 100/day baseline → under.
        let s = PaceMetric.evaluate(spentThisPeriodCents: 500, elapsedDays: 10,
                                    baselineDailyCents: 100)
        XCTAssertEqual(s, .under)
    }

    func test_withinTolerance_isOnPace() {
        // 105/day vs 100/day baseline, default 15% band → on pace.
        let s = PaceMetric.evaluate(spentThisPeriodCents: 1050, elapsedDays: 10,
                                    baselineDailyCents: 100)
        XCTAssertEqual(s, .onPace)
    }

    // MARK: - Guards (no crash / no divide-by-zero)

    func test_zeroElapsedDays_isUnavailable() {
        // Day 0 / empty period must not divide by zero.
        let s = PaceMetric.evaluate(spentThisPeriodCents: 500, elapsedDays: 0,
                                    baselineDailyCents: 100)
        XCTAssertEqual(s, .unavailable)
    }

    func test_noHistory_isUnavailable() {
        // No prior baseline → nothing to compare against → hidden.
        let s = PaceMetric.evaluate(spentThisPeriodCents: 500, elapsedDays: 10,
                                    baselineDailyCents: 0)
        XCTAssertEqual(s, .unavailable)
        XCTAssertFalse(s.isShown)
    }

    // MARK: - Sparse but valid data still produces a verdict

    func test_sparseCurrentMonth_stillJudgedAgainstBaseline() {
        // One small purchase early in the month, against an established baseline,
        // reads as "under" — a meaningful, calm signal (not unavailable).
        let s = PaceMetric.evaluate(spentThisPeriodCents: 300, elapsedDays: 3,
                                    baselineDailyCents: 500)
        XCTAssertEqual(s, .under)
        XCTAssertTrue(s.isShown)
    }

    // MARK: - Baseline source (budget preferred, history fallback)

    func test_baseline_prefersBudget_whenSet() {
        // $300 budget / 30 days = $10/day, regardless of prior history.
        let b = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: 30_000, daysInMonth: 30,
            priorExpenseCents: 999_999, priorSpanDays: 1)
        XCTAssertEqual(b, 1000, accuracy: 0.001)
    }

    func test_baseline_fallsBackToHistory_whenNoBudget() {
        // No budget → prior 60,000 over 20 days = 3,000/day.
        let b = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: 0, daysInMonth: 30,
            priorExpenseCents: 60_000, priorSpanDays: 20)
        XCTAssertEqual(b, 3000, accuracy: 0.001)
    }

    func test_baseline_zero_whenNeitherAvailable() {
        // No budget and no history → 0 → cue hidden downstream.
        let b = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: 0, daysInMonth: 30,
            priorExpenseCents: 0, priorSpanDays: 0)
        XCTAssertEqual(b, 0)
        XCTAssertEqual(
            PaceMetric.evaluate(spentThisPeriodCents: 5000, elapsedDays: 10,
                                baselineDailyCents: b),
            .unavailable)
    }

    func test_shown_flagMatchesState() {
        XCTAssertTrue(PaceMetric.State.faster.isShown)
        XCTAssertTrue(PaceMetric.State.onPace.isShown)
        XCTAssertTrue(PaceMetric.State.under.isShown)
        XCTAssertFalse(PaceMetric.State.unavailable.isShown)
    }
}
