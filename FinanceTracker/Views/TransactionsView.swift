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

    var body: some View {
        NavigationStack {
            List {
                let filtered = filteredTransactions()
                let groups = groupedByDay(filtered)

                if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle",
                        title: "No transactions",
                        message: scope == .month
                            ? "Add a transaction to see it here."
                            : "No transactions found."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                        Section(header: Text(sectionTitle(for: day))) {
                            ForEach(groups[day] ?? []) { tx in
                                NavigationLink {
                                    destination(for: tx)
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
                }
            }
            .refreshable {
                await PurchaseManager.shared.refreshStatus()
            }
            .listStyle(.insetGrouped)
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        }
    }

    // MARK: - Destination

    private func destination(for tx: Transaction) -> some View {
        TransactionDetailView(tx: tx)
    }

    // MARK: - Filtering

    private func filteredTransactions() -> [Transaction] {
        let base: [Transaction]
        switch scope {
        case .all:
            base = transactions
        case .month:
            let calendar = Calendar.current
            let now = Date()
            base = transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
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

    // MARK: - Grouping (by day)

    private func groupedByDay(_ list: [Transaction]) -> [Date: [Transaction]] {
        let cal = Calendar.current
        return Dictionary(grouping: list) { tx in
            cal.startOfDay(for: tx.date)
        }
    }

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

    // MARK: - Actions

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
            // Левая часть
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

            // Правая часть (сумма)
            Text(formattedAmount)
                .font(.headline)
                .foregroundStyle(isIncome ? .green : .red)
                .monospacedDigit()
        }
        .contentShape(Rectangle()) // чтобы тапалось по всей строке
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        let merchant = (tx.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if merchant.isEmpty { return tx.category.name }
        return merchant
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
