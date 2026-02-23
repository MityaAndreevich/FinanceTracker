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
        case month
        case all
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .month: "scope.month"
            case .all: "scope.all"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let summary = computeSummary()

                    if summary.hasAnyData == false {
                        EmptyStateView(
                            systemImage: "creditcard",
                            title: "empty.noData",
                            message: "empty.addFirstTransaction"
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
                    Picker("scope.picker.title", selection: $scope) {
                        ForEach(Scope.allCases) { s in
                            Text(s.titleKey).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
        }
    }

    // MARK: - Summary

    private func computeSummary() -> DashboardSummary {
        let filtered = filteredTransactions()
        let currency = filtered.first?.currency ?? "USD"

        var incomeCents = 0
        var expenseCents = 0

        var expenseMap: [String: Int] = [:]
        var incomeMap: [String: Int] = [:]

        for tx in filtered {
            if tx.typeRaw == "income" {
                incomeCents += tx.amountCents
                let key = tx.source?.name ?? String(localized: "dashboard.unknown_source")
                incomeMap[key, default: 0] += tx.amountCents
            } else {
                expenseCents += tx.amountCents

                // ✅ группируем по видимому имени категории
                let key = tx.category.displayName()
                expenseMap[key, default: 0] += tx.amountCents
            }
        }

        let expenseByCategory = expenseMap
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }

        let incomeBySource = incomeMap
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

// MARK: - UI Components (без изменений)

private struct SummaryCards: View {
    let incomeCents: Int
    let expenseCents: Int
    let netCents: Int
    let currency: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    titleKey: "dashboard.summary.income",
                    value: formatMoney(cents: incomeCents, currency: currency),
                    systemImage: "arrow.down.circle.fill",
                    accent: .green
                )

                SummaryCard(
                    titleKey: "dashboard.summary.expenses",
                    value: formatMoney(cents: expenseCents, currency: currency),
                    systemImage: "arrow.up.circle.fill",
                    accent: .red
                )
            }

            SummaryCard(
                titleKey: "dashboard.summary.net",
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
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(accent)

                Text(titleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(value)
                .font(.title3.weight(.semibold))
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
                    titleKey: "dashboard.insights.top_expenses.title",
                    subtitleKey: "dashboard.insights.top_expenses.subtitle",
                    rows: expenseByCategory,
                    currency: currency,
                    icon: "chart.pie.fill"
                )
            }

            if !incomeBySource.isEmpty {
                InsightCard(
                    titleKey: "dashboard.insights.top_income_sources.title",
                    subtitleKey: "dashboard.insights.top_income_sources.subtitle",
                    rows: incomeBySource,
                    currency: currency,
                    icon: "chart.bar.fill"
                )
            }
        }
    }
}

private struct InsightCard: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let rows: [(String, Int)]
    let currency: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(titleKey)
                    .font(.headline)
                Spacer()
            }

            Text(subtitleKey)
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
