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
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: Scope = .month
    @State private var chartKind: ChartKind = .line

    enum Scope: String, CaseIterable, Identifiable {
        case month = "This month"
        case all = "All"
        var id: String { rawValue }
    }

    enum ChartKind: String, CaseIterable, Identifiable {
        case pie = "Pie"
        case bars = "Bars"
        case line = "Line"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Chart", selection: $chartKind) {
                        ForEach(ChartKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredTransactions.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No data yet",
                        message: "Add transactions to see analytics."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    combinedSection
                    breakdownExpensesByCategorySection
                    breakdownIncomeBySourceSection
                }
            }
            .navigationTitle("Analytics")
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Combined (Income + Expense) | Net only as number

    @ViewBuilder
    private var combinedSection: some View {
        Section("Income • Expense") {

            switch chartKind {
            case .bars:
                barsChart(values: seriesValues)

            case .line:
                lineChart(values: seriesValues)

            case .pie:
                pieChart(summary: periodSummary)
            }

            // Summary rows (Net только текстом)
            HStack {
                Text("Income").foregroundStyle(.secondary)
                Spacer()
                Text(formatCents(periodSummary.incomeCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            HStack {
                Text("Expense").foregroundStyle(.secondary)
                Spacer()
                Text(formatCents(periodSummary.expenseCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            HStack {
                Text("Net").foregroundStyle(.secondary)
                Spacer()
                Text(formatCents(periodSummary.netCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(periodSummary.netCents >= 0 ? .green : .red)
            }
            .font(.footnote)
        }
    }

    // MARK: - Bars (Income vs Expense only)

    private func barsChart(values: [SeriesValue]) -> some View {
        Chart(values) { v in
            BarMark(
                x: .value("Date", v.bucketDate),
                y: .value("Amount", v.amount)
            )
            .foregroundStyle(by: .value("Type", v.kind.rawValue))
            .position(by: .value("Type", v.kind.rawValue)) // рядом, НЕ stacked
            .opacity(v.kind == .expense ? 0.55 : 1.0)
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text(xAxisLabel(for: value.as(Date.self)))
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(position: .bottom)
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Line (Bank-style: smooth timeline, no “single nail”)

    private func lineChart(values: [SeriesValue]) -> some View {
        Chart(values) { v in
            LineMark(
                x: .value("Date", v.bucketDate),
                y: .value("Amount", v.amount)
            )
            .foregroundStyle(by: .value("Type", v.kind.rawValue))
            .interpolationMethod(.catmullRom)

            // точки оставляем, но маленькие и только когда мало данных
            if shouldShowPoints {
                PointMark(
                    x: .value("Date", v.bucketDate),
                    y: .value("Amount", v.amount)
                )
                .foregroundStyle(by: .value("Type", v.kind.rawValue))
            }
        }
        .chartXScale(domain: xDomain) // вот это и делает “банковскую” ось
        .chartXAxis {
            AxisMarks(position: .bottom, values: xAxisTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text(xAxisLabel(for: value.as(Date.self)))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartLegend(position: .bottom)
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    private var shouldShowPoints: Bool {
        // когда очень мало бакетов — точки помогают
        seriesBucketCount <= 8
    }

    // MARK: - Pie (Income vs Expense only)

    private func pieChart(summary: PeriodSummary) -> some View {
        let slices = summary.pieSlices

        return Chart(slices) { s in
            SectorMark(
                angle: .value("Value", s.value),
                innerRadius: .ratio(0.55),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Type", s.name))
        }
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Breakdown Sections

    @ViewBuilder
    private var breakdownExpensesByCategorySection: some View {
        Section("Expenses by Category") {
            if expenseByCategory.isEmpty {
                Text("No expenses in this period.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(expenseByCategory) { row in
                    BarMark(
                        x: .value("Amount", row.amount),
                        y: .value("Category", row.name)
                    )
                }
                .chartXAxis { AxisMarks(position: .bottom) }
                .frame(height: chartHeight(for: expenseByCategory.count))
                .padding(.vertical, 6)

                ForEach(expenseByCategory) { row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text(formatCents(row.amountCents, currencyCode: row.currency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var breakdownIncomeBySourceSection: some View {
        Section("Income by Source") {
            if incomeBySource.isEmpty {
                Text("No income in this period.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(incomeBySource) { row in
                    BarMark(
                        x: .value("Amount", row.amount),
                        y: .value("Source", row.name)
                    )
                }
                .chartXAxis { AxisMarks(position: .bottom) }
                .frame(height: chartHeight(for: incomeBySource.count))
                .padding(.vertical, 6)

                ForEach(incomeBySource) { row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text(formatCents(row.amountCents, currencyCode: row.currency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredTransactions: [Transaction] {
        switch scope {
        case .all:
            return transactions
        case .month:
            let cal = Calendar.current
            let now = Date()
            return transactions.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        }
    }

    // MARK: - Series (Income/Expense with “filled” timeline buckets)

    private enum SeriesKind: String {
        case income = "Income"
        case expense = "Expense"
    }

    private var seriesValues: [SeriesValue] {
        let list = filteredTransactions
        let cal = Calendar.current
        let currency = list.first?.currency ?? "USD"

        // агрегируем реальные суммы по бакетам
        let bucket: (Date) -> Date = {
            switch scope {
            case .month:
                return cal.startOfDay(for: $0)
            case .all:
                let comps = cal.dateComponents([.year, .month], from: $0)
                return cal.date(from: comps) ?? cal.startOfDay(for: $0)
            }
        }

        var dict: [Date: (income: Int, expense: Int)] = [:]
        for tx in list {
            let key = bucket(tx.date)
            var cur = dict[key] ?? (0, 0)
            if tx.typeRaw == "income" { cur.income += tx.amountCents }
            else { cur.expense += tx.amountCents }
            dict[key] = cur
        }

        // “банк-вид”: добавляем пустые бакеты от min до max (иначе один столбик/точка)
        let keysSorted = dict.keys.sorted()
        guard let first = keysSorted.first, let last = keysSorted.last else { return [] }

        let allBuckets: [Date] = {
            switch scope {
            case .month:
                return fillDays(from: first, to: last)
            case .all:
                return fillMonths(from: first, to: last)
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
        // считаем бакеты по income (у нас их ровно столько же сколько expense)
        seriesValues.filter { $0.kind == .income }.count
    }

    // MARK: - Period summary

    private var periodSummary: PeriodSummary {
        let list = filteredTransactions
        let currency = list.first?.currency ?? "USD"

        var income = 0
        var expense = 0
        for tx in list {
            if tx.typeRaw == "income" { income += tx.amountCents }
            else { expense += tx.amountCents }
        }

        return PeriodSummary(incomeCents: income, expenseCents: expense, currency: currency)
    }

    // MARK: - X axis (domain + ticks + labels)

    private var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let dates = seriesValues.map(\.bucketDate)
        guard let minD = dates.min(), let maxD = dates.max() else {
            let now = Date()
            return now...now
        }

        switch scope {
        case .month:
            // чуть расширим края, чтобы не “прилипало”
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
        // не рисуем 31 подпись — делаем “умную” разметку
        let cal = Calendar.current
        let dates = seriesValues.map(\.bucketDate)
        guard let minD = dates.min(), let maxD = dates.max() else { return [] }

        switch scope {
        case .month:
            // метка раз в 5 дней
            var ticks: [Date] = []
            var cur = minD
            while cur <= maxD {
                ticks.append(cur)
                cur = cal.date(byAdding: .day, value: 5, to: cur) ?? cur
                if ticks.count > 20 { break }
            }
            return ticks

        case .all:
            // метка раз в 2 месяца
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
        df.locale = .current

        switch scope {
        case .month:
            df.dateFormat = "d MMM" // 26 Jan
        case .all:
            df.dateFormat = "MMM yy" // Jan 26
        }
        return df.string(from: date)
    }

    // MARK: - Breakdown Data

    private var expenseByCategory: [ChartRow] {
        let list = filteredTransactions.filter { $0.typeRaw == "expense" }
        guard let currency = list.first?.currency else { return [] }

        var sums: [String: Int] = [:]
        for tx in list {
            sums[tx.category.name, default: 0] += tx.amountCents
        }

        return sums
            .map { (name, cents) in
                ChartRow(name: name, amount: Double(cents) / 100.0, amountCents: cents, currency: currency)
            }
            .sorted { $0.amountCents > $1.amountCents }
    }

    private var incomeBySource: [ChartRow] {
        let list = filteredTransactions.filter { $0.typeRaw == "income" }
        guard let currency = list.first?.currency else { return [] }

        var sums: [String: Int] = [:]
        for tx in list {
            let name = tx.source?.name ?? "Unknown"
            sums[name, default: 0] += tx.amountCents
        }

        return sums
            .map { (name, cents) in
                ChartRow(name: name, amount: Double(cents) / 100.0, amountCents: cents, currency: currency)
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

        init(name: String, amount: Double, amountCents: Int, currency: String) {
            self.id = name
            self.name = name
            self.amount = amount
            self.amountCents = amountCents
            self.currency = currency
        }
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
            self.id = "\(bucketDate.timeIntervalSinceReferenceDate)-\(kind.rawValue)"
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

            // чтобы pie не исчезал при нуле
            return [
                .init(id: "Income", name: "Income", value: max(income, 0.01)),
                .init(id: "Expense", name: "Expense", value: max(expense, 0.01))
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

        guard
            let s = cal.date(from: startComps),
            let e = cal.date(from: endComps)
        else { return [] }

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

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    private func formatCents(_ cents: Int, currencyCode: String) -> String {
        let amount = Decimal(cents) / 100
        Self.formatter.currencyCode = currencyCode
        return Self.formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
