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

    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    private var totalIncomeCents: Int {
        currentMonthTransactions
            .filter { $0.typeRaw == "income" }
            .map { $0.amountCents }
            .reduce(0, +)
    }

    private var totalExpenseCents: Int {
        currentMonthTransactions
            .filter { $0.typeRaw == "expense" }
            .map { $0.amountCents }
            .reduce(0, +)
    }

    private var netCents: Int {
        totalIncomeCents - totalExpenseCents
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard(
                    title: "Income",
                    cents: totalIncomeCents,
                    color: .green
                )

                summaryCard(
                    title: "Expenses",
                    cents: totalExpenseCents,
                    color: .red
                )

                summaryCard(
                    title: "Net",
                    cents: netCents,
                    color: netCents >= 0 ? .green : .red
                )
            }
            .padding()
        }
        .navigationTitle("title.dashboard")
    }

    // MARK: - UI helpers

    private func summaryCard(title: String, cents: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatMoney(cents: cents))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatMoney(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
