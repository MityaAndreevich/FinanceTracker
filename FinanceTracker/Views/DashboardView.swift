//
//  DashboardView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    var body: some View {
        let monthTx = transactionsThisMonth()
        let incomeCents = monthTx
            .filter { $0.typeRaw == "income" }
            .reduce(0) { $0 + $1.amountCents }

        let expenseCents = monthTx
            .filter { $0.typeRaw == "expense" }
            .reduce(0) { $0 + $1.amountCents }

        let netCents = incomeCents - expenseCents

        NavigationStack {
            if monthTx.isEmpty {
                // ✅ Empty state when there is no data
                EmptyStateView(
                    systemImage: "creditcard",
                    title: "No data yet",
                    message: "Add your first income or expense to see your monthly summary here."
                )
                .navigationTitle("title.dashboard")
            } else {
                List {
                    Section("This month") {
                        SummaryRow(title: "Income", value: formatMoney(cents: incomeCents), valueColor: .green)
                        SummaryRow(title: "Expenses", value: formatMoney(cents: expenseCents), valueColor: .red)
                        SummaryRow(title: "Net", value: formatMoney(cents: netCents), valueColor: netCents >= 0 ? .green : .red)
                    }

                    // Можно позже добавить Top categories / Top sources
                }
                .listStyle(.insetGrouped)
                .navigationTitle("title.dashboard")
            }
        }
    }

    // MARK: - Helpers

    private func transactionsThisMonth() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    private func formatMoney(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// MARK: - Small UI component

private struct SummaryRow: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
