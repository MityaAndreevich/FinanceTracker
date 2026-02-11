//
//  TransactionDetailView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @State private var showEdit = false
    let tx: Transaction

    var body: some View {
        List {
            Section("tx_detail.section.summary") {
                row("tx_detail.type", tx.typeRaw.capitalized)
                row("tx_detail.amount", formatMoney(cents: tx.amountCents, currency: tx.currency))
                row("tx_detail.date", formattedDate(tx.date))
            }

            Section("tx_detail.section.category") {
                // ✅ показываем как в UI (key/custom)
                row("tx_detail.category", tx.category.displayName())
            }

            Section("tx_detail.section.source") {
                row("tx_detail.source", tx.source?.name ?? "—")
            }

            Section("tx_detail.section.note") {
                Text(tx.note ?? "—")
                    .foregroundStyle(tx.note == nil ? .secondary : .primary)
            }
        }
        .navigationTitle("tx_detail.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditTransactionView(transaction: tx)
        }
    }

    private func row(_ titleKey: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
