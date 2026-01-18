//
//  TransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: Scope = .month

    enum Scope: String, CaseIterable, Identifiable {
        case month = "This month"
        case all = "All"
        var id: String { rawValue }
    }

    var body: some View {
        let filtered = filteredTransactions()

        List {
            if filtered.isEmpty {
                Text("No transactions yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { tx in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tx.merchant ?? tx.category.name)
                                .font(.headline)

                            Text(tx.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formatMoney(cents: tx.amountCents, currency: tx.currency))
                            .font(.headline)
                            .foregroundStyle(tx.typeRaw == "income" ? .green : .red)
                    }
                }
                .onDelete(perform: deleteTransactions)
            }
        }
        .navigationTitle("title.transactions")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Filtering

    private func filteredTransactions() -> [Transaction] {
        switch scope {
        case .all:
            return transactions
        case .month:
            let calendar = Calendar.current
            let now = Date()
            return transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        }
    }

    // MARK: - Actions

    @Environment(\.modelContext) private var modelContext

    private func deleteTransactions(offsets: IndexSet) {
        let list = filteredTransactions()
        for index in offsets {
            modelContext.delete(list[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete transactions: \(error)")
        }
    }

    // MARK: - Formatting

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
