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
    /// Set only by the split entry point below, so the editor opens with one
    /// empty part already there. Reset on dismiss — the toolbar's plain "Edit"
    /// must never inherit it.
    @State private var startSplitting = false
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
                row("tx_detail.category", tx.category.displayNameOrFallback())
            }

            // One purchase, several categories: show the itemized breakdown —
            // shares, not raw split rows, so the remainder line ("what stays in
            // the main category") appears exactly as aggregation counts it.
            if CategoryAttribution.isSplit(tx) {
                Section("tx_detail.section.split") {
                    ForEach(Array(CategoryAttribution.shares(for: tx).enumerated()), id: \.offset) { _, share in
                        HStack {
                            Text(share.category.displayNameOrFallback(locale: locale))
                            Spacer()
                            Text(Money.format(cents: share.amountCents, currencyCode: tx.currency))
                                .foregroundStyle(.secondary)
                        }
                        .privacySensitive()
                    }
                }
            } else if !tx.isIncome {
                // The split affordance used to appear ONLY on already-split
                // transactions — i.e. only to users who had already found the
                // feature. Everyone else met no evidence anywhere that splitting
                // exists. This row is the entry point for them; it opens the same
                // editor, which still owns the whole split UI and its validation.
                //
                // Expense-only, matching EditTransactionView's own gate
                // (`typeRaw == expense` guards `splitSection`) — offering it on an
                // income row would open a sheet with nothing to split.
                Section {
                    Button {
                        startSplitting = true
                        showEdit = true
                    } label: {
                        Label("split.add_part", systemImage: "square.split.2x1")
                    }
                } header: {
                    Text("split.section")
                } footer: {
                    Text("split.hint")
                }
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
                Button("common.edit") {
                    startSplitting = false
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { startSplitting = false }) {
            EditTransactionView(transaction: tx, startSplitting: startSplitting)
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
