//
//  AnalyticsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    var body: some View {
        let expenseByCategory = monthlyExpenseByCategory()
        let incomeBySource = monthlyIncomeBySource()
        let netBySource = monthlyNetBySource()

        NavigationStack {
            List {
                // ===== Expenses =====
                Section("Top expense categories (this month)") {
                    if expenseByCategory.isEmpty {
                        Text("No expense data for this month yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(expenseByCategory.prefix(3), id: \.id) { row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .font(.headline)
                            }
                        }
                    }
                }

                Section("All expense categories") {
                    if expenseByCategory.isEmpty {
                        Text("—")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(expenseByCategory, id: \.id) { row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // ===== Income by source =====
                Section("Income by source (this month)") {
                    if incomeBySource.isEmpty {
                        Text("No income data for this month yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(incomeBySource, id: \.id) { row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .font(.headline)
                            }
                        }
                    }
                }

                // ===== Net by source =====
                Section("Net by source (this month)") {
                    if netBySource.isEmpty {
                        Text("No data for this month yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(netBySource, id: \.id) { row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .font(.headline)
                                    .foregroundStyle(row.totalCents >= 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("title.analytics")
        }
    }

    // MARK: - Data helpers

    private func currentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    private func monthlyExpenseByCategory() -> [SummaryRow] {
        let monthExpenses = transactions.filter { tx in
            tx.typeRaw == "expense" && currentMonth(tx.date)
        }

        var dict: [UUID: (name: String, total: Int)] = [:]

        for tx in monthExpenses {
            let id = tx.category.id
            let name = tx.category.name
            dict[id] = (name: name, total: (dict[id]?.total ?? 0) + tx.amountCents)
        }

        return dict.map { SummaryRow(id: $0.key, name: $0.value.name, totalCents: $0.value.total) }
            .sorted { $0.totalCents > $1.totalCents }
    }

    private func monthlyIncomeBySource() -> [SummaryRow] {
        let monthIncome = transactions.filter { tx in
            tx.typeRaw == "income" && currentMonth(tx.date)
        }

        // source может быть nil -> складываем в "Unassigned"
        var dict: [String: Int] = [:]

        for tx in monthIncome {
            let key = tx.source?.name ?? "Unassigned"
            dict[key] = (dict[key] ?? 0) + tx.amountCents
        }

        return dict.map { SummaryRow(id: UUID().uuidString, name: $0.key, totalCents: $0.value) }
            .sorted { $0.totalCents > $1.totalCents }
    }

    private func monthlyNetBySource() -> [SummaryRow] {
        let monthTx = transactions.filter { currentMonth($0.date) }

        // net по source: income +, expense -
        var dict: [String: Int] = [:]

        for tx in monthTx {
            let key = tx.source?.name ?? "Unassigned"
            let signed = (tx.typeRaw == "income") ? tx.amountCents : -tx.amountCents
            dict[key] = (dict[key] ?? 0) + signed
        }

        // Сортируем по абсолютной величине (самые “влияющие” источники сверху)
        return dict.map { SummaryRow(id: UUID().uuidString, name: $0.key, totalCents: $0.value) }
            .sorted { abs($0.totalCents) > abs($1.totalCents) }
    }

    // MARK: - Formatting

    private func formatMoney(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// Универсальная строка-резюме для списков аналитики
private struct SummaryRow {
    let id: AnyHashable
    let name: String
    let totalCents: Int
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
