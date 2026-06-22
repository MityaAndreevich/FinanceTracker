//
//  DashboardView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var scope: PeriodScope = .currentMonth

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PeriodSelector(scope: $scope)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                let summary = computeSummary()

                if !summary.hasAnyData {
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
    }

    // MARK: - Summary

    private func computeSummary() -> DashboardSummary {
        let filtered = scope.filter(transactions)

        // Currency is locked app-wide to the user's default. We deliberately do not
        // peek at transaction.currency anymore — historical transactions from a
        // previous default still report the user's CURRENT preferred currency for
        // the rollup. This is a known trade-off documented in the App Store review.
        let currency = defaultCurrencyCode

        var incomeCents = 0
        var expenseCents = 0

        var expenseMap: [String: Int] = [:]
        var incomeMap: [String: Int] = [:]

        for tx in filtered {
            if tx.isIncome {
                incomeCents += tx.amountCents
                let key = tx.source?.name ?? String(localized: "dashboard.unknown_source")
                incomeMap[key, default: 0] += tx.amountCents
            } else {
                expenseCents += tx.amountCents
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
                    titleKey: "dashboard.summary.income",
                    value: Money.format(cents: incomeCents, currencyCode: currency),
                    systemImage: "arrow.down.circle.fill",
                    accent: .green
                )

                SummaryCard(
                    titleKey: "dashboard.summary.expenses",
                    value: Money.format(cents: expenseCents, currencyCode: currency),
                    systemImage: "arrow.up.circle.fill",
                    accent: .red
                )
            }

            SummaryCard(
                titleKey: "dashboard.summary.net",
                value: Money.format(cents: netCents, currencyCode: currency),
                systemImage: "equal.circle.fill",
                accent: netCents >= 0 ? .green : .red
            )
        }
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
                        Text(Money.format(cents: row.1, currencyCode: currency))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
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
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
