//
//  DashboardView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    @AppStorage("firstLaunchDate") private var firstLaunchInterval: Double = 0

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @Query(sort: \Category.order, order: .forward)
    private var allCategories: [Category]

    @State private var showAddTransaction = false
    @State private var animateArrow = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Recurring prompt
    @State private var duePrompts: [RecurrencePrompt] = []
    @State private var showRecurringPrompt = false
    @State private var editPrefill: AddTransactionPrefill?
    @State private var showEditPrefill = false

    // Quick Add
    @State private var quickAddText: String = ""
    @State private var quickAddParsed: QuickAddParsedInput? = nil
    @State private var showQuickAddEdit = false
    @State private var quickAddEditPrefill: AddTransactionPrefill? = nil

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

                insightSection

                if !recentTransactions.isEmpty {
                    thisWeekSection
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 12)
        }
        // Pin Quick Add below the nav bar so focusing its field never scrolls it
        // up under the inline title (the month "date").
        .safeAreaInset(edge: .top, spacing: 0) {
            quickAddSection
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.bar)
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
        .sheet(isPresented: $showQuickAddEdit) {
            if let quickAddEditPrefill {
                NavigationStack { AddTransactionView(prefill: quickAddEditPrefill) }
            }
        }
        .task {
            loadDueRecurring()
            refreshWidgetSnapshot()
            if !reduceMotion { animateArrow = true }
        }
        .onChange(of: transactions.count) { _, _ in
            refreshWidgetSnapshot()
        }
    }

    private func refreshWidgetSnapshot() {
        NetSnapshotBuilder.updateSnapshot(transactions: transactions, currencyCode: defaultCurrencyCode)
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

    // MARK: - Quick Add

    private var quickAddSection: some View {
        VStack(spacing: 8) {
            QuickAddBar(text: $quickAddText) { parsed in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    quickAddParsed = parsed
                }
            }
            .padding(.horizontal, 16)

            if let parsed = quickAddParsed {
                quickAddPreviewCard(parsed)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: quickAddParsed != nil)
    }

    @ViewBuilder
    private func quickAddPreviewCard(_ parsed: QuickAddParsedInput) -> some View {
        let resolvedCategory = resolveCategoryForQuickAdd(parsed)
        let canSave = resolvedCategory != nil

        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)

                Text(Money.formatSigned(
                    cents: parsed.amountCents,
                    isPositive: parsed.typeRaw == TransactionType.income.raw,
                    currencyCode: defaultCurrencyCode
                ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(parsed.typeRaw == TransactionType.income.raw ? Color.green : Color.red)
                .monospacedDigit()

                Text("→").foregroundStyle(.secondary)

                Text(parsed.suggestedCategoryName ?? String(localized: "quickadd.preview.no_category"))
                    .font(.subheadline)
                    .foregroundStyle(parsed.suggestedCategoryName == nil ? .secondary : .primary)

                if let merchant = parsed.merchant {
                    Text("→").foregroundStyle(.secondary)
                    Text(merchant)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation { quickAddParsed = nil }
                    quickAddText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.close"))
            }

            HStack(spacing: 12) {
                Button {
                    saveQuickAdd(parsed, category: resolvedCategory)
                } label: {
                    Text("quickadd.preview.save")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(!canSave)

                Button {
                    openEditForQuickAdd(parsed)
                } label: {
                    Text("quickadd.preview.edit")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private func resolveCategoryForQuickAdd(_ parsed: QuickAddParsedInput) -> Category? {
        QuickAddSaveService.resolveCategory(for: parsed, in: modelContext)
    }

    private func saveQuickAdd(_ parsed: QuickAddParsedInput, category: Category?) {
        do {
            _ = try QuickAddSaveService.save(
                parsed: parsed,
                modelContext: modelContext,
                defaultCurrencyCode: defaultCurrencyCode
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { quickAddParsed = nil }
            quickAddText = ""
            refreshWidgetSnapshot()
            RatingPromptCoordinator.recordTransactionSaved()
        } catch {
            #if DEBUG
            print("QuickAdd save failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func openEditForQuickAdd(_ parsed: QuickAddParsedInput) {
        let categoryUUID = resolveCategoryForQuickAdd(parsed)?.uuid
        quickAddEditPrefill = AddTransactionPrefill(
            typeRaw: parsed.typeRaw,
            amountText: Money.plainDecimalString(cents: parsed.amountCents),
            merchant: parsed.merchant ?? "",
            categoryUUID: categoryUUID,
            sourceUUID: nil,
            recurrence: nil
        )
        withAnimation { quickAddParsed = nil }
        quickAddText = ""
        showQuickAddEdit = true
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
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
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

    private var hasUnlockedInsights: Bool {
        if transactions.count >= 10 { return true }
        let firstLaunchDate = Date(timeIntervalSinceReferenceDate: firstLaunchInterval)
        let daysSince = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: .now).day ?? 0
        return daysSince >= 14
    }

    @ViewBuilder
    private var insightSection: some View {
        if transactions.isEmpty {
            DashboardEmptyState(animateArrow: animateArrow)
                .padding(.horizontal, 16)
        } else if !hasUnlockedInsights {
            Day0EducationalCard(showAddTransaction: $showAddTransaction)
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

// MARK: - Empty state (contextual hint pointing at QuickAddBar)

private struct DashboardEmptyState: View {
    let animateArrow: Bool

    private let mintColor = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)

    var body: some View {
        VStack(spacing: 12) {
            // Arrow pointing up at QuickAddBar
            Image(systemName: "arrow.up")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(mintColor)
                .opacity(animateArrow ? 1 : 0.35)
                .offset(y: animateArrow ? -4 : 4)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: animateArrow
                )

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("dashboard.empty.title")
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("dashboard.empty.caption")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

// MARK: - Day-0 Educational Card

private struct Day0EducationalCard: View {
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

            Text("dashboard.day0.message.singular")
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

// MARK: - Quick Add Bar

private struct QuickAddBar: View {
    @Binding var text: String
    let onSubmit: (QuickAddParsedInput) -> Void

    private let mintColor = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 18))
                .foregroundStyle(mintColor)

            TextField("quickadd.placeholder", text: $text)
                .submitLabel(.done)
                .onSubmit { handleSubmit() }

            if !text.isEmpty {
                Button { handleSubmit() } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(mintColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.add"))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private func handleSubmit() {
        guard let parsed = QuickAddParser.parse(text) else { return }
        onSubmit(parsed)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
