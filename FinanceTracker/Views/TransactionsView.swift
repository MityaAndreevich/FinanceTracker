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

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: Scope = .month
    @State private var searchText: String = ""

    enum Scope: String, CaseIterable, Identifiable {
        case month = "This month"
        case all = "All"
        var id: String { rawValue }
    }

    // MARK: - Derived data (вынесли из body)

    private var filtered: [Transaction] {
        let base: [Transaction]

        switch scope {
        case .all:
            base = transactions
        case .month:
            let cal = Calendar.current
            let now = Date()
            base = transactions.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }

        let lower = q.lowercased()
        return base.filter { tx in
            let merchant = (tx.merchant ?? "").lowercased()
            let category = tx.category.name.lowercased()
            let source = (tx.source?.name ?? "").lowercased()
            let note = (tx.note ?? "").lowercased()

            return merchant.contains(lower)
            || category.contains(lower)
            || source.contains(lower)
            || note.contains(lower)
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
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
            .toolbar { scopeToolbar }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .refreshable {
                // Pull-to-refresh: обновляем статус премиума/энтитлменты
                await PurchaseManager.shared.refreshStatus()
            }
        }
    }

    // MARK: - UI pieces (разрезаем body)

    private var emptyStateRow: some View {
        EmptyStateView(
            systemImage: "list.bullet.rectangle",
            title: "No transactions",
            message: scope == .month ? "Add a transaction to see it here." : "No transactions found."
        )
        .listRowBackground(Color.clear)
    }

    private var scopeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func daySection(for day: Date) -> some View {
        Section(header: Text(sectionTitle(for: day))) {
            let dayItems = grouped[day] ?? []

            ForEach(dayItems) { tx in
                NavigationLink {
                    TransactionDetailView(tx: tx)
                } label: {
                    TransactionRow(tx: tx)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(tx)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }

        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: day)
    }

    private func delete(_ tx: Transaction) {
        modelContext.delete(tx)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete transaction: \(error)")
        }
    }
}

// MARK: - Row

private struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryTitle)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(tx.category.name)

                    if let sourceName = tx.source?.name, !sourceName.isEmpty {
                        Text("•")
                        Text(sourceName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.headline)
                .foregroundStyle(isIncome ? .green : .red)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        let merchant = (tx.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return merchant.isEmpty ? tx.category.name : merchant
    }

    private var isIncome: Bool {
        tx.typeRaw == "income"
    }

    private var formattedAmount: String {
        MoneyFormatter.shared.string(cents: tx.amountCents, currencyCode: tx.currency)
    }
}

// MARK: - Money formatter (cached)

private final class MoneyFormatter {
    static let shared = MoneyFormatter()
    private let formatter = NumberFormatter()

    private init() {
        formatter.numberStyle = .currency
    }

    func string(cents: Int, currencyCode: String) -> String {
        let amount = Decimal(cents) / 100
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    NavigationStack { TransactionsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
