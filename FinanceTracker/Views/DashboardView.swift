//
//  DashboardView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: Scope = .month

    enum Scope: String, CaseIterable, Identifiable {
        case month = "This month"
        case all = "All"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ===== Summary cards =====
                    let summary = computeSummary()

                    if summary.hasAnyData == false {
                        EmptyStateView(
                            systemImage: "creditcard",
                            title: "No data yet",
                            message: "Add your first transaction to see insights here."
                        )
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                    } else {
                        SummaryCards(
                            incomeCents: summary.incomeCents,
                            expenseCents: summary.expenseCents,
                            netCents: summary.netCents,
                            currency: summary.currency
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // ===== Quick insights =====
                        QuickInsights(
                            expenseByCategory: summary.expenseByCategory,
                            incomeBySource: summary.incomeBySource,
                            currency: summary.currency
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("title.dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
        }
    }

    // MARK: - Summary computation

    private func computeSummary() -> DashboardSummary {
        let filtered = filteredTransactions()

        // Currency choice (simple MVP rule):
        // If there are transactions -> take currency from first one.
        // Later we will add "default currency" in Settings.
        let currency = filtered.first?.currency ?? "USD"

        var incomeCents = 0
        var expenseCents = 0

        var expenseByCategory: [(String, Int)] = []
        var incomeBySource: [(String, Int)] = []

        // Aggregate maps
        var expenseMap: [String: Int] = [:]
        var incomeMap: [String: Int] = [:]

        for tx in filtered {
            if tx.typeRaw == "income" {
                incomeCents += tx.amountCents
                let key = tx.source?.name ?? "Unknown source"
                incomeMap[key, default: 0] += tx.amountCents
            } else {
                expenseCents += tx.amountCents
                let key = tx.category.name
                expenseMap[key, default: 0] += tx.amountCents
            }
        }

        expenseByCategory = expenseMap
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }

        incomeBySource = incomeMap
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }

        let netCents = incomeCents - expenseCents

        return DashboardSummary(
            incomeCents: incomeCents,
            expenseCents: expenseCents,
            netCents: netCents,
            currency: currency,
            expenseByCategory: expenseByCategory,
            incomeBySource: incomeBySource,
            hasAnyData: !filtered.isEmpty
        )
    }

    private func filteredTransactions() -> [Transaction] {
        switch scope {
        case .all:
            return transactions
        case .month:
            let calendar = Calendar.current
            let now = Date()
            return transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        }
    }
}

// MARK: - Models

private struct DashboardSummary {
    let incomeCents: Int
    let expenseCents: Int
    let netCents: Int
    let currency: String
    let expenseByCategory: [(String, Int)]
    let incomeBySource: [(String, Int)]
    let hasAnyData: Bool
}

// MARK: - UI Components

private struct SummaryCards: View {
    let incomeCents: Int
    let expenseCents: Int
    let netCents: Int
    let currency: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Income",
                    value: formatMoney(cents: incomeCents, currency: currency),
                    systemImage: "arrow.down.circle.fill",
                    accent: .green
                )

                SummaryCard(
                    title: "Expenses",
                    value: formatMoney(cents: expenseCents, currency: currency),
                    systemImage: "arrow.up.circle.fill",
                    accent: .red
                )
            }

            SummaryCard(
                title: "Net",
                value: formatMoney(cents: netCents, currency: currency),
                systemImage: "equal.circle.fill",
                accent: netCents >= 0 ? .green : .red
            )
        }
    }

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.8)

        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct QuickInsights: View {
    let expenseByCategory: [(String, Int)]
    let incomeBySource: [(String, Int)]
    let currency: String

    var body: some View {
        VStack(spacing: 12) {
            if !expenseByCategory.isEmpty {
                InsightCard(
                    title: "Top expenses",
                    subtitle: "This helps you spot where money leaks.",
                    rows: expenseByCategory,
                    currency: currency,
                    icon: "chart.pie.fill"
                )
            }

            if !incomeBySource.isEmpty {
                InsightCard(
                    title: "Top income sources",
                    subtitle: "Useful when you have multiple streams.",
                    rows: incomeBySource,
                    currency: currency,
                    icon: "chart.bar.fill"
                )
            }
        }
    }
}

private struct InsightCard: View {
    let title: String
    let subtitle: String
    let rows: [(String, Int)]
    let currency: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0)
                            .lineLimit(1)
                        Spacer()
                        Text(formatMoney(cents: row.1, currency: currency))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
