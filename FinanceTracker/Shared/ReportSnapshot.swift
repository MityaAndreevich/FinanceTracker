//
//  ReportSnapshot.swift
//  FinanceTracker
//
//  A report is a VALUE: every figure the Reports screen, the report PDF and
//  the report TSV show comes from one `ReportSnapshot`, built by one pure
//  function over DTO rows. Design: outputs/DESIGN_REPORTS_1_0_6.md §5.
//
//  EQUALITY BY CONSTRUCTION. The builder does not sum anything itself. Income
//  and expense are `MonthTotals`-shaped sums via `AnalyticsSeries.pulse`; the
//  category table is `CategoryBreakdown.buckets`; the series is
//  `AnalyticsSeries.pulse(...).daily` or `.months`. Those are the functions the
//  Dashboard and Analytics call for the same period, so a report cannot show a
//  different number — and `ReportEqualityCanaryTests` checks that it does not,
//  because "by construction" is an argument and a test is evidence.
//
//  UNAVAILABLE. `build` returns nil when any sum cannot be represented (D5).
//  The Optional idiom follows MonthTotals / SafeToSpend / CategoryLimitPolicy;
//  callers show the unavailable card, never a number.
//

import Foundation

// MARK: - Input (Sendable DTOs — no PersistentModel crosses the actor boundary)

struct ReportInput: Equatable, Sendable {

    /// One parent transaction inside the period.
    struct Parent: Equatable, Sendable {
        let uuid: UUID
        let date: Date
        let amountCents: Int
        let isIncome: Bool
        let merchant: String?
        /// The parent's own category (for the "largest" list); attribution for
        /// the category table goes through `rows`.
        let categoryLabel: ReportSnapshot.CategoryLabel
    }

    /// Parents in the period.
    let parents: [Parent]
    /// `CategoryAttribution.rows(for:)` of every parent in the period.
    let rows: [CategoryAttribution.Row]
    /// Labels for every category UUID that appears in `rows` (and the nil
    /// bucket's label under `CategoryAttribution.uncategorizedBucketID`).
    let labels: [UUID: ReportSnapshot.CategoryLabel]
    /// Parents in the PREVIOUS period, as SafeToSpend entries — the comparison
    /// needs only totals.
    let previousEntries: [SafeToSpend.Entry]
    /// Categories carrying a monthly limit (month reports only use it).
    let limitedCategories: [ReportSnapshot.LimitedCategory]

    static let empty = ReportInput(parents: [], rows: [], labels: [:], previousEntries: [], limitedCategories: [])
}

// MARK: - Output

struct ReportSnapshot: Equatable, Sendable {

    /// Enough to draw a category without the model: name resolved on the
    /// actor with the in-app bundle, symbol, and the theme key for its colour.
    struct CategoryLabel: Equatable, Hashable, Sendable {
        let name: String
        let symbol: String
        let themeKey: String?
    }

    struct LimitedCategory: Equatable, Sendable {
        let uuid: UUID
        let displayName: String
        let limitCents: Int
    }

    struct Totals: Equatable, Sendable {
        let incomeCents: Int
        let expenseCents: Int
        let netCents: Int
    }

    /// Period-over-period. `percent` is nil when the previous figure is 0 —
    /// not 0%, not ∞ — and the whole comparison is nil when the previous period
    /// could not be summed.
    struct Delta: Equatable, Sendable {
        let cents: Int
        let percent: Double?
    }

    struct Comparison: Equatable, Sendable {
        let previous: Totals
        let income: Delta
        let expense: Delta
        let net: Delta
    }

    struct BudgetLine: Equatable, Sendable {
        let budgetCents: Int
        let spentCents: Int
        let remainingCents: Int
        let limits: [CategoryLimitPolicy.Status]
        var overLimitCount: Int { limits.filter { $0.remainingCents < 0 }.count }
    }

    struct CategoryShare: Equatable, Sendable, Identifiable {
        var id: UUID { bucketID }
        let bucketID: UUID
        let label: CategoryLabel
        let cents: Int
        let isIncome: Bool
        /// cents / direction total, 0...1; 0 when the total is 0.
        let share: Double
    }

    enum SeriesGranularity: Equatable, Sendable { case day, month }

    struct BucketNet: Equatable, Sendable, Identifiable {
        var id: Date { start }
        let start: Date
        let netCents: Int
    }

    struct LargestRow: Equatable, Sendable, Identifiable {
        var id: UUID { uuid }
        let uuid: UUID
        let date: Date
        let title: String
        let amountCents: Int
    }

    let period: ReportPeriod
    let totals: Totals
    let transactionCount: Int
    let comparison: Comparison?
    let budget: BudgetLine?
    /// Expense categories, sorted by cents descending. The "Other" fold is a
    /// presentation choice made by the view/PDF with `CategoryBreakdown.fold`.
    let expenseCategories: [CategoryShare]
    let seriesGranularity: SeriesGranularity
    let series: [BucketNet]
    let largest: [LargestRow]

    /// Custom periods longer than this many days are bucketed by month.
    static let dailySeriesMaxDays = 62
    static let largestCount = 5
}

// MARK: - Builder

enum ReportBuilder {

    /// Nil = unavailable (a sum overflowed). Pure; runs on any executor.
    static func build(
        input: ReportInput,
        period: ReportPeriod,
        calendar: Calendar,
        monthlyBudgetCents: Int
    ) -> ReportSnapshot? {
        let range = period.range(calendar: calendar)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: range.upperBound) ?? range.lowerBound
        let entries = input.parents.map { SafeToSpend.Entry(amountCents: $0.amountCents, date: $0.date, isIncome: $0.isIncome) }

        // Totals and the daily series — the Analytics Pulse accumulation.
        guard let pulse = AnalyticsSeries.pulse(entries: entries, calendar: calendar,
                                                monthStart: range.lowerBound, today: lastDay),
              let net = pulse.netCents
        else { return nil }
        let totals = ReportSnapshot.Totals(incomeCents: pulse.earnedCents, expenseCents: pulse.spentCents, netCents: net)

        // Previous period — nil comparison when IT cannot be summed; the report
        // itself is still available.
        let prevPeriod = period.previous(calendar: calendar)
        let prevRange = prevPeriod.range(calendar: calendar)
        let prevLast = calendar.date(byAdding: .day, value: -1, to: prevRange.upperBound) ?? prevRange.lowerBound
        var comparison: ReportSnapshot.Comparison?
        if let prev = AnalyticsSeries.pulse(entries: input.previousEntries, calendar: calendar,
                                            monthStart: prevRange.lowerBound, today: prevLast),
           let prevNet = prev.netCents,
           let dIncome = delta(now: totals.incomeCents, previous: prev.earnedCents),
           let dExpense = delta(now: totals.expenseCents, previous: prev.spentCents),
           let dNet = delta(now: net, previous: prevNet) {
            comparison = ReportSnapshot.Comparison(
                previous: .init(incomeCents: prev.earnedCents, expenseCents: prev.spentCents, netCents: prevNet),
                income: dIncome, expense: dExpense, net: dNet
            )
        }

        // Category table — the one fold.
        guard let buckets = CategoryBreakdown.buckets(rows: input.rows, includeIncome: false),
              let expenseTotal = CategoryBreakdown.total(buckets, cents: \.cents)
        else { return nil }
        let uncategorized = ReportSnapshot.CategoryLabel(name: "", symbol: "tray", themeKey: nil)
        let categories = buckets
            .map { b in
                ReportSnapshot.CategoryShare(
                    bucketID: b.id,
                    label: input.labels[b.id] ?? uncategorized,
                    cents: b.cents,
                    isIncome: b.isIncome,
                    share: expenseTotal > 0 ? Double(b.cents) / Double(expenseTotal) : 0
                )
            }
            .sorted { $0.cents != $1.cents ? $0.cents > $1.cents : $0.bucketID.uuidString < $1.bucketID.uuidString }

        // Budget line — month only, budget set.
        var budget: ReportSnapshot.BudgetLine?
        if case .month = period, monthlyBudgetCents > 0 {
            var statuses: [CategoryLimitPolicy.Status] = []
            if !input.limitedCategories.isEmpty {
                guard let spent = CategoryLimitPolicy.spentByCategory(
                    rows: input.rows, monthStart: range.lowerBound, today: lastDay, calendar: calendar
                ) else { return nil }
                statuses = input.limitedCategories.map {
                    CategoryLimitPolicy.Status(categoryUUID: $0.uuid, displayName: $0.displayName,
                                               limitCents: $0.limitCents, spentCents: spent[$0.uuid] ?? 0)
                }
            }
            let (remaining, overflow) = monthlyBudgetCents.subtractingReportingOverflow(totals.expenseCents)
            guard !overflow else { return nil }
            budget = ReportSnapshot.BudgetLine(budgetCents: monthlyBudgetCents, spentCents: totals.expenseCents,
                                               remainingCents: remaining, limits: statuses)
        }

        // Series — daily for week/month/short custom, monthly for year/long custom.
        let granularity: ReportSnapshot.SeriesGranularity
        switch period {
        case .week, .month: granularity = .day
        case .year: granularity = .month
        case .custom: granularity = period.dayCount(calendar: calendar) <= ReportSnapshot.dailySeriesMaxDays ? .day : .month
        }
        let series: [ReportSnapshot.BucketNet]
        switch granularity {
        case .day:
            series = pulse.daily.map { .init(start: $0.date, netCents: $0.cents) }
        case .month:
            let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: range.lowerBound)) ?? range.lowerBound
            let lastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastDay)) ?? lastDay
            guard let months = AnalyticsSeries.months(entries: entries, calendar: calendar,
                                                      firstMonthStart: firstMonth, lastMonthStart: lastMonth)
            else { return nil }
            var out: [ReportSnapshot.BucketNet] = []
            for m in months {
                let (n, overflow) = m.incomeCents.subtractingReportingOverflow(m.expenseCents)
                guard !overflow else { return nil }
                out.append(.init(start: m.monthStart, netCents: n))
            }
            series = out
        }

        // Largest expenses.
        let largest = input.parents
            .filter { !$0.isIncome }
            .sorted { $0.amountCents != $1.amountCents ? $0.amountCents > $1.amountCents : $0.date > $1.date }
            .prefix(ReportSnapshot.largestCount)
            .map { p in
                ReportSnapshot.LargestRow(
                    uuid: p.uuid, date: p.date,
                    title: (p.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? p.categoryLabel.name,
                    amountCents: p.amountCents
                )
            }

        return ReportSnapshot(
            period: period, totals: totals, transactionCount: input.parents.count,
            comparison: comparison, budget: budget, expenseCategories: categories,
            seriesGranularity: granularity, series: series, largest: Array(largest)
        )
    }

    /// Signed change and, when the base is non-zero, the percentage.
    static func delta(now: Int, previous: Int) -> ReportSnapshot.Delta? {
        let (cents, overflow) = now.subtractingReportingOverflow(previous)
        guard !overflow else { return nil }
        let percent: Double? = previous == 0 ? nil : (Double(cents) / Double(abs(previous))) * 100
        return .init(cents: cents, percent: percent)
    }
}
