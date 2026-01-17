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

    var body: some View {
        NavigationStack {
            List {
                if transactions.isEmpty {
                    Text("No transactions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactions) { tx in
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
                        }
                    }
                }
            }
            .navigationTitle("title.transactions")
        }
    }

    /// Превращаем cents (Int) в красивую валюту ("$12.50")
    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
