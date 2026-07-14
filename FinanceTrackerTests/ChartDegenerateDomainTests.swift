//
//  ChartDegenerateDomainTests.swift
//  FinanceTrackerTests
//
//  The gap left by every previous harness. Earlier rounds varied the DATA by
//  *count* (ChartGuards.canRenderContinuous(pointCount:)) and varied the
//  GEOMETRY (ChartDegenerateFrameTests). Neither ever varied the thing the
//  device stack actually points at: the auto-computed continuous SCALE DOMAIN.
//
//  No chart in this app sets an explicit `.chartYScale(domain:)`, so Charts
//  derives the Y domain from the data. When every value in the series is the
//  SAME, that domain is [v, v] — zero height. Charts then subdivides a zero
//  extent looking for "nice" ticks (the recursive scale frames #4-8 in the
//  device report) and traps, with no app frame on the stack.
//
//  `pointCount >= 2` does NOT prevent this: N identical points still collapse
//  the domain. Both real series are DENSE and ZERO-FILLED, so an all-equal
//  series is not exotic, it is the ordinary early state:
//
//    * Pulse    — dailyTotals is every day month-start..today, 0 on days with
//                 no transactions. Every day nets 0 the moment an expense is
//                 cancelled by an equal income (the "crash on the 2nd
//                 transaction" report), or when all transactions fall outside
//                 the current month.
//    * Horizon  — monthlyTotals is 12 months, 0 for months with no data, and
//                 the mode is PERSISTED in @AppStorage("horizon_mode"). In
//                 .income mode a user who only logs expenses has incomeCents
//                 == 0 for all 12 months. That is the common case for a
//                 finance app.
//
//  These tests hold the FRAME valid (353x852 — a real iPhone box, so the frame
//  guard cannot mask anything) and make only the DOMAIN degenerate. Before the
//  domain guard they trap inside Charts; after it they must render a
//  placeholder.
//

import XCTest
import SwiftUI
import SwiftData
@testable import FinanceTracker

@MainActor
final class ChartDegenerateDomainTests: XCTestCase {

    private var window: UIWindow!

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
        UserDefaults.standard.removeObject(forKey: "horizon_mode")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    /// Host a view in a REAL, VALID iPhone-sized box and force a layout pass.
    /// The box is deliberately healthy: anything that traps here traps on the
    /// DOMAIN, not the geometry.
    private func render(_ view: some View) {
        let host = UIHostingController(rootView: view)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    // MARK: - Fixtures reproducing the REAL dense, zero-filled series

    /// Pulse exactly as `AnalyticsView.recomputePulse` builds it: one point per
    /// day from month-start to today, `cents` == 0 on days with no activity.
    private func pulse(everyDayNets cents: Int, days: Int = 14) -> AnalyticsPulseView {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let totals = (0..<days).map { i in
            AnalyticsPulseView.DailyTotal(
                date: cal.date(byAdding: .day, value: i, to: start)!,
                cents: cents
            )
        }
        return AnalyticsPulseView(
            dailyTotals: totals,
            netCents: cents * days,
            earnedCents: 5_000,
            spentCents: 5_000,
            currencyCode: "RUB"
        )
    }

    /// Horizon exactly as `AnalyticsView.recomputeHorizon` builds it: 12 months,
    /// zero-filled.
    private func horizon(income: Int, expense: Int) -> AnalyticsHorizonView {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let totals = (0..<12).map { i in
            AnalyticsHorizonView.MonthlyTotal(
                date: cal.date(byAdding: .month, value: i - 11, to: start)!,
                incomeCents: income,
                expenseCents: expense
            )
        }
        return AnalyticsHorizonView(monthlyTotals: totals, currencyCode: "RUB")
    }

    // MARK: - REPRO: Pulse, valid frame, degenerate Y domain

    /// THE REPORTED CRASH. Transaction #1 is an expense, transaction #2 is an
    /// equal income on the same day → that day nets 0 → every day in the dense
    /// series is 0 → Y domain is [0, 0].
    func test_pulse_everyDayNetsZero_secondTransactionCancelsTheFirst() {
        render(pulse(everyDayNets: 0))
    }

    /// The same degenerate domain without the zero: a flat non-zero series still
    /// collapses to [v, v].
    func test_pulse_everyDayNetsSameNonZeroValue() {
        render(pulse(everyDayNets: -1_200))
    }

    /// Two points is the minimum `canRenderContinuous` allows — and two IDENTICAL
    /// points is still a zero-height domain. This is the precise hole in the
    /// count-based guard.
    func test_pulse_twoIdenticalPoints_passesCountGuardButDomainIsDegenerate() {
        XCTAssertTrue(
            ChartGuards.canRenderContinuous(pointCount: 2),
            "precondition: the count guard lets this through"
        )
        render(pulse(everyDayNets: 0, days: 2))
    }

    // MARK: - REPRO: Horizon, valid frame, degenerate Y domain

    /// A user who only ever logs EXPENSES, with the persisted mode on .income →
    /// incomeCents == 0 across all 12 months → Y domain [0, 0]. Ordinary state.
    func test_horizon_incomeMode_userHasOnlyExpenses() {
        UserDefaults.standard.set("income", forKey: "horizon_mode")
        render(horizon(income: 0, expense: 40_000))
    }

    /// The mirror: only income logged, mode persisted on .expenses.
    func test_horizon_expensesMode_userHasOnlyIncome() {
        UserDefaults.standard.set("expenses", forKey: "horizon_mode")
        render(horizon(income: 40_000, expense: 0))
    }

    /// Default .net mode, every month netting exactly zero.
    func test_horizon_netMode_everyMonthNetsZero() {
        UserDefaults.standard.set("net", forKey: "horizon_mode")
        render(horizon(income: 40_000, expense: 40_000))
    }

    /// .combined plots two series; the expense one is flat-zero here.
    func test_horizon_combinedMode_oneSeriesIsFlatZero() {
        UserDefaults.standard.set("combined", forKey: "horizon_mode")
        render(horizon(income: 40_000, expense: 0))
    }

    // MARK: - The guard itself
    //
    // Surviving the render is not the bar (the simulator has repeatedly survived
    // what the device traps on). The bar is that Charts is never ASKED to build a
    // scale on a zero-width domain. Assert that as a property.

    func test_flatSeries_isRefused() {
        XCTAssertFalse(ChartGuards.canRenderContinuous(cents: [0, 0, 0]),
                       "all-zero series → domain [0,0]")
        XCTAssertFalse(ChartGuards.canRenderContinuous(cents: [-1_200, -1_200]),
                       "flat non-zero series → domain [v,v]")
        XCTAssertFalse(ChartGuards.canRenderContinuous(cents: [5_000]),
                       "single point → zero-width domain")
        XCTAssertFalse(ChartGuards.canRenderContinuous(cents: []),
                       "empty series has no domain at all")
    }

    func test_seriesWithSpread_isAccepted() {
        XCTAssertTrue(ChartGuards.canRenderContinuous(cents: [0, -1_200]),
                      "any two distinct values span a real domain")
        XCTAssertTrue(ChartGuards.canRenderContinuous(cents: [0, 0, 0, -800, 0]),
                      "one non-zero day among zeros is perfectly renderable")
    }

    func test_nonFiniteValues_areRefused() {
        let nanSeries: [Double] = [.nan, 1]
        let infSeries: [Double] = [0, .infinity]
        XCTAssertFalse(ChartGuards.canRenderContinuous(values: nanSeries),
                       "NaN cannot bound a scale")
        XCTAssertFalse(ChartGuards.canRenderContinuous(values: infSeries),
                       "an unbounded domain is not mappable either")
    }
}
