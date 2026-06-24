//
//  DashboardView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var showAddTransaction = false

    // Recurring prompt
    @State private var duePrompts: [RecurrencePrompt] = []
    @State private var showRecurringPrompt = false
    @State private var editPrefill: AddTransactionPrefill?
    @State private var showEditPrefill = false

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
        .sheet(isPresented: $showRecurringPrompt) {
            RecurringPromptSheet(prompts: duePrompts) { prompt in
                handleEditRecurring(prompt)
            }
        }
        .sheet(isPresented: $showEditPrefill) {
            if let editPrefill {
                NavigationStack { AddTransactionView(prefill: editPrefill) }
            }
        }
        .task {
            loadDueRecurring()
        }
    }

    // MARK: - Recurring

    private func loadDueRecurring() {
        let due = RecurrenceService.checkAndPromptDueRecurring(modelContext: modelContext)
        guard !due.isEmpty else { return }
        duePrompts = due
        RecurrenceService.markPromptedToday()
        showRecurringPrompt = true
    }

    /// "Edit" on a due prompt: mark the period handled (so it won't re-prompt),
    /// then open the Add form prefilled with the template's values for a one-off entry.
    private func handleEditRecurring(_ prompt: RecurrencePrompt) {
        RecurrenceService.skip(prompt, modelContext: modelContext)

        let uuid = prompt.id
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.uuid == uuid })
        guard let template = try? modelContext.fetch(descriptor).first else { return }

        editPrefill = AddTransactionPrefill(
            typeRaw: template.typeRaw,
            amountText: String(format: "%.2f", Double(template.amountCents) / 100),
            merchant: template.merchant ?? "",
            categoryUUID: template.category.uuid,
            sourceUUID: template.source?.uuid,
            recurrence: nil
        )

        // Let the prompt sheet finish dismissing before presenting the editor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showEditPrefill = true
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
        if transactions.isEmpty {
            EmptyStateCard(showAddTransaction: $showAddTransaction)
                .padding(.horizontal, 16)
        } else {
            let needed = max(0, 5 - transactions.count)
            if needed > 0 {
                Day0EducationalCard(needed: needed, showAddTransaction: $showAddTransaction)
                    .padding(.horizontal, 16)
            }
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

// MARK: - First-launch empty state

private struct EmptyStateCard: View {
    @Binding var showAddTransaction: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("dashboard.empty.headline")
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("dashboard.empty.body")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddTransaction = true
            } label: {
                Text("dashboard.empty.cta")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
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
