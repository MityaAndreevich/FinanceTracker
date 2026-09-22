//
//  ReportEqualityCanaryTests.swift
//  FinanceTrackerTests
//
//  THE BRIEF'S EXPLICIT REQUIREMENT (BRIEF_MASTER_2026-09-21.md:156–157): every
//  figure in a report equals the same figure elsewhere in the app for the same
//  period. "Equal by construction" is the design's argument; this file is the
//  evidence. It rides on `SplitMirrorFixture` — the SPLIT-HEAVY ledger the
//  founder's approval condition asks for — and compares the report snapshot
//  against MonthTotals (Dashboard), AnalyticsSeries (Analytics Pulse/Horizon),
//  CategoryBreakdown (Analytics Breakdown) and CategoryAttribution, for the
//  same month.
//
//  Negative control: a mutant that drops the period's last day from the
//  builder's pulse fails `pulseSeriesEqual` — see the commit that added this.
//

import Foundation
import SwiftData
import Testing
@testable import FinanceTracker

@Suite("Report figures equal the app's figures (split-heavy fixture)")
@MainActor
struct ReportEqualityCanaryTests {

    private func makeReport(_ f: SplitMirrorFixture) throws -> (ReportSnapshot, [Transaction], [Transaction]) {
        let cal = Calendar.current
        let period = ReportPeriod.month(containing: f.now)
        let all = try f.allTransactions()
        let categories = try f.container.mainContext.fetch(FetchDescriptor<FinanceTracker.Category>())
        let input = LedgerAggregator.makeReportInput(transactions: all, categories: categories, period: period,
                                                     calendar: cal, bundle: .main)
        let snapshot = try #require(ReportBuilder.build(input: input, period: period, calendar: cal, monthlyBudgetCents: 50_000))
        let monthTxs = try f.monthTransactions()
        return (snapshot, monthTxs, all)
    }

    @Test("income and expense equal MonthTotals — the Dashboard's figures")
    func totalsEqualDashboard() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        #expect(f.hasSplits)
        let (s, monthTxs, _) = try makeReport(f)
        #expect(s.totals.expenseCents == MonthTotals.expenseCents(monthTxs))
        #expect(s.totals.incomeCents == MonthTotals.incomeCents(monthTxs))
        #expect(s.totals.expenseCents == f.expectedMonthExpenseCents)   // and the hand sum
        #expect(s.transactionCount == monthTxs.count)
    }

    @Test("category table equals MonthTotals.categorySpendBuckets AND CategoryBreakdown — Dashboard and Analytics")
    func categoriesEqualBothScreens() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let (s, monthTxs, _) = try makeReport(f)
        let dashboard = try #require(MonthTotals.categorySpendBuckets(monthTxs))
        let analytics = try #require(CategoryBreakdown.buckets(transactions: monthTxs))
        let report = Dictionary(uniqueKeysWithValues: s.expenseCategories.map { ($0.bucketID, $0.cents) })

        #expect(report == dashboard.mapValues { $0.1 })
        #expect(report == Dictionary(uniqueKeysWithValues: analytics.filter { !$0.value.isIncome }.map { ($0.key, $0.value.cents) }))
        // The split-heavy hand sums: Food 6 200 + 700 + 2 500, Home 4 000 + 2 500, Health 3 000 + 1 800.
        let byName = Dictionary(uniqueKeysWithValues: s.expenseCategories.map { ($0.label.name, $0.cents) })
        #expect(byName == ["Food": 9_400, "Home": 6_500, "Health": 4_800])
        // Σ categories == expense total, and each share is cents / total.
        #expect(s.expenseCategories.map(\.cents).reduce(0, +) == s.totals.expenseCents)
        for c in s.expenseCategories {
            #expect(abs(c.share - Double(c.cents) / Double(s.totals.expenseCents)) < 1e-12)
        }
    }

    @Test("the daily series and earned/spent equal AnalyticsSeries.pulse — Analytics Pulse")
    func pulseSeriesEqual() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let (s, monthTxs, _) = try makeReport(f)
        let cal = Calendar.current
        let range = ReportPeriod.month(containing: f.now).range(calendar: cal)
        let lastDay = cal.date(byAdding: .day, value: -1, to: range.upperBound)!
        let pulse = try #require(AnalyticsSeries.pulse(transactions: monthTxs, calendar: cal,
                                                       monthStart: range.lowerBound, today: lastDay))
        #expect(s.series.map { ($0.start, $0.netCents) }.elementsEqual(pulse.daily.map { ($0.date, $0.cents) }, by: ==))
        #expect(s.totals.incomeCents == pulse.earnedCents)
        #expect(s.totals.expenseCents == pulse.spentCents)
        #expect(s.totals.netCents == pulse.netCents)
    }

    @Test("a year report's month buckets equal AnalyticsSeries.horizon on the overlapping months")
    func yearEqualsHorizon() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let cal = Calendar.current
        let all = try f.allTransactions()
        let categories = try f.container.mainContext.fetch(FetchDescriptor<FinanceTracker.Category>())
        let period = ReportPeriod.year(containing: f.now)
        let input = LedgerAggregator.makeReportInput(transactions: all, categories: categories, period: period,
                                                     calendar: cal, bundle: .main)
        let year = try #require(ReportBuilder.build(input: input, period: period, calendar: cal, monthlyBudgetCents: 0))
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: f.now))!
        let horizon = try #require(AnalyticsSeries.horizon(transactions: all, calendar: cal, monthStart: monthStart))
        let horizonByMonth = Dictionary(uniqueKeysWithValues: horizon.map { ($0.monthStart, $0.incomeCents - $0.expenseCents) })
        var compared = 0
        for bucket in year.series {
            if let h = horizonByMonth[bucket.start] {
                #expect(bucket.netCents == h, "month \(bucket.start)")
                compared += 1
            }
        }
        #expect(compared >= 2, "the fixture's two months must both overlap the trailing-12 horizon")
    }

    @Test("a week report equals the month report's series filtered to the week's days")
    func weekEqualsMonthSlice() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let (month, _, all) = try makeReport(f)
        let cal = Calendar.current
        let weekPeriod = ReportPeriod.week(containing: f.now)
        let categories = try f.container.mainContext.fetch(FetchDescriptor<FinanceTracker.Category>())
        let input = LedgerAggregator.makeReportInput(transactions: all, categories: categories, period: weekPeriod,
                                                     calendar: cal, bundle: .main)
        let week = try #require(ReportBuilder.build(input: input, period: weekPeriod, calendar: cal, monthlyBudgetCents: 0))
        let weekRange = weekPeriod.range(calendar: cal)
        let sliced = month.series.filter { weekRange.contains($0.start) }
        // The week can straddle the month boundary; compare the overlapping days only.
        for day in week.series where sliced.contains(where: { $0.start == day.start }) {
            #expect(day.netCents == sliced.first { $0.start == day.start }?.netCents)
        }
        #expect(week.series.count == 7)
    }

    @Test("the comparison's previous figures equal MonthTotals over the previous month's rows")
    func previousEqualsMonthTotals() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let (s, _, all) = try makeReport(f)
        let cal = Calendar.current
        let prevRange = ReportPeriod.month(containing: f.now).previous(calendar: cal).range(calendar: cal)
        let prevTxs = all.filter { prevRange.contains($0.date) }
        let c = try #require(s.comparison)
        #expect(c.previous.expenseCents == MonthTotals.expenseCents(prevTxs))
        #expect(c.previous.incomeCents == MonthTotals.incomeCents(prevTxs))
    }

    @Test("splitting changes no report figure except the category table (the category-blind contract)")
    func splitsOnlyMoveCategories() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        let (sa, _, _) = try makeReport(a)
        let (sb, _, _) = try makeReport(b)
        #expect(sa.totals == sb.totals)
        #expect(sa.series.map(\.netCents) == sb.series.map(\.netCents))
        #expect(sa.largest.map(\.amountCents) == sb.largest.map(\.amountCents))
        #expect(sa.expenseCategories.map(\.cents) != sb.expenseCategories.map(\.cents))
    }
}
