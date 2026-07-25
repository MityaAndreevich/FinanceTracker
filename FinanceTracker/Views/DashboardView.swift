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

    // The per-user tip collection. Observed so the daily card appears the instant a
    // launch reveals today's tip (the reveal is driven from the app's launch task).
    @ObservedObject private var tipCollection = TipCollection.shared

    // SCOPED queries (hang-brief Item 1, stage 2). The old single
    // `@Query(all transactions)` re-fetched and re-walked the ENTIRE table on
    // the main thread on every body evaluation after every save — several
    // O(n)-with-Calendar passes per eval (currentMonth filter, prefix, widget
    // signature), measured at ~5.5s of blocked UI per QuickAdd save at 8k rows.
    // Everything this screen renders is current-month or recent-5; the only
    // all-time facts it needs are COUNTS, which are SQL aggregates (see
    // `totalTransactionCount` / `hasDemoData`) and never materialize rows.
    //
    // The month window is fixed at view-identity creation; ContentView flips the
    // Dashboard's `.id` on a month rollover so the predicate follows the
    // calendar (see `dashboardMonthKey` there).
    @Query private var monthTransactions: [Transaction]

    /// The 5 newest rows, any date — the "Recent" list. Also the cheapest
    /// correct emptiness probe: this is empty iff the table is empty.
    @Query private var recentTransactions: [Transaction]

    @Query(sort: \Category.order, order: .forward)
    private var allCategories: [Category]

    init() {
        let calendar = Calendar.current
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: .now)
        ) ?? .now
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? .distantFuture

        _monthTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= monthStart && $0.date < nextMonthStart },
            sort: \Transaction.date,
            order: .reverse
        )

        var recent = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        recent.fetchLimit = 5
        _recentTransactions = Query(recent)
    }

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

    /// The @Query is already month-scoped; the name survives so the dozen
    /// call sites below don't churn.
    private var currentMonthTransactions: [Transaction] { monthTransactions }

    /// All-time row count as a SQL COUNT — no row materialization, ~ms at any
    /// scale. Recomputed per body eval, which is exactly when it can change.
    private var totalTransactionCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Transaction>())) ?? 0
    }

    // Extracted to MonthTotals (design doc §8.1) so the SplitCanary suite pins
    // the production formula. Category-blind: parent transactions only.
    private var expenseCents: Int {
        MonthTotals.expenseCents(currentMonthTransactions)
    }

    private var incomeCents: Int {
        MonthTotals.incomeCents(currentMonthTransactions)
    }

    private var netCents: Int { incomeCents - expenseCents }


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

    /// The Velocity Dashboard numbers (Item 2): today's allowance, the budget
    /// ring fraction, and the month-end forecast. nil while no budget is set.
    private var allowance: DailyAllowance.Snapshot? {
        DailyAllowance.compute(
            monthlyBudgetCents: monthlyBudgetCents,
            spentThisMonthCents: expenseCents
        )
    }

    // MARK: - Category spend aggregation (this month, expenses)

    private struct CategorySpend: Identifiable {
        let id: String
        let category: Category?   // nil = the uncategorized bucket (§1.4)
        let cents: Int
    }

    /// A-path (design doc §2.4 A2): sums CategoryAttribution shares, so a
    /// split purchase's money lands in the splits' categories. The donut's
    /// center total stays the parent-summed `expenseCents` — the two agree by
    /// the conservation invariant (canary: donutAttributionSumEqualsMonthExpenseTotal).
    private var monthCategorySpend: [CategorySpend] {
        hangProbe("Dashboard.categorySpend", rows: currentMonthTransactions.count) {
            monthCategorySpendPass
        }
    }

    private var monthCategorySpendPass: [CategorySpend] {
        let expenses = currentMonthTransactions.filter { !$0.isIncome }
        var byBucket: [UUID: (Category?, Int)] = [:]
        for tx in expenses {
            for share in CategoryAttribution.shares(for: tx) {
                let key = share.category.bucketID
                let running = byBucket[key]?.1 ?? 0
                byBucket[key] = (share.category, running + share.amountCents)
            }
        }
        return byBucket
            .map { CategorySpend(id: $0.key.uuidString, category: $0.value.0, cents: $0.value.1) }
            .sorted { $0.cents > $1.cents }
    }

    /// Donut slices: top 6 categories, remainder folded into a gray "Other".
    private var donutSlices: [CategoryDonutView.Slice] {
        let sorted = monthCategorySpend
        let maxSlices = 6
        func slice(_ s: CategorySpend) -> CategoryDonutView.Slice {
            CategoryDonutView.Slice(
                id: s.id,
                name: s.category.displayNameOrFallback(),
                cents: s.cents,
                color: s.category.themeColorOrFallback
            )
        }
        guard sorted.count > maxSlices else { return sorted.map(slice) }
        var result = sorted.prefix(maxSlices - 1).map(slice)
        let tail = sorted.dropFirst(maxSlices - 1).reduce(0) { $0 + $1.cents }
        result.append(CategoryDonutView.Slice(
            id: "__other",
            // The FOLD aggregate, not the seeded catch-all category — it must
            // share the Breakdown fold's label ("Other"/"Другое"), never
            // `category.other` (device QA 2026-07-23 #3: three buckets rendered
            // as "Без категории" and nobody could tell them apart).
            name: String(localized: "analytics.breakdown.other"),
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
        // Month-scoped input: NetSnapshotBuilder.build month-filters internally,
        // so the widget only ever renders current-month data — walking the whole
        // table here was pure waste (and O(n) on the main thread per change).
        //
        // Probed (2026-07-25): this is a computed property feeding `.onChange`,
        // so SwiftUI re-derives it on EVERY body evaluation, and since 1.0.3 its
        // hash walk touches `tx.splits` per row (a to-many fault).
        hangProbe("Dashboard.widgetSignature", rows: monthTransactions.count) {
            NetSnapshotBuilder.contentSignature(transactions: monthTransactions,
                                                currencyCode: defaultCurrencyCode,
                                                monthlyBudgetCents: monthlyBudgetCents,
                                                languageCode: appLanguageCode)
        }
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
        hangProbe("Dashboard.widgetRebuild", rows: monthTransactions.count) {
            NetSnapshotBuilder.updateSnapshot(transactions: monthTransactions,
                                              currencyCode: defaultCurrencyCode,
                                              monthlyBudgetCents: monthlyBudgetCents,
                                              languageCode: appLanguageCode)
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
            categoryUUID: template.category?.uuid,
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

    /// SQL COUNT with a predicate — never materializes rows.
    private var hasDemoData: Bool {
        ((try? modelContext.fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo })
        )) ?? 0) > 0
    }

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
        HStack(alignment: .center, spacing: 16) {
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
                            // Velocity Dashboard (Item 2): the hero is the DAILY
                            // number — budgets are monthly but life is daily.
                            Text("dashboard.safe_today")
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

                if let allowance, !allowance.isOverBudget {
                    paceLine(allowance)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // The monthly budget's whole presence in the hero: a non-numeric
            // percentage ring — status, not a second competing currency figure.
            if let allowance {
                budgetStatusDonut(allowance)
            }
        }
        .bcCard(padding: 18)
    }

    /// Gain-framed month-end pace verdict (Item 2). Muted tints, never alarm
    /// red — the over-pace line is a nudge phrased as a win ("keeping to
    /// today's number lands you under"), not a warning.
    private func paceLine(_ a: DailyAllowance.Snapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: a.onPaceToStayUnder
                  ? "gauge.with.dots.needle.33percent"
                  : "gauge.with.dots.needle.67percent")
                .font(.system(size: 12, weight: .semibold))
            Text(a.onPaceToStayUnder ? "dashboard.pace.on_track" : "dashboard.pace.hold_the_line")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(a.onPaceToStayUnder ? Color.bcPositive : Color.bcWarningInk)
        .accessibilityElement(children: .combine)
    }

    /// The budget as a status ring: fill = fraction used, muted mint at every
    /// level (never alarm red — Item 2), percentage in the center. Plain
    /// SwiftUI strokes, no Charts — nothing here can hit a degenerate domain.
    private func budgetStatusDonut(_ a: DailyAllowance.Snapshot) -> some View {
        ZStack {
            Circle()
                .stroke(Color.bcSurface2, lineWidth: 7)
            Circle()
                .trim(from: 0, to: a.fractionUsed)   // clamped 0…1 at the source
                .stroke(Color.bcAccent.opacity(0.85),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(a.percentUsed)%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color.bcTextSecondary)
                .padding(6)
        }
        .frame(width: 64, height: 64)
        .accessibilityLabel(Text(String(
            format: String(localized: "dashboard.budget_used.a11y"), a.percentUsed
        )))
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

    /// The large amount in the hero. Budget mode is the Velocity Dashboard's
    /// DAILY allowance (gain-framed "safe to spend today"); over budget it
    /// falls back to the truthful monthly remainder. Fallbacks show signed net.
    private var heroBigNumber: String {
        switch heroMode {
        case .budget:
            if let allowance, !allowance.isOverBudget {
                return Money.format(cents: allowance.perDayCents, currencyCode: defaultCurrencyCode)
            }
            return Money.format(cents: remainingCents, currencyCode: defaultCurrencyCode)
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
            if let allowance, !allowance.isOverBudget {
                // Non-currency by design: the daily amount above is the only
                // money figure in the healthy hero (Item 2 — one number is
                // "gist", the ring is "status").
                return String(
                    format: String(localized: "dashboard.days_left"),
                    allowance.daysLeft
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
                .fill(item.category.themeColorOrFallback)
                .frame(width: 9, height: 9)

            Text(item.category.displayNameOrFallback())
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
        if totalTransactionCount >= 10 { return true }
        let firstLaunchDate = Date(timeIntervalSinceReferenceDate: firstLaunchInterval)
        let daysSince = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: .now).day ?? 0
        return daysSince >= 14
    }

    /// Today's tip — the user's most-recently unlocked tip — or nil when the library
    /// is empty (no content shipped yet) or nothing has been revealed yet.
    private var todaysTip: DailyTip? {
        tipCollection.todaysTip
    }

    /// Local timezone, so the tip rolls over at the user's own midnight.
    private var todayTipDayIndex: Int {
        TipRotation.dayIndex(for: .now, in: .current)
    }

    /// Exactly one teaching card at a time — see `DashboardTeachingSlot.decide`
    /// for the precedence and the day-1 contract (v1.0.2 review, item 2).
    @ViewBuilder
    private var insightSection: some View {
        let slot = DashboardTeachingSlot.decide(
            // recent-5 is empty iff the table is empty — first-frame correct,
            // no COUNT round-trip on the teaching-slot path.
            hasTransactions: !recentTransactions.isEmpty,
            tipAvailable: todaysTip != nil,
            tipDismissedToday: TipDismissal.isDismissed(
                dismissedDayIndex: tipDismissedDayIndex,
                todayIndex: todayTipDayIndex
            ),
            insightsUnlocked: hasUnlockedInsights
        )
        switch slot {
        case .emptyState:
            DashboardEmptyState(animateArrow: animateArrow)
                .padding(.horizontal, 16)
        case .tip:
            if let tip = todaysTip {
                TipOfTheDayCard(tip: tip) {
                    tipDismissedDayIndex = todayTipDayIndex
                }
                .padding(.horizontal, 16)
            }
        case .day0:
            Day0EducationalCard(showAddTransaction: $showAddTransaction)
                .padding(.horizontal, 16)
        case .none:
            EmptyView()
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

/// Which single teaching card the Dashboard's insight slot shows. Pure, so the
/// precedence — the part that has regressed three times from three different
/// angles (global epoch, orphan-inflated count, a borrowed maturity gate) — is
/// unit-tested rather than trapped in a ViewBuilder.
///
/// Precedence (v1.0.2 review, item 2):
///   1. No transactions yet → the empty state. Adding the first transaction is
///      the one action that matters on an empty dashboard; nothing competes.
///   2. A tip exists and wasn't dismissed today → the daily tip, FROM DAY 1.
///      Tips are static content and need no data. The old order borrowed
///      `hasUnlockedInsights` — a DATA-maturity gate (10 transactions / 14
///      days) that exists so analytics mean something — which kept the
///      dashboard silent while reveals accumulated, then debuted the card
///      alongside the very back-catalogue the per-user deck exists to prevent.
///   3. Otherwise, while insights are still locked → the Day-0 "keep tracking"
///      nudge. The tip supersedes it, but the nudge keeps its job for an early
///      user who dismissed today's tip.
///
/// Exactly one card at a time, always — a calm dashboard is the invariant.
enum DashboardTeachingSlot: Equatable {
    case emptyState
    case tip
    case day0
    case none

    static func decide(
        hasTransactions: Bool,
        tipAvailable: Bool,
        tipDismissedToday: Bool,
        insightsUnlocked: Bool
    ) -> DashboardTeachingSlot {
        guard hasTransactions else { return .emptyState }
        if tipAvailable && !tipDismissedToday { return .tip }
        return insightsUnlocked ? .none : .day0
    }
}

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
                .plainTextEntry()
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
