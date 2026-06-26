//
//  TransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: PeriodScope = .currentMonth
    @State private var searchText: String = ""

    @State private var editTx: Transaction?
    @State private var presentQuickEntry = false

    // MARK: - Derived

    private var filtered: [Transaction] {
        let base = scope.filter(transactions)

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }

        // Diacritic-insensitive, case-insensitive match.
        // "Cafe" should match "Café", "Senor" should match "Señor".
        let needle = q.folded()
        return base.filter { tx in
            let merchant = (tx.merchant ?? "").folded()
            let categoryVisible = tx.category.displayName().folded()
            let categoryLegacy = tx.category.name.folded()
            let source = (tx.source?.name ?? "").folded()
            let note = (tx.note ?? "").folded()

            return merchant.contains(needle)
            || categoryVisible.contains(needle)
            || categoryLegacy.contains(needle)
            || source.contains(needle)
            || note.contains(needle)
        }
    }

    private var grouped: [Date: [Transaction]] {
        let cal = Calendar.current
        return Dictionary(grouping: filtered) { tx in
            cal.startOfDay(for: tx.date)
        }
    }

    private var sortedDays: [Date] {
        grouped.keys.sorted(by: >)
    }

    var body: some View {
        List {
            Section {
                PeriodSelector(scope: $scope)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
            }

            if filtered.isEmpty {
                emptyStateRow
            } else {
                ForEach(sortedDays, id: \.self) { day in
                    daySection(for: day)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("title.transactions")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("transactions.search.prompt")
        )
        .refreshable {
            await PurchaseManager.shared.refreshStatus()
        }
        .navigationDestination(item: $editTx) { tx in
            EditTransactionView(transaction: tx)
        }
        .sheet(isPresented: $presentQuickEntry) {
            QuickEntryView()
        }
    }

    private var emptyStateRow: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)

            Text("transactions.empty.title")
                .font(.headline)

            Button {
                presentQuickEntry = true
            } label: {
                Text("transactions.empty.cta")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func daySection(for day: Date) -> some View {
        Section(header: sectionHeader(for: day)) {
            let dayItems = grouped[day] ?? []

            ForEach(dayItems) { tx in
                Button { editTx = tx } label: {
                    TransactionRow(tx: tx)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                    Button(role: .destructive) { delete(tx) } label: {
                        Label("common.delete", systemImage: "trash")
                    }

                    Button { editTx = tx } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button { editTx = tx } label: {
                        Label("common.edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) { delete(tx) } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(for day: Date) -> Text {
        let cal = Calendar.current

        if cal.isDateInToday(day) { return Text("common.today") }
        if cal.isDateInYesterday(day) { return Text("common.yesterday") }

        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .medium
        df.timeStyle = .none

        return Text(df.string(from: day))
    }

    private func delete(_ tx: Transaction) {
        modelContext.delete(tx)
        do { try modelContext.save() }
        catch { print("Failed to delete transaction: \(error.localizedDescription)") }
    }
}

// MARK: - Row

struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryTitle)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(tx.category.displayKeyOrName))

                    if let sourceName = tx.source?.name, !sourceName.isEmpty {
                        Text("•")
                        Text(sourceName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // ✅ Color-blind safe: explicit sign + arrow icon, color is decorative.
            HStack(spacing: 4) {
                Image(systemName: tx.isIncome ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)

                Text(signedAmount)
                    .font(.headline)
                    .monospacedDigit()
                    .privacySensitive(true)
            }
            .foregroundStyle(tx.isIncome ? .green : .red)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                Text(tx.isIncome ? "analytics.label.income" : "analytics.label.expense")
                + Text(", ")
                + Text(Money.format(cents: tx.amountCents, currencyCode: tx.currency))
            )
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        let merchant = (tx.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return tx.category.displayName()
    }

    private var signedAmount: String {
        Money.formatSigned(
            cents: tx.amountCents,
            isPositive: tx.isIncome,
            currencyCode: tx.currency
        )
    }
}

// MARK: - String folding helper

private extension String {
    /// Lowercase + strip diacritics for substring search.
    func folded() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

#Preview {
    NavigationStack { TransactionsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
