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

    @State private var scope: Scope = .month
    @State private var searchText: String = ""

    @State private var editTx: Transaction?

    enum Scope: String, CaseIterable, Identifiable {
        case month
        case all
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .month: "scope.month"
            case .all: "scope.all"
            }
        }

        var emptyMessageKey: LocalizedStringKey {
            switch self {
            case .month: "transactions.empty.month"
            case .all: "transactions.empty.all"
            }
        }
    }

    // MARK: - Derived

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

            // ✅ Search should match what user sees
            let categoryVisible = tx.category.displayName().lowercased()
            let categoryLegacy = tx.category.name.lowercased()

            let source = (tx.source?.name ?? "").lowercased()
            let note = (tx.note ?? "").lowercased()

            return merchant.contains(lower)
            || categoryVisible.contains(lower)
            || categoryLegacy.contains(lower)
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

    var body: some View {
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
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: Text("transactions.search.prompt")
        )
        .refreshable {
            await PurchaseManager.shared.refreshStatus()
        }
        .navigationDestination(item: $editTx) { tx in
            EditTransactionView(transaction: tx)
        }
    }

    private var emptyStateRow: some View {
        EmptyStateView(
            systemImage: "list.bullet.rectangle",
            title: "empty.noTransactions",
            message: scope.emptyMessageKey
        )
        .listRowBackground(Color.clear)
    }

    private var scopeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Picker("scope.picker.title", selection: $scope) {
                ForEach(Scope.allCases) { s in
                    Text(s.titleKey).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
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
        catch { print("Failed to delete transaction: \(error)") }
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
                    // ✅ Localized display (key or custom)
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
        if !merchant.isEmpty { return merchant }

        // ✅ если merchant пуст — показываем видимое имя категории
        return tx.category.displayName()
    }

    private var isIncome: Bool { tx.typeRaw == "income" }

    private var formattedAmount: String {
        MoneyFormatter.shared.string(cents: tx.amountCents, currencyCode: tx.currency)
    }
}

// MARK: - Money formatter (currency-safe cache)

private final class MoneyFormatter {
    static let shared = MoneyFormatter()

    private var cache: [String: NumberFormatter] = [:]
    private let lock = NSLock()

    private init() {}

    func string(cents: Int, currencyCode: String) -> String {
        let amount = Decimal(cents) / 100
        let formatter = formatter(for: currencyCode)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private func formatter(for currencyCode: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }

        if let f = cache[currencyCode] { return f }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        cache[currencyCode] = f
        return f
    }
}

#Preview {
    NavigationStack { TransactionsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
