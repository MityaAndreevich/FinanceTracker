//
//  AnalyticsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.locale) private var locale

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: PeriodScope = .currentMonth
    @State private var chartKind: ChartKind = .line

    enum ChartKind: String, CaseIterable, Identifiable {
        case pie
        case bars
        case line
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .pie: "analytics.chart.pie"
            case .bars: "analytics.chart.bars"
            case .line: "analytics.chart.line"
            }
        }
    }

    var body: some View {
        List {
            Section {
                PeriodSelector(scope: $scope)

                Picker(LocalizedStringKey("analytics.chart.picker.title"), selection: $chartKind) {
                    ForEach(ChartKind.allCases) { k in
                        Text(k.titleKey).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredTransactions.isEmpty {
                EmptyStateView(
                    systemImage: "chart.bar.xaxis",
                    title: "empty.noData",
                    message: "analytics.empty.message"
                )
                .listRowBackground(Color.clear)
            } else {
                combinedSection
                breakdownExpensesByCategorySection
                breakdownIncomeBySourceSection
            }
        }
        .navigationTitle(LocalizedStringKey("title.analytics"))
        .listStyle(.insetGrouped)
    }

    // MARK: - Combined

    @ViewBuilder
    private var combinedSection: some View {
        Section(LocalizedStringKey("analytics.section.combined.title")) {

            switch chartKind {
            case .bars:
                barsChart(values: seriesValues)
            case .line:
                lineChart(values: seriesValues)
            case .pie:
                pieChart(summary: periodSummary)
            }

            HStack {
                Text(LocalizedStringKey("analytics.label.income"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Money.format(cents: periodSummary.incomeCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.footnote)

            HStack {
                Text(LocalizedStringKey("analytics.label.expense"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Money.format(cents: periodSummary.expenseCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.footnote)

            HStack {
                Text(LocalizedStringKey("analytics.label.net"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Money.format(cents: periodSummary.netCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(periodSummary.netCents >= 0 ? .green : .red)
                    .monospacedDigit()
            }
            .font(.footnote)
        }
    }

    // MARK: - Bars

    private func barsChart(values: [SeriesValue]) -> some View {
        Chart(values) { v in
            BarMark(
                x: .value("analytics.axis.date", v.bucketDate),
                y: .value("analytics.axis.amount", v.amount)
            )
            .foregroundStyle(by: .value("analytics.axis.type", v.kind.legendName))
            .position(by: .value("analytics.axis.type", v.kind.legendName))
            .opacity(v.kind == .expense ? 0.55 : 1.0)
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel { Text(xAxisLabel(for: value.as(Date.self))) }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(position: .bottom)
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Line

    private func lineChart(values: [SeriesValue]) -> some View {
        Chart(values) { v in
            LineMark(
                x: .value("analytics.axis.date", v.bucketDate),
                y: .value("analytics.axis.amount", v.amount)
            )
            .foregroundStyle(by: .value("analytics.axis.type", v.kind.legendName))
            .interpolationMethod(.catmullRom)

            if shouldShowPoints {
                PointMark(
                    x: .value("analytics.axis.date", v.bucketDate),
                    y: .value("analytics.axis.amount", v.amount)
                )
                .foregroundStyle(by: .value("analytics.axis.type", v.kind.legendName))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(position: .bottom, values: xAxisTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel { Text(xAxisLabel(for: value.as(Date.self))) }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(position: .bottom)
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    private var shouldShowPoints: Bool { seriesBucketCount <= 8 }

    // MARK: - Pie

    private func pieChart(summary: PeriodSummary) -> some View {
        Chart(summary.pieSlices) { s in
            SectorMark(
                angle: .value("analytics.axis.value", s.value),
                innerRadius: .ratio(0.55),
                angularInset: 2
            )
            .foregroundStyle(by: .value("analytics.axis.type", s.name))
        }
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Breakdown Sections

    @ViewBuilder
    private var breakdownExpensesByCategorySection: some View {
        Section(LocalizedStringKey("analytics.section.expenses_by_category.title")) {
            if expenseByCategory.isEmpty {
                Text(LocalizedStringKey("analytics.empty.no_expenses"))
                    .foregroundStyle(.secondary)
            } else {
                Chart(expenseByCategory) { row in
                    BarMark(
                        x: .value("analytics.axis.amount", row.amount),
                        y: .value("analytics.axis.category", row.name)
                    )
                }
                .chartXAxis { AxisMarks(position: .bottom) }
                .frame(height: chartHeight(for: expenseByCategory.count))
                .padding(.vertical, 6)

                ForEach(expenseByCategory) { row in
                    HStack {
                        Text(LocalizedStringKey(row.name))
                        Spacer()
                        Text(Money.format(cents: row.amountCents, currencyCode: row.currency))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var breakdownIncomeBySourceSection: some View {
        Section(LocalizedStringKey("analytics.section.income_by_source.title")) {
            if incomeBySource.isEmpty {
                Text(LocalizedStringKey("analytics.empty.no_income"))
                    .foregroundStyle(.secondary)
            } else {
                Chart(incomeBySource) { row in
                    BarMark(
                        x: .value("analytics.axis.amount", row.amount),
                        y: .value("analytics.axis.source", row.name)
                    )
                }
                .chartXAxis { AxisMarks(position: .bottom) }
                .frame(height: chartHeight(for: incomeBySource.count))
                .padding(.vertical, 6)

                ForEach(incomeBySource) { row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text(Money.format(cents: row.amountCents, currencyCode: row.currency))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.footnote)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredTransactions: [Transaction] {
        scope.filter(transactions)
    }

    // MARK: - Series

    private enum SeriesKind {
        case income
        case expense

        var legendName: String {
            switch self {
            case .income: return String(localized: "analytics.legend.income")
            case .expense: return String(localized: "analytics.legend.expense")
            }
        }
    }

    private var seriesValues: [SeriesValue] {
        let list = filteredTransactions
        let cal = Calendar.current
        let currency = defaultCurrencyCode

        let bucket: (Date) -> Date = { date in
            switch scope {
            case .month:
                return cal.startOfDay(for: date)
            case .all:
                let comps = cal.dateComponents([.year, .month], from: date)
                return cal.date(from: comps) ?? cal.startOfDay(for: date)
            }
        }

        var dict: [Date: (income: Int, expense: Int)] = [:]
        for tx in list {
            let key = bucket(tx.date)
            var cur = dict[key] ?? (0, 0)
            if tx.isIncome { cur.income += tx.amountCents }
            else { cur.expense += tx.amountCents }
            dict[key] = cur
        }

        let keysSorted = dict.keys.sorted()
        guard let first = keysSorted.first, let last = keysSorted.last else { return [] }

        let allBuckets: [Date] = {
            switch scope {
            case .month: return fillDays(from: first, to: last)
            case .all: return fillMonths(from: first, to: last)
            }
        }()

        var out: [SeriesValue] = []
        out.reserveCapacity(allBuckets.count * 2)

        for day in allBuckets {
            let v = dict[day] ?? (0, 0)
            out.append(.init(bucketDate: day, kind: .income, amount: Double(v.income) / 100.0, currency: currency))
            out.append(.init(bucketDate: day, kind: .expense, amount: Double(v.expense) / 100.0, currency: currency))
        }

        return out
    }

    private var seriesBucketCount: Int {
        seriesValues.filter { $0.kind == .income }.count
    }

    // MARK: - Period summary

    private var periodSummary: PeriodSummary {
        let list = filteredTransactions
        let currency = defaultCurrencyCode

        var income = 0
        var expense = 0
        for tx in list {
            if tx.isIncome { income += tx.amountCents }
            else { expense += tx.amountCents }
        }

        return PeriodSummary(incomeCents: income, expenseCents: expense, currency: currency)
    }

    // MARK: - X axis

    private var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let dates = seriesValues.map(\.bucketDate)
        guard let minD = dates.min(), let maxD = dates.max() else {
            let now = Date()
            return now...now
        }

        switch scope {
        case .month:
            let start = cal.date(byAdding: .day, value: -1, to: minD) ?? minD
            let end = cal.date(byAdding: .day, value: 1, to: maxD) ?? maxD
            return start...end
        case .all:
            let start = cal.date(byAdding: .month, value: -1, to: minD) ?? minD
            let end = cal.date(byAdding: .month, value: 1, to: maxD) ?? maxD
            return start...end
        }
    }

    private var xAxisTicks: [Date] {
        let cal = Calendar.current
        let dates = seriesValues.map(\.bucketDate)
        guard let minD = dates.min(), let maxD = dates.max() else { return [] }

        switch scope {
        case .month:
            var ticks: [Date] = []
            var cur = minD
            while cur <= maxD {
                ticks.append(cur)
                cur = cal.date(byAdding: .day, value: 5, to: cur) ?? cur
                if ticks.count > 20 { break }
            }
            return ticks

        case .all:
            var ticks: [Date] = []
            var cur = minD
            while cur <= maxD {
                ticks.append(cur)
                cur = cal.date(byAdding: .month, value: 2, to: cur) ?? cur
                if ticks.count > 20 { break }
            }
            return ticks
        }
    }

    private func xAxisLabel(for date: Date?) -> String {
        guard let date else { return "" }
        let df = DateFormatter()
        df.locale = locale

        switch scope {
        case .month: df.dateFormat = "d MMM"
        case .all: df.dateFormat = "MMM yy"
        }
        return df.string(from: date)
    }

    // MARK: - Breakdown Data

    private var expenseByCategory: [ChartRow] {
        let list = filteredTransactions.filter { $0.isExpense }
        let currency = defaultCurrencyCode

        struct Acc {
            var nameKeyOrName: String
            var cents: Int
        }

        var sums: [UUID: Acc] = [:]

        for tx in list {
            let cat = tx.category
            let id = cat.uuid
            let display = cat.displayKeyOrName

            var cur = sums[id] ?? Acc(nameKeyOrName: display, cents: 0)
            cur.cents += tx.amountCents
            cur.nameKeyOrName = display
            sums[id] = cur
        }

        return sums
            .map { (id, acc) in
                ChartRow(
                    id: id.uuidString,
                    name: acc.nameKeyOrName,
                    amount: Double(acc.cents) / 100.0,
                    amountCents: acc.cents,
                    currency: currency
                )
            }
            .sorted { $0.amountCents > $1.amountCents }
    }

    private var incomeBySource: [ChartRow] {
        let list = filteredTransactions.filter { $0.isIncome }
        let currency = defaultCurrencyCode

        var sums: [String: Int] = [:]
        for tx in list {
            let name = tx.source?.name ?? String(localized: "common.unknown")
            sums[name, default: 0] += tx.amountCents
        }

        return sums
            .map { (name, cents) in
                ChartRow(
                    id: name,
                    name: name,
                    amount: Double(cents) / 100.0,
                    amountCents: cents,
                    currency: currency
                )
            }
            .sorted { $0.amountCents > $1.amountCents }
    }

    // MARK: - Models

    private struct ChartRow: Identifiable {
        let id: String
        let name: String
        let amount: Double
        let amountCents: Int
        let currency: String
    }

    private struct SeriesValue: Identifiable {
        let id: String
        let bucketDate: Date
        let kind: SeriesKind
        let amount: Double
        let currency: String

        init(bucketDate: Date, kind: SeriesKind, amount: Double, currency: String) {
            self.bucketDate = bucketDate
            self.kind = kind
            self.amount = amount
            self.currency = currency
            self.id = "\(bucketDate.timeIntervalSinceReferenceDate)-\(kind.legendName)"
        }
    }

    private struct PeriodSummary {
        let incomeCents: Int
        let expenseCents: Int
        let currency: String
        var netCents: Int { incomeCents - expenseCents }

        struct PieSlice: Identifiable {
            let id: String
            let name: String
            let value: Double
        }

        var pieSlices: [PieSlice] {
            let income = Double(max(incomeCents, 0)) / 100.0
            let expense = Double(max(expenseCents, 0)) / 100.0

            return [
                .init(id: "income", name: String(localized: "analytics.legend.income"), value: max(income, 0.01)),
                .init(id: "expense", name: String(localized: "analytics.legend.expense"), value: max(expense, 0.01))
            ]
        }
    }

    // MARK: - Fill buckets

    private func fillDays(from start: Date, to end: Date) -> [Date] {
        let cal = Calendar.current
        var out: [Date] = []
        var cur = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)

        while cur <= last {
            out.append(cur)
            cur = cal.date(byAdding: .day, value: 1, to: cur) ?? cur
            if out.count > 400 { break }
        }
        return out
    }

    private func fillMonths(from start: Date, to end: Date) -> [Date] {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.year, .month], from: start)
        let endComps = cal.dateComponents([.year, .month], from: end)

        guard let s = cal.date(from: startComps), let e = cal.date(from: endComps) else { return [] }

        var out: [Date] = []
        var cur = s

        while cur <= e {
            out.append(cur)
            cur = cal.date(byAdding: .month, value: 1, to: cur) ?? cur
            if out.count > 200 { break }
        }
        return out
    }

    // MARK: - Helpers

    private func chartHeight(for rows: Int) -> CGFloat {
        let base: CGFloat = 160
        let extraPerRow: CGFloat = 24
        return max(base, CGFloat(rows) * extraPerRow)
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
