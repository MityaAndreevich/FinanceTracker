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
    // Optional monthly budget (cents). 0 == unset → the hero falls back to the
    // net-this-month view. No SwiftData model yet; a full budgeting engine is
    // Phase 2. Settable in a future Settings row.
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents: Int = 0
    // Item 5: the widget snapshot is baked in this language so the widget follows
    // the in-app language (it can't inherit the app's Bundle/AppleLanguages override).
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    // The day index the user dismissed the tip on, not a bool: the dismissal expires
    // by itself at the next local midnight, so there is no timer and no cleanup pass.
    @AppStorage(TipDismissal.storageKey) private var tipDismissedDayIndex: Int = TipDismissal.none

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
    // Debounces an accidental double-fire of the quick-add commit (auto-save on a
    // confident parse, or the preview's Save button — they are two branches of one
    // action, so they share one gate). Content-blind by design: it replaces a content
    // dedup that silently dropped legitimately identical entries.
    @State private var saveGate = SaveActionGate()
    @State private var showQuickAddEdit = false
    @State private var quickAddEditPrefill: AddTransactionPrefill? = nil
    // Q1 (option C): high-confidence parses save immediately and surface a
    // tappable "Saved — tap to edit" toast instead of a confirmation preview.
    @State private var quickAddToast: LocalizedStringKey? = nil
    // Severity for `quickAddToast`. This one toast carries both the "Saved" success
    // and the "Couldn't save" failure, so its style must follow the result — a save
    // failure was previously shown with the success (green ✓) style.
    @State private var quickAddToastStyle: ToastStyle = .success
    @State private var quickAddSavedTx: Transaction? = nil   // last auto-saved row (toast target)
    @State private var quickAddEditingTx: Transaction? = nil // drives the edit sheet on toast tap
    // Brief 28-A #1: Dashboard entry point to the (previously Settings-only) budget.
    @State private var showBudgetSheet = false
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

    // MARK: - Budget / safe-to-spend

    private var budgetIsSet: Bool { monthlyBudgetCents > 0 }

    /// Same gain-framed precedence as the Home Screen widget (Item 0) so the app
    /// and widget never disagree: budget → income-remainder → last-resort spent.
    private enum HeroMode { case budget, income, spent }
    private var heroMode: HeroMode {
        if budgetIsSet { return .budget }
        if incomeCents > 0 { return .income }
        return .spent
    }

    /// What's left of the budget this month (can go negative when over budget).
    ///
    /// Delegates to `SafeToSpend` — the proactive alerts read the same computation, and
    /// a notification that disagreed with this screen would be worse than no
    /// notification at all.
    private var remainingCents: Int {
        SafeToSpend.remainingCents(
            monthlyBudgetCents: monthlyBudgetCents,
            spentCents: expenseCents
        )
    }

    /// Days remaining in the current month, today inclusive.
    private var daysLeftInMonth: Int {
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now) else { return 1 }
        let today = cal.component(.day, from: now)
        return max(1, range.count - today + 1)
    }

    private var perDayCents: Int {
        remainingCents > 0 ? remainingCents / daysLeftInMonth : 0
    }

    // MARK: - Category spend aggregation (this month, expenses)

    private struct CategorySpend: Identifiable {
        let id: String
        let category: Category
        let cents: Int
    }

    private var monthCategorySpend: [CategorySpend] {
        let expenses = currentMonthTransactions.filter { !$0.isIncome }
        var byCat: [PersistentIdentifier: (Category, Int)] = [:]
        for tx in expenses {
            let cat = tx.category
            let running = byCat[cat.persistentModelID]?.1 ?? 0
            byCat[cat.persistentModelID] = (cat, running + tx.amountCents)
        }
        return byCat.values
            .map { CategorySpend(id: $0.0.uuid.uuidString, category: $0.0, cents: $0.1) }
            .sorted { $0.cents > $1.cents }
    }

    /// Donut slices: top 6 categories, remainder folded into a gray "Other".
    private var donutSlices: [CategoryDonutView.Slice] {
        let sorted = monthCategorySpend
        let maxSlices = 6
        func slice(_ s: CategorySpend) -> CategoryDonutView.Slice {
            CategoryDonutView.Slice(
                id: s.id,
                name: s.category.displayName(),
                cents: s.cents,
                color: s.category.themeColor
            )
        }
        guard sorted.count > maxSlices else { return sorted.map(slice) }
        var result = sorted.prefix(maxSlices - 1).map(slice)
        let tail = sorted.dropFirst(maxSlices - 1).reduce(0) { $0 + $1.cents }
        result.append(CategoryDonutView.Slice(
            id: "__other",
            name: String(localized: "category.other"),
            cents: tail,
            color: CategoryTheme.map["other"]?.color ?? .gray
        ))
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Brief 28-C: clearly label the reversible demo sandbox + one-tap clear.
                if hasDemoData {
                    demoBanner
                        .padding(.horizontal, 16)
                }

                heroCard
                    .padding(.horizontal, 16)

                // Brief 28-A #1: when no budget is set the "safe to spend" value is
                // hidden, so surface a clear CTA to set one right under the hero.
                if !budgetIsSet {
                    budgetCTACard
                        .coachmarkTarget(.budget)
                        .padding(.horizontal, 16)
                }

                if !monthCategorySpend.isEmpty {
                    spendingCard
                        .padding(.horizontal, 16)
                }

                insightSection

                if !recentTransactions.isEmpty {
                    recentSection
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 12)
        }
        .background(Color.bcPage.ignoresSafeArea())
        // Pin Quick Add below the nav bar so focusing its field never scrolls it
        // up under the inline title (the month "date").
        .safeAreaInset(edge: .top, spacing: 0) {
            quickAddSection
                .coachmarkTarget(.quickAdd)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.bar)
        }
        .navigationTitle(PeriodScope.currentMonth.label(locale: .current))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBudgetSheet) {
            BudgetSetterSheet()
        }
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
        .confirmationToast($quickAddToast, duration: 5.0, style: quickAddToastStyle) {
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
            scheduleWidgetSnapshot()
            if !reduceMotion { animateArrow = true }
        }
        // Item 3: rebuild on a CONTENT signature, not transactions.count. An edit
        // (amount/category/type/date) leaves the count invariant, so a count-only
        // trigger left the widget showing stale pre-edit data.
        .onChange(of: widgetSnapshotSignature) { _, _ in
            scheduleWidgetSnapshot()
        }
        // Re-localize the Dashboard live on an in-app language change (device QA
        // round 1 #2): section headers, captions and code-resolved category names
        // rebuild in the new language without a relaunch.
        .languageReactive()
    }

    // Coalesces widget-snapshot rebuilds. Each rebuild does a full-array scan plus
    // a cross-process `WidgetCenter.reloadAllTimelines()`; firing it on every save
    // *and* again via `onChange(transactions.count)` meant ~2 per Quick Add save —
    // a main-thread hitch during rapid entry (the device hang: synchronous work on
    // com.apple.main-thread while entering ~7 tx). Debounced so a burst of N saves
    // triggers ONE rebuild + ONE timeline reload instead of ~2N.
    @State private var widgetRefreshTask: Task<Void, Never>?

    /// Content fingerprint driving the widget rebuild — moves on edits, not just
    /// on add/delete (Item 3). Cheap: hashes ints/uuids over the current set.
    private var widgetSnapshotSignature: Int {
        NetSnapshotBuilder.contentSignature(transactions: transactions,
                                            currencyCode: defaultCurrencyCode,
                                            monthlyBudgetCents: monthlyBudgetCents,
                                            languageCode: appLanguageCode)
    }

    private func scheduleWidgetSnapshot() {
        widgetRefreshTask?.cancel()
        widgetRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            refreshWidgetSnapshot()
        }
    }

    private func refreshWidgetSnapshot() {
        NetSnapshotBuilder.updateSnapshot(transactions: transactions,
                                          currencyCode: defaultCurrencyCode,
                                          monthlyBudgetCents: monthlyBudgetCents,
                                          languageCode: appLanguageCode)
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
                    quickAddToastStyle = .success
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

                // B5: show the LOCALIZED display name of the category that will
                // actually be saved (resolvedCategory), not the raw English
                // suggestion name ("Food & Drink") which leaked under RU/UK/ES/PT.
                Text(resolvedCategory?.displayName() ?? String(localized: "quickadd.preview.no_category"))
                    .font(.subheadline)
                    .foregroundStyle(resolvedCategory == nil ? .secondary : .primary)

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
        var saved: Transaction?
        // This commit has no Save button and no in-flight guard — it fires straight off
        // a confident parse — so the gate is the only thing standing between a
        // double-delivered parse callback and a double row. Content-blind: it debounces
        // the ACTION, and never inspects what is being saved.
        saveGate.submit {
            do {
                let tx = try QuickAddSaveService.save(
                    parsed: parsed,
                    modelContext: modelContext,
                    defaultCurrencyCode: defaultCurrencyCode
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                scheduleWidgetSnapshot()
                RatingPromptCoordinator.recordTransactionSaved()
                saved = tx
            } catch {
                logSaveFailure("DashboardView.autoSaveQuickAdd", error)
                saveGate.reset()   // a retry must not be debounced away
                #if DEBUG
                print("QuickAdd auto-save failed: \(error.localizedDescription)")
                #endif
            }
        }
        return saved
    }

    private func saveQuickAdd(_ parsed: QuickAddParsedInput, category: Category?) {
        saveGate.submit {
            do {
                _ = try QuickAddSaveService.save(
                    parsed: parsed,
                    modelContext: modelContext,
                    defaultCurrencyCode: defaultCurrencyCode,
                    // B5/B2: commit the *exact* category shown in the preview chip so
                    // the saved row matches what the user confirmed (and so save never
                    // silently re-resolves to a different / nil category).
                    overrideCategory: category
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { quickAddParsed = nil }
                quickAddText = ""
                scheduleWidgetSnapshot()
                RatingPromptCoordinator.recordTransactionSaved()
            } catch {
                // B2: never fail silently. A swallowed error left the preview + input
                // on screen, which read as "Save did nothing" and invited a second tap
                // (the apparent double-count). Surface it and keep the preview so the
                // user can retry deliberately.
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                quickAddSavedTx = nil   // don't let the error toast's tap open a stale edit
                quickAddToastStyle = .error
                quickAddToast = "add.error.save_failed"
                logSaveFailure("DashboardView.saveQuickAdd", error)
                saveGate.reset()   // the deliberate retry this invites must land
                #if DEBUG
                print("QuickAdd save failed: \(error.localizedDescription)")
                #endif
            }
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
        scheduleWidgetSnapshot()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        quickAddToastStyle = .success
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

    // MARK: - Demo sandbox banner (Brief 28-C)

    private var hasDemoData: Bool { transactions.contains { $0.isDemo } }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)
            Text("onboarding.demo.banner")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.bcTextSecondary)
            Spacer(minLength: 8)
            Button {
                DemoSeeder.clearDemoData(modelContext: modelContext)
            } label: {
                Text("onboarding.demo.clear")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(Color.bcAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.bcAccent.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Hero (safe-to-spend / net fallback)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // When a budget is set the header doubles as the EDIT entry point (label +
            // pencil), so the budget is adjustable straight from the Dashboard — not a
            // bare, inert number (Brief 28-A #1). The unset case shows a plain caption;
            // the "Set budget" CTA card below the hero handles that path instead.
            if budgetIsSet {
                Button {
                    showBudgetSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("dashboard.safe_to_spend")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.bcTextSecondary)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.bcAccent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("dashboard.budget.edit.a11y"))
            } else {
                // No budget: still lead with the gain frame when income is known
                // ("Safe to spend {income − spent}"); fall back to a calm "Spent"
                // only when there's nothing to frame against.
                Text(heroMode == .income ? "dashboard.safe_to_spend" : "dashboard.hero.spent")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bcTextSecondary)
            }

            Text(heroBigNumber)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(heroNumberColor)
                .privacySensitive(true)

            Text(heroSubtitle)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Color.bcTextSecondary)
                .privacySensitive(true)

            if budgetIsSet {
                budgetProgressBar
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bcCard(padding: 18)
    }

    /// Brief 28-A #1: prominent, obviously-tappable CTA shown under the hero while no
    /// budget is set — the "safe to spend" value is otherwise invisible and its only
    /// entry point was buried in Settings.
    private var budgetCTACard: some View {
        Button {
            showBudgetSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.bcAccent.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.bcAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("dashboard.budget.cta.title")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcTextPrimary)
                    Text("dashboard.budget.cta.subtitle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.bcTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .bcCard(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The large amount in the hero. Budget mode shows the remaining budget
    /// (locale-formatted, negative when over); fallback shows signed net.
    private var heroBigNumber: String {
        switch heroMode {
        case .budget: return Money.format(cents: remainingCents, currencyCode: defaultCurrencyCode)
        case .income: return Money.format(cents: netCents, currencyCode: defaultCurrencyCode)
        case .spent:  return Money.format(cents: expenseCents, currencyCode: defaultCurrencyCode)
        }
    }

    private var heroNumberColor: Color {
        // Green stays reserved for genuine income (device QA round 1 #8: a green
        // safe-to-spend number read as a gain on the first screen). Neutral primary
        // while healthy; calm coral (bcDanger) only when actually negative/over.
        switch heroMode {
        case .budget: return remainingCents >= 0 ? .bcTextPrimary : .bcDanger
        case .income: return netCents >= 0 ? .bcTextPrimary : .bcDanger
        case .spent:  return .bcTextPrimary
        }
    }

    private var heroSubtitle: String {
        if budgetIsSet {
            if remainingCents >= 0 {
                return String(
                    format: String(localized: "dashboard.safe_per_day"),
                    Money.format(cents: perDayCents, currencyCode: defaultCurrencyCode),
                    daysLeftInMonth
                )
            }
            return String(
                format: String(localized: "dashboard.over_budget"),
                Money.format(cents: -remainingCents, currencyCode: defaultCurrencyCode)
            )
        }
        return String(
            format: String(localized: "dashboard.spent_earned_caption"),
            Money.format(cents: expenseCents, currencyCode: defaultCurrencyCode),
            Money.format(cents: incomeCents, currencyCode: defaultCurrencyCode)
        )
    }

    /// Spent-vs-budget bar. Fills mint; flips to warning once over budget.
    private var budgetProgressBar: some View {
        let fraction = min(max(Double(expenseCents) / Double(max(monthlyBudgetCents, 1)), 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bcSurface2)
                Capsule()
                    .fill(remainingCents < 0 ? Color.bcWarning : Color.bcAccent)
                    // `fraction` is already clamped, but the proposed width is
                    // not ours — a collapsed parent can offer NaN/negative.
                    .frame(width: ChartGuards.dimension(geo.size.width * fraction))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    // MARK: - Spending by category (donut + legend)

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard.spending_by_category")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.bcTextSecondary)

            HStack(alignment: .center, spacing: 18) {
                CategoryDonutView(
                    slices: donutSlices,
                    centerTitle: "dashboard.total_spent",
                    centerValue: Money.format(cents: expenseCents, currencyCode: defaultCurrencyCode),
                    size: 150
                )

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(monthCategorySpend.prefix(4)) { item in
                        categoryLegendRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bcCard(padding: 18)
    }

    @ViewBuilder
    private func categoryLegendRow(_ item: CategorySpend) -> some View {
        let pct = expenseCents > 0 ? Int((Double(item.cents) / Double(expenseCents) * 100).rounded()) : 0
        HStack(spacing: 8) {
            Circle()
                .fill(item.category.themeColor)
                .frame(width: 9, height: 9)

            Text(item.category.displayName())
                .font(.system(size: 14))
                .foregroundStyle(Color.bcTextPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(pct)%")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.bcTextSecondary)
        }
    }

    // MARK: - Insight / Day-0

    private var hasUnlockedInsights: Bool {
        if transactions.count >= 10 { return true }
        let firstLaunchDate = Date(timeIntervalSinceReferenceDate: firstLaunchInterval)
        let daysSince = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: .now).day ?? 0
        return daysSince >= 14
    }

    /// Today's tip, or nil when the library is empty (no content shipped yet).
    private var todaysTip: DailyTip? {
        let library = TipLibraryCache.current
        guard let index = TipRotation.tipIndex(
            dayIndex: todayTipDayIndex,
            canonicalCount: library.canonicalCount
        ) else { return nil }
        return library.tip(at: index)
    }

    /// Local timezone, so the tip rolls over at the user's own midnight.
    private var todayTipDayIndex: Int {
        TipRotation.dayIndex(for: .now, in: .current)
    }

    /// Exactly one teaching card at a time. The Day-0 card is onboarding for a
    /// brand-new user; the daily tip is habit reinforcement for an established one.
    /// Stacking both on a first run would be pure noise on the one screen that has
    /// to stay calm, so they are exclusive branches of the same slot.
    @ViewBuilder
    private var insightSection: some View {
        if transactions.isEmpty {
            DashboardEmptyState(animateArrow: animateArrow)
                .padding(.horizontal, 16)
        } else if !hasUnlockedInsights {
            Day0EducationalCard(showAddTransaction: $showAddTransaction)
                .padding(.horizontal, 16)
        } else if let tip = todaysTip,
                  !TipDismissal.isDismissed(
                      dismissedDayIndex: tipDismissedDayIndex,
                      todayIndex: todayTipDayIndex
                  ) {
            TipOfTheDayCard(tip: tip) {
                tipDismissedDayIndex = todayTipDayIndex
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - This Week

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Device QA round 1 #7: the list is the 5 most-recent rows, not a whole
            // "week", so the label was contradicting the count. Call it "Recent" and
            // offer a "See all" link into the Transactions tab for the full history.
            HStack(alignment: .firstTextBaseline) {
                Text("dashboard.recent")
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bcTextSecondary)

                Spacer(minLength: 8)

                Button {
                    NotificationCenter.default.post(name: .budgetCrabNavigateToTransactions, object: nil)
                } label: {
                    HStack(spacing: 3) {
                        Text("dashboard.see_all")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.bcAccent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("dashboard.see_all"))
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(recentTransactions.enumerated()), id: \.element.uuid) { index, tx in
                    CategoryTileRow(tx: tx)

                    if index < recentTransactions.count - 1 {
                        Rectangle()
                            .fill(Color.bcDivider)
                            .frame(height: 1)
                            .padding(.leading, 48)
                    }
                }
            }
            .bcCard(padding: 14)
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
                .foregroundStyle(Color.bcAccent)

            TextField("quickadd.placeholder", text: $text)
                .submitLabel(.done)
                .lineLimit(1)
                .truncationMode(.tail)
                .onSubmit { handleSubmit() }

            if !text.isEmpty {
                Button { handleSubmit() } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.bcAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.add"))
            }
        }
        .padding(12)
        .background(Color.bcSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.bcDivider, lineWidth: 1)
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
