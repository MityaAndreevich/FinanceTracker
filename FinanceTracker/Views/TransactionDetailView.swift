//
//  TransactionDetailView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.locale) private var locale
    @State private var showEdit = false
    let tx: Transaction

    var body: some View {
        List {
            Section("tx_detail.section.summary") {
                // Render the type label through a LocalizedStringKey (not a
                // pre-resolved String) so it localizes via the same environment
                // path as every other Text here — "Expense" → "Расход" can't lag.
                row("tx_detail.type", valueKey: tx.isIncome
                    ? "add.type.income"
                    : "add.type.expense")
                row("tx_detail.amount", Money.format(cents: tx.amountCents, currencyCode: tx.currency))
                    .privacySensitive()
                row("tx_detail.date", formattedDate(tx.date))
            }

            Section("tx_detail.section.category") {
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

    /// Like ``row(_:_:)`` but the value is itself a localization key, resolved by
    /// `Text` through the environment locale/bundle (not pre-resolved to a String).
    private func row(_ titleKey: LocalizedStringKey, valueKey: LocalizedStringKey) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Text(valueKey)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
