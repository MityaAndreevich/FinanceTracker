//
//  ReportBuilderTests.swift
//  FinanceTrackerTests
//
//  DESIGN_REPORTS_1_0_6.md §10.1. Pure fixtures — no container. Every expected
//  figure is hand-summed in the test, never derived from production code.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("ReportBuilder")
struct ReportBuilderTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private static let food = UUID(), home = UUID(), salary = UUID()
    private static let labels: [UUID: ReportSnapshot.CategoryLabel] = [
        food: .init(name: "Food", symbol: "fork.knife", themeKey: "food"),
        home: .init(name: "Home", symbol: "house.fill", themeKey: "home"),
        salary: .init(name: "Salary", symbol: "banknote", themeKey: "salary"),
        CategoryAttribution.uncategorizedBucketID: .init(name: "Uncategorized", symbol: "tray", themeKey: nil),
    ]

    private func parent(_ cents: Int, _ date: Date, income: Bool = false, category: UUID? = ReportBuilderTests.food,
                        merchant: String? = nil) -> ReportInput.Parent {
        .init(uuid: UUID(), date: date, amountCents: cents, isIncome: income, merchant: merchant,
              categoryLabel: Self.labels[category ?? CategoryAttribution.uncategorizedBucketID]!)
    }

    private func row(_ p: ReportInput.Parent, cents: Int? = nil, category: UUID?) -> CategoryAttribution.Row {
        .init(amountCents: cents ?? p.amountCents, categoryUUID: category, date: p.date, isIncome: p.isIncome)
    }

    /// September 2026: 3 expenses (one split 3 000 → Home 2 000 / Food 1 000),
    /// 1 income; August: 1 expense, 1 income.
    private func septemberInput() -> ReportInput {
        let a = parent(3_000, date(2026, 9, 3), merchant: "Amazon")            // split
        let b = parent(700, date(2026, 9, 10), merchant: "Cafe")
        let c = parent(5_000, date(2026, 9, 25), category: Self.home, merchant: "Hardware")
        let pay = parent(250_000, date(2026, 9, 1), income: true, category: Self.salary)
        let rows = [row(a, cents: 2_000, category: Self.home), row(a, cents: 1_000, category: Self.food),
                    row(b, category: Self.food), row(c, category: Self.home), row(pay, category: Self.salary)]
        let previous = [SafeToSpend.Entry(amountCents: 20_000, date: date(2026, 8, 14), isIncome: false),
                        SafeToSpend.Entry(amountCents: 100_000, date: date(2026, 8, 1), isIncome: true)]
        return ReportInput(parents: [a, b, c, pay], rows: rows, labels: Self.labels,
                           previousEntries: previous,
                           limitedCategories: [.init(uuid: Self.food, displayName: "Food", limitCents: 1_500)])
    }

    @Test("month totals, count, and the category table with attribution")
    func monthFigures() throws {
        let s = try #require(ReportBuilder.build(input: septemberInput(), period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 10_000))
        #expect(s.totals == .init(incomeCents: 250_000, expenseCents: 8_700, netCents: 241_300))
        #expect(s.transactionCount == 4)
        // Home 2 000 + 5 000 = 7 000; Food 1 000 + 700 = 1 700. Σ == 8 700.
        #expect(s.expenseCategories.map { ($0.label.name, $0.cents) }.elementsEqual([("Home", 7_000), ("Food", 1_700)], by: ==))
        #expect(s.expenseCategories.allSatisfy { !$0.isIncome })
        #expect(abs(s.expenseCategories[0].share - 7_000.0 / 8_700.0) < 1e-12)
        #expect(s.seriesGranularity == .day)
        #expect(s.series.count == 30)
        #expect(s.series.map(\.netCents).reduce(0, +) == 241_300)
        #expect(s.series[0].netCents == 250_000)    // Sep 1: salary
        #expect(s.series[2].netCents == -3_000)     // Sep 3: the split parent, summed as a parent
        #expect(s.largest.map(\.title) == ["Hardware", "Amazon", "Cafe"])
        #expect(s.largest.map(\.amountCents) == [5_000, 3_000, 700])
    }

    @Test("comparison deltas: signed cents, percent nil on a zero base, sign on a decrease")
    func comparison() throws {
        let s = try #require(ReportBuilder.build(input: septemberInput(), period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 0))
        let c = try #require(s.comparison)
        #expect(c.previous == .init(incomeCents: 100_000, expenseCents: 20_000, netCents: 80_000))
        #expect(c.income.cents == 150_000)
        #expect(abs(try #require(c.income.percent) - 150) < 1e-9)
        #expect(c.expense.cents == -11_300)
        #expect(abs(try #require(c.expense.percent) - (-56.5)) < 1e-9)
        #expect(c.net.cents == 161_300)

        // Zero base → percent omitted, cents kept.
        #expect(ReportBuilder.delta(now: 500, previous: 0) == .init(cents: 500, percent: nil))
        #expect(ReportBuilder.delta(now: 0, previous: 0) == .init(cents: 0, percent: nil))
        // Overflow in the delta → nil, never a wrapped number.
        #expect(ReportBuilder.delta(now: Int.max, previous: -1) == nil)
    }

    @Test("an empty previous period yields a comparison against zeros, not nil")
    func emptyPrevious() throws {
        var input = septemberInput()
        input = ReportInput(parents: input.parents, rows: input.rows, labels: input.labels,
                            previousEntries: [], limitedCategories: [])
        let s = try #require(ReportBuilder.build(input: input, period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 0))
        #expect(s.comparison?.previous == .init(incomeCents: 0, expenseCents: 0, netCents: 0))
        #expect(s.comparison?.expense.percent == nil)
    }

    @Test("budget line only for a month with a budget; limits carry the attributed spend")
    func budgetLine() throws {
        let month = ReportPeriod.month(containing: date(2026, 9, 15))
        let with = try #require(ReportBuilder.build(input: septemberInput(), period: month, calendar: cal, monthlyBudgetCents: 10_000))
        let b = try #require(with.budget)
        #expect(b.budgetCents == 10_000)
        #expect(b.spentCents == 8_700)
        #expect(b.remainingCents == 1_300)
        #expect(b.limits.count == 1)
        #expect(b.limits[0].spentCents == 1_700)     // Food: 1 000 (split part) + 700
        #expect(b.overLimitCount == 1)               // 1 700 > 1 500

        let none = try #require(ReportBuilder.build(input: septemberInput(), period: month, calendar: cal, monthlyBudgetCents: 0))
        #expect(none.budget == nil)
        let week = try #require(ReportBuilder.build(input: septemberInput(), period: .week(containing: date(2026, 9, 10)),
                                                    calendar: cal, monthlyBudgetCents: 10_000))
        #expect(week.budget == nil, "a weekly budget does not exist in this app")
    }

    @Test("a week takes only its days; a year buckets by month; a long custom range by month")
    func granularity() throws {
        let week = try #require(ReportBuilder.build(input: septemberInput(), period: .week(containing: date(2026, 9, 10)),
                                                    calendar: cal, monthlyBudgetCents: 0))
        #expect(week.series.count == 7)
        #expect(week.totals.expenseCents == 700)     // only the Cafe row falls in Sep 7–13
        #expect(week.transactionCount == 4, "count is of the INPUT parents — the aggregator scopes the fetch")

        let year = try #require(ReportBuilder.build(input: septemberInput(), period: .year(containing: date(2026, 9, 10)),
                                                    calendar: cal, monthlyBudgetCents: 0))
        #expect(year.seriesGranularity == .month)
        #expect(year.series.count == 12)
        #expect(year.series[8].netCents == 241_300)  // September
        #expect(year.series[7].netCents == 0)        // August rows were handed in as previousEntries, not parents

        let short = ReportPeriod.custom(start: date(2026, 9, 1), end: date(2026, 9, 30))
        #expect(try #require(ReportBuilder.build(input: septemberInput(), period: short, calendar: cal, monthlyBudgetCents: 0)).seriesGranularity == .day)
        let long = ReportPeriod.custom(start: date(2026, 1, 1), end: date(2026, 9, 30))
        let l = try #require(ReportBuilder.build(input: septemberInput(), period: long, calendar: cal, monthlyBudgetCents: 0))
        #expect(l.seriesGranularity == .month)
        #expect(l.series.count == 9)
    }

    @Test("an empty period is zeros, not unavailable")
    func emptyPeriod() throws {
        let s = try #require(ReportBuilder.build(input: .empty, period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 0))
        #expect(s.totals == .init(incomeCents: 0, expenseCents: 0, netCents: 0))
        #expect(s.expenseCategories.isEmpty)
        #expect(s.largest.isEmpty)
        #expect(s.series.count == 30)
    }

    @Test("a poisoned ledger yields nil for every period kind — never a number",
          arguments: [ReportPeriod.Kind.week, .month, .year, .custom])
    func poisoned(kind: ReportPeriod.Kind) {
        let d = date(2026, 9, 10)
        let p1 = parent(Int.max - 8, d, merchant: "poisoned 0")
        let p2 = parent(Int.max - 8, date(2026, 9, 11), merchant: "poisoned 1")
        let input = ReportInput(parents: [p1, p2], rows: [row(p1, category: Self.food), row(p2, category: Self.food)],
                                labels: Self.labels, previousEntries: [], limitedCategories: [])
        let period: ReportPeriod
        switch kind {
        case .week: period = .week(containing: d)
        case .month: period = .month(containing: d)
        case .year: period = .year(containing: d)
        case .custom: period = .custom(start: date(2026, 9, 1), end: date(2026, 9, 30))
        }
        #expect(ReportBuilder.build(input: input, period: period, calendar: cal, monthlyBudgetCents: 10_000) == nil)
    }

    @Test("a poisoned PREVIOUS period drops the comparison but keeps the report")
    func poisonedPrevious() throws {
        var input = septemberInput()
        input = ReportInput(parents: input.parents, rows: input.rows, labels: input.labels,
                            previousEntries: [.init(amountCents: Int.max - 8, date: date(2026, 8, 3), isIncome: false),
                                              .init(amountCents: Int.max - 8, date: date(2026, 8, 4), isIncome: false)],
                            limitedCategories: [])
        let s = try #require(ReportBuilder.build(input: input, period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 0))
        #expect(s.comparison == nil)
        #expect(s.totals.expenseCents == 8_700)
    }
}
