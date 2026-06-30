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
    // Q1 (option C): high-confidence parses save immediately and surface a
    // tappable "Saved — tap to edit" toast instead of a confirmation preview.
    @State private var quickAddToast: LocalizedStringKey? = nil
    @State private var quickAddSavedTx: Transaction? = nil   // last auto-saved row (toast target)
    @State private var quickAddEditingTx: Transaction? = nil // drives the edit sheet on toast tap
    // User-tunable auto-save threshold (Settings → Quick Add sensitivity).
    @AppStorage("quickAddConfidenceThreshold") private var quickAddThreshold: Double = 0.75
    // Shake-to-undo: the auto-saved row stays undoable for a 30s rolling window.
    @State private var quickAddSavedAt: Date? = nil
    @State private var undoExpiryTask: Task<Void, Never>? = nil

    /// Rolling 30s window during which a shake undoes the last auto-save. Drives
    /// the conditional ShakeDetector so it only steals first responder briefly.
    private var undoWindowActive: Bool {
        guard quickAddSavedTx != nil, let at = quickAddSavedAt else { return false }
        return Date().timeIntervalSince(at) < 30
    }

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
        // Edits the transaction just auto-saved by a high-confidence Quick Add
        // (the toast's "tap to edit") — opens the existing row, never a new one.
        .sheet(item: $quickAddEditingTx) { tx in
            NavigationStack { EditTransactionView(transaction: tx) }
        }
        // 5.0s (was 3.5s): industry-standard toast window; RU/UK copy is ~40%
        // longer than EN and needs the extra reading time (Apple HIG guidance on
        // time-boxed elements / accessibility).
        .confirmationToast($quickAddToast, duration: 5.0) {
            quickAddEditingTx = quickAddSavedTx
        }
        // Shake-to-undo the last auto-save, only while the 30s window is open so
        // the detector doesn't hold first responder during normal Quick Add use.
        .background {
            if undoWindowActive {
                Color.clear.onShake { undoLastAutoSave() }
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
                // Q1 (option C): a confident parse (amount + merchant + concrete
                // category) saves immediately and offers an edit toast — the
                // preview chip stays as the escape hatch for unsure parses only.
                if parsed.confidence >= quickAddThreshold,
                   let saved = autoSaveQuickAdd(parsed) {
                    quickAddSavedTx = saved
                    quickAddSavedAt = Date()
                    scheduleUndoWindowExpiry()
                    quickAddText = ""
                    quickAddToast = "quickadd.saved.tap_to_edit"
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        quickAddParsed = parsed
                    }
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
                .foregroundStyle(Color.money(isPositive: parsed.typeRaw == TransactionType.income.raw))
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

    /// Saves a high-confidence parse immediately. Returns the created transaction
    /// (for the edit toast) or nil if the save fails, in which case the caller
    /// falls back to the confirmation preview.
    private func autoSaveQuickAdd(_ parsed: QuickAddParsedInput) -> Transaction? {
        do {
            let tx = try QuickAddSaveService.save(
                parsed: parsed,
                modelContext: modelContext,
                defaultCurrencyCode: defaultCurrencyCode
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            refreshWidgetSnapshot()
            RatingPromptCoordinator.recordTransactionSaved()
            return tx
        } catch {
            #if DEBUG
            print("QuickAdd auto-save failed: \(error.localizedDescription)")
            #endif
            return nil
        }
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

    /// Closes the shake-undo window after 30s so the ShakeDetector unmounts and a
    /// stale shake can't delete a long-since-saved row.
    private func scheduleUndoWindowExpiry() {
        undoExpiryTask?.cancel()
        undoExpiryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            quickAddSavedTx = nil
            quickAddSavedAt = nil
        }
    }

    /// Deletes the last auto-saved transaction (shake-to-undo). Only the auto-save
    /// path arms this — manual preview-chip saves are never shake-undoable.
    private func undoLastAutoSave() {
        guard undoWindowActive, let tx = quickAddSavedTx else { return }
        undoExpiryTask?.cancel()
        modelContext.delete(tx)
        try? modelContext.save()
        quickAddSavedTx = nil
        quickAddSavedAt = nil
        refreshWidgetSnapshot()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        quickAddToast = "quickadd.undo.confirmed"
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
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard.net_this_month")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Sign + direction arrow + amount — redundant cues required by WCAG/HIG for CVD safety.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: netCents >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.money(isPositive: netCents >= 0))

                Text((netCents >= 0 ? "+" : "−") + "\u{00A0}" +
                     Money.format(cents: abs(netCents), currencyCode: defaultCurrencyCode))
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(Color.money(isPositive: netCents >= 0))
                    .privacySensitive(true)
            }

            Text(String(
                format: String(localized: "dashboard.spent_earned_caption"),
                Money.format(cents: expenseCents, currencyCode: defaultCurrencyCode),
                Money.format(cents: incomeCents, currencyCode: defaultCurrencyCode)
            ))
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .privacySensitive(true)
        }
        .padding(.vertical, 8)
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
                ForEach(Array(recentTransactions.enumerated()), id: \.element.uuid) { index, tx in
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

    var body: some View {
        VStack(spacing: 12) {
            // Arrow pointing up at QuickAddBar
            Image(systemName: "arrow.up")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.brand)
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
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("dashboard.empty.caption")
                    .font(.subheadline)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.brand)
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
        .background(Color.brand.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Quick Add Bar

private struct QuickAddBar: View {
    @Binding var text: String
    let onSubmit: (QuickAddParsedInput) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 18))
                .foregroundStyle(Color.brand)

            TextField("quickadd.placeholder", text: $text)
                .submitLabel(.done)
                .lineLimit(1)
                .truncationMode(.tail)
                .onSubmit { handleSubmit() }

            if !text.isEmpty {
                Button { handleSubmit() } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brand)
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
