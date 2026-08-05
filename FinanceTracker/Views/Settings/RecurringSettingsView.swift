//
//  RecurringSettingsView.swift
//  FinanceTracker
//
//  Settings → Recurring. Lists every recurring template; swipe to stop a series
//  (keeps the historical transaction, clears its recurrence + notification).
//

import SwiftUI
import SwiftData

struct RecurringSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Transaction> { $0.recurrenceRaw != nil },
        sort: \Transaction.date,
        order: .reverse
    )
    private var recurring: [Transaction]

    // Pending "stop recurrence" — confirmed via the alert below before mutating.
    @State private var pendingStop: Transaction?

    /// The @Query re-shows the row when the stop failed, which is honest but
    /// mute — it reads as "the swipe didn't register". Say it explicitly.
    @State private var showStopFailed = false

    var body: some View {
        List {
            if recurring.isEmpty {
                Section {
                    Text("recurring.settings.empty")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(recurring, id: \.uuid) { tx in
                        row(for: tx)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingStop = tx
                                } label: {
                                    Label("recurring.settings.stop", systemImage: "xmark.circle")
                                }
                            }
                    }
                } footer: {
                    Text("recurring.settings.footer")
                }
            }
        }
        .navigationTitle("settings.recurring")
        .listStyle(.insetGrouped)
        .alert(
            "recurring.settings.stop",
            isPresented: Binding(
                get: { pendingStop != nil },
                set: { if !$0 { pendingStop = nil } }
            )
        ) {
            Button("common.cancel", role: .cancel) { pendingStop = nil }
            Button("recurring.settings.stop", role: .destructive) {
                if let tx = pendingStop,
                   !RecurrenceService.stopRecurrence(for: tx, modelContext: modelContext) {
                    showStopFailed = true
                }
                pendingStop = nil
            }
        }
        .alert("common.error", isPresented: $showStopFailed) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("edit.error.save_failed")
        }
    }

    @ViewBuilder
    private func row(for tx: Transaction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant?.isEmpty == false
                     ? tx.merchant!
                     : String(localized: "recurring.notif.fallback_merchant"))
                    .font(.body)

                if let rec = tx.recurrence {
                    Text(LocalizedStringKey(rec.labelKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(Money.format(cents: tx.amountCents, currencyCode: tx.currency))
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .privacySensitive(true)
        }
    }
}

#Preview {
    NavigationStack { RecurringSettingsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
