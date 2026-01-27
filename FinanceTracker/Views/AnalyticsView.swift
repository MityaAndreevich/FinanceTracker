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

    enum Scope: String, CaseIterable, Identifiable {
        case month = "This month"
        case all = "All"
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
                }

                if filteredTransactions.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No data yet",
                        message: "Add transactions to see analytics."
                    )
                    .listRowBackground(Color.clear)

                } else {

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
            }
            .navigationTitle("Analytics")
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Computed data (вынесли из List, чтобы компилятор не умирал)

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
        let id = UUID()
        let name: String
        let amount: Double
        let amountCents: Int
        let currency: String
    }

    // MARK: - Helpers

    private func chartHeight(for rows: Int) -> CGFloat {
        let base: CGFloat = 160
        let extraPerRow: CGFloat = 24
        return max(base, CGFloat(rows) * extraPerRow)
    }

    // Локальный форматтер, чтобы не зависеть от MoneyFormatter из другого файла
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
