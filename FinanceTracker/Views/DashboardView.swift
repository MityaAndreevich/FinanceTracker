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

    @State private var showAddTransaction = false

    private var currentMonthTransactions: [Transaction] {
        PeriodScope.currentMonth.filter(transactions)
    }

    private var expenseCents: Int {
        currentMonthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }
    }

    private var incomeCents: Int {
        currentMonthTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCents }
    }

    private var netCents: Int { incomeCents - expenseCents }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                insightSection

                if !recentTransactions.isEmpty {
                    thisWeekSection
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 12)
        }
        .navigationTitle(PeriodScope.currentMonth.label(locale: .current))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack { AddTransactionView() }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("dashboard.net_this_month")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Sign + direction arrow + amount — redundant cues required by WCAG/HIG for CVD safety.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: netCents >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(netCents >= 0 ? Color.green : Color.red)

                Text((netCents >= 0 ? "+" : "−") + "\u{00A0}" +
                     Money.format(cents: abs(netCents), currencyCode: defaultCurrencyCode))
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(netCents >= 0 ? Color.green : Color.red)
                    .privacySensitive(true)
            }

            Text(String(
                format: String(localized: "dashboard.spent_earned_caption"),
                Money.format(cents: expenseCents, currencyCode: defaultCurrencyCode),
                Money.format(cents: incomeCents, currencyCode: defaultCurrencyCode)
            ))
            .font(.system(size: 13))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .privacySensitive(true)

            Text(netCents < 0 ? "dashboard.spent_more" : "dashboard.earned_more")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("dashboard.based_on_tracked")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Insight / Day-0

    @ViewBuilder
    private var insightSection: some View {
        let needed = max(0, 5 - transactions.count)
        if needed > 0 {
            Day0EducationalCard(needed: needed, showAddTransaction: $showAddTransaction)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - This Week

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard.this_week")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(recentTransactions.enumerated()), id: \.offset) { index, tx in
                    TransactionRow(tx: tx)
                        .padding(.horizontal, 16)

                    if index < recentTransactions.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Day-0 Educational Card

private struct Day0EducationalCard: View {
    let needed: Int
    @Binding var showAddTransaction: Bool

    private let mintColor = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(mintColor)
                Text("dashboard.day0.title")
                    .font(.headline)
            }

            Text(needed == 1
                 ? String(localized: "dashboard.day0.message.singular")
                 : String(format: String(localized: "dashboard.day0.message.plural"), needed))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showAddTransaction = true
            } label: {
                Text("dashboard.day0.cta")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mintColor.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
