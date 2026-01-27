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
    @State private var chartKind: ChartKind = .bars

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

    // MARK: - Main Combined Section (Income + Expense + Net)

    @ViewBuilder
    private var combinedSection: some View {
        Section("Income • Expense • Net") {
            switch chartKind {
            case .bars:
                barsChart(points: seriesPoints)

            case .line:
                lineChart(points: seriesPoints)

            case .pie:
                pieChart(summary: periodSummary)
            }

            // маленькая “легенда” внизу (нативно и понятно)
            HStack {
                legendDot("Income")
                Spacer()
                Text(formatCents(periodSummary.incomeCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            HStack {
                legendDot("Expense")
                Spacer()
                Text(formatCents(periodSummary.expenseCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            HStack {
                legendDot("Net")
                Spacer()
                Text(formatCents(periodSummary.netCents, currencyCode: periodSummary.currency))
                    .foregroundStyle(periodSummary.netCents >= 0 ? .green : .red)
            }
            .font(.footnote)
        }
    }

    private func legendDot(_ title: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .frame(width: 10, height: 10)
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bars

    private func barsChart(points: [SeriesPoint]) -> some View {
        Chart {
            ForEach(points) { p in
                BarMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Income", p.incomeAmount)
                )
                .position(by: .value("Series", "Income"))

                BarMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Expense", p.expenseAmount)
                )
                .position(by: .value("Series", "Expense"))

                BarMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Net", p.netAmount)
                )
                .position(by: .value("Series", "Net"))
            }
        }
        .chartXAxis { AxisMarks(position: .bottom) }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Line

    private func lineChart(points: [SeriesPoint]) -> some View {
        Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Income", p.incomeAmount)
                )
                .foregroundStyle(by: .value("Series", "Income"))

                LineMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Expense", p.expenseAmount)
                )
                .foregroundStyle(by: .value("Series", "Expense"))

                LineMark(
                    x: .value("Date", p.bucketDate),
                    y: .value("Net", p.netAmount)
                )
                .foregroundStyle(by: .value("Series", "Net"))
            }
        }
        .chartXAxis { AxisMarks(position: .bottom) }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 260)
        .padding(.vertical, 6)
    }

    // MARK: - Pie

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

    // MARK: - Breakdown Sections (your old ones, but made stable)

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

    // MARK: - Combined Series Data

    private var seriesPoints: [SeriesPoint] {
        let list = filteredTransactions

        // Выбор “шага”:
        // - This month -> по дням
        // - All -> по месяцам
        let cal = Calendar.current
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
            if tx.typeRaw == "income" {
                cur.income += tx.amountCents
            } else {
                cur.expense += tx.amountCents
            }
            dict[key] = cur
        }

        let currency = list.first?.currency ?? "USD"

        return dict.keys.sorted().map { day in
            let v = dict[day] ?? (0, 0)
            return SeriesPoint(
                bucketDate: day,
                incomeCents: v.income,
                expenseCents: v.expense,
                currency: currency
            )
        }
    }

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
                ChartRow(
                    name: name,
                    amount: Double(cents) / 100.0,
                    amountCents: cents,
                    currency: currency
                )
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
                ChartRow(
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

        init(name: String, amount: Double, amountCents: Int, currency: String) {
            self.id = name
            self.name = name
            self.amount = amount
            self.amountCents = amountCents
            self.currency = currency
        }
    }

    private struct SeriesPoint: Identifiable {
        let id: Date
        let bucketDate: Date
        let incomeCents: Int
        let expenseCents: Int
        let currency: String

        init(bucketDate: Date, incomeCents: Int, expenseCents: Int, currency: String) {
            self.id = bucketDate
            self.bucketDate = bucketDate
            self.incomeCents = incomeCents
            self.expenseCents = expenseCents
            self.currency = currency
        }

        var incomeAmount: Double { Double(incomeCents) / 100.0 }
        var expenseAmount: Double { Double(expenseCents) / 100.0 }
        var netAmount: Double { Double(incomeCents - expenseCents) / 100.0 }
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

        // Pie не любит отрицательные значения — делаем аккуратно
        var pieSlices: [PieSlice] {
            let income = Double(max(incomeCents, 0)) / 100.0
            let expense = Double(max(expenseCents, 0)) / 100.0

            let net = incomeCents - expenseCents
            let netAbs = Double(abs(net)) / 100.0

            var slices: [PieSlice] = []
            slices.append(.init(id: "Income", name: "Income", value: max(income, 0.01)))
            slices.append(.init(id: "Expense", name: "Expense", value: max(expense, 0.01)))

            if net != 0 {
                slices.append(.init(
                    id: net > 0 ? "Savings" : "Deficit",
                    name: net > 0 ? "Savings" : "Deficit",
                    value: max(netAbs, 0.01)
                ))
            }

            return slices
        }
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
