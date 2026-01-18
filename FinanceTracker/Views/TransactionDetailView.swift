//
//  TransactionDetailView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showEdit = false

    let tx: Transaction

    var body: some View {
        List {
            Section("Summary") {
                row("Type", tx.typeRaw.capitalized)
                row("Amount", formatMoney(cents: tx.amountCents, currency: tx.currency))
                row("Date", formattedDate(tx.date))
            }

            Section("Category") {
                row("Category", tx.category.name)
            }

            Section("Source") {
                row("Source", tx.source?.name ?? "—")
            }

            Section("Note") {
                Text(tx.note ?? "—")
                    .foregroundStyle(tx.note == nil ? .secondary : .primary)
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditTransactionView(tx: tx)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
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
