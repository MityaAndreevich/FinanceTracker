//
//  EditTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 28.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    let transaction: Transaction

    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    // UI state (copy of transaction values)
    @State private var typeRaw: String = TransactionType.expense.raw
    @State private var amountText: String = ""
    @State private var taxText: String = ""
    @State private var merchantText: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()

    @State private var selectedCategoryUUID: UUID? = nil
    @State private var selectedSourceUUID: UUID? = nil
    @State private var showCategoryPicker = false

    // Recurring — parity with AddTransactionView (1.0.3). Prefilled in
    // loadFromTransaction so the toggle round-trips; the picker keeps a
    // selection even while the toggle is off.
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .monthly

    // Split-across-categories drafts (1.0.3 Item 4). Expense-only surface.
    @State private var splitDrafts: [SplitDraft] = []
    @State private var splitPickerIndex: Int? = nil

    struct SplitDraft: Identifiable {
        let id = UUID()
        var amountText: String = ""
        var categoryUUID: UUID? = nil
    }

    @State private var showError = false
    @State private var errorMessageKey: String = "edit.error.unknown"
    @State private var errorExtra: String? = nil

    // Double-submit protection, same pattern as all three entry surfaces. An
    // edit is idempotent by construction (TransactionEditService UPDATES the
    // existing row, never inserts), so a double-fire can't duplicate data —
    // the gate exists so one tap means one update + one dismiss, and so this
    // surface doesn't quietly diverge from the standard. Content-blind.
    @State private var isSaving = false
    @State private var saveGate = SaveActionGate()

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    private var selectedCategory: Category? {
        guard let id = selectedCategoryUUID else { return nil }
        return categories.first { $0.uuid == id }
    }

    private var selectedSource: Source? {
        guard let id = selectedSourceUUID else { return nil }
        return sources.first { $0.uuid == id }
    }

    private var canSave: Bool {
        Money.parseCents(from: amountText) != nil
            && selectedCategoryUUID != nil
            && splitValidation.isValid
    }

    // MARK: - Split validation (write-side over-sum prevention)

    /// Σ splits > total must be IMPOSSIBLE TO SAVE — not clamped on read, not
    /// warned about, but unsaveable (design §2.2 hardening). `isValid` gates
    /// the Save button; the footer explains what's wrong in the meantime.
    private struct SplitValidation {
        var parsedCents: [Int] = []
        var sumCents: Int = 0
        var remainderCents: Int = 0
        var isOverSum: Bool = false
        var hasInvalidRow: Bool = false
        var isValid: Bool { !isOverSum && !hasInvalidRow }
    }

    private var splitValidation: SplitValidation {
        var v = SplitValidation()
        guard !splitDrafts.isEmpty else { return v }
        let totalCents = Money.parseCents(from: amountText) ?? 0

        for draft in splitDrafts {
            guard let cents = Money.parseCents(from: draft.amountText), cents > 0,
                  draft.categoryUUID != nil else {
                v.hasInvalidRow = true
                continue
            }
            v.parsedCents.append(cents)
            v.sumCents += cents
        }
        v.isOverSum = v.sumCents > totalCents
        v.remainderCents = max(0, totalCents - v.sumCents)
        return v
    }

    var body: some View {
        Form {
            typeSection
            amountSection
            titleSection
            categorySection
            if typeRaw == TransactionType.expense.raw {
                splitSection
            }
            accountSection
            dateSection
            noteSection
            recurringSection
        }
        .navigationTitle("edit.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.save") { save() }
                    .disabled(!canSave)
            }

            // Same dismiss affordance as AddTransactionView — the decimal pad has
            // no return key, so without this the split/amount/tax fields trap the
            // keyboard on screen.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("add.keyboard.hide") { hideKeyboard() }
            }
        }
        .onAppear { loadFromTransaction() }
        .onChange(of: typeRaw) { _, _ in
            // If type changes, reselect category to match.
            if let current = selectedCategory, current.kindRaw != typeRaw {
                selectedCategoryUUID = filteredCategories.first?.uuid
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            // Same shared, searchable, full-list picker used by Quick Entry and the
            // Add form — including its "＋ New category" affordance. Routing the edit
            // surface through it (instead of a per-view Picker) is what lets you
            // create a category while editing a transaction (device QA, Item 1).
            CategoryPickerSheet(currentType: typeRaw) { picked in
                selectedCategoryUUID = picked.uuid
            }
        }
        // Split-row category picker. Anchored HERE, on the Form — NOT on the
        // split Section. A presentation modifier attached to content inside
        // Form/List lazy containers is torn down the moment the hosting row
        // re-renders — the sheet slid down the instant it appeared (same
        // teardown class as .languageReactive over navigationDestination):
        // presentation registrations must live on stable anchors.
        .sheet(item: splitPickerBinding) { boxed in
            CategoryPickerSheet(currentType: TransactionType.expense.raw) { picked in
                if splitDrafts.indices.contains(boxed.index) {
                    splitDrafts[boxed.index].categoryUUID = picked.uuid
                }
            }
        }
        .alert("common.error", isPresented: $showError) {
            Button("common.ok", role: .cancel) {
                errorExtra = nil
            }
        } message: {
            if let extra = errorExtra, !extra.isEmpty {
                Text(LocalizedStringKey(errorMessageKey)) + Text("\n\n") + Text(extra)
            } else {
                Text(LocalizedStringKey(errorMessageKey))
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("edit.section.type") {
            Picker("edit.type.picker", selection: $typeRaw) {
                Text("add.type.expense").tag(TransactionType.expense.raw)
                Text("add.type.income").tag(TransactionType.income.raw)
            }
            .pickerStyle(.segmented)
        }
    }

    private var amountSection: some View {
        Section("edit.section.amount") {
            TextField("edit.amount.placeholder", text: $amountText)
                .plainTextEntry()
                .keyboardType(.decimalPad)
                .onChange(of: amountText) { _, newValue in
                    amountText = Money.sanitizeInput(newValue)
                }

            TextField("edit.tax.placeholder", text: $taxText)
                .plainTextEntry()
                .keyboardType(.decimalPad)
                .onChange(of: taxText) { _, newValue in
                    taxText = Money.sanitizeInput(newValue)
                }
        }
    }

    private var titleSection: some View {
        Section("edit.section.merchant") {
            TextField("edit.merchant.placeholder", text: $merchantText)
                .plainTextEntry()
        }
    }

    private var categorySection: some View {
        // Always route through the shared bottom sheet — even when no category of this
        // kind exists yet, the sheet's "＋ New category" affordance is the way out, so
        // the edit screen is never a dead end (device QA, Item 1).
        Section {
            categorySelectRow
        } header: {
            Text("edit.section.category")
        } footer: {
            // When the parts consume the whole amount, this category receives
            // NOTHING — the remainder is zero, so Analytics attributes every
            // cent to the split categories and this one shows 0 for the
            // purchase. Leaving the field looking like an ordinary selection
            // made that silently self-contradictory: set a category, give all
            // the money away, and the field still reads as though it holds it.
            //
            // Says what is true rather than forbidding the state: a fully
            // assigned split is legitimate, and the category still matters as
            // the fallback if a part's category is later deleted
            // (CategoryAttribution falls back to the parent's category).
            if isFullyAssignedSplit {
                Text("edit.category.fully_split_note")
            }
        }
    }

    /// Expense with at least one part, and the parts consume the entire amount.
    private var isFullyAssignedSplit: Bool {
        guard typeRaw == TransactionType.expense.raw else { return false }
        let v = splitValidation
        return !splitDrafts.isEmpty && !v.isOverSum && v.remainderCents == 0 && v.sumCents > 0
    }

    /// Tappable row showing the current selection; opens the full-set bottom sheet.
    /// Mirrors AddTransactionView.categorySelectRow (value + chevron disclosure).
    private var categorySelectRow: some View {
        Button {
            showCategoryPicker = true
        } label: {
            HStack(spacing: 12) {
                if let cat = selectedCategory {
                    CategoryIconTile(category: cat, size: 28)
                    Text(cat.displayName())
                        .foregroundStyle(.primary)
                } else {
                    Text("common.select")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("edit.category.picker"))
        .accessibilityValue(Text(selectedCategory?.displayName() ?? ""))
    }

    // MARK: - Split across categories (1.0.3 Item 4)

    /// One purchase, several categories — the Amazon-order case. The parent
    /// total stays authoritative; whatever the parts don't cover remains in
    /// the main category above (remainder model, design §2.2). Over-sum
    /// disables Save via `splitValidation` — it cannot be created here.
    private var splitSection: some View {
        Section {
            ForEach($splitDrafts) { $draft in
                splitRow($draft)
            }
            .onDelete { offsets in
                splitDrafts.remove(atOffsets: offsets)
            }

            Button {
                splitDrafts.append(SplitDraft())
            } label: {
                Label("split.add_part", systemImage: "plus.circle")
            }
        } header: {
            Text("split.section")
        } footer: {
            splitFooter
        }
    }

    private func splitRow(_ draft: Binding<SplitDraft>) -> some View {
        HStack(spacing: 10) {
            TextField("split.amount.placeholder", text: draft.amountText)
                .plainTextEntry()
                .keyboardType(.decimalPad)
                .frame(maxWidth: 110)
                .onChange(of: draft.wrappedValue.amountText) { _, newValue in
                    draft.wrappedValue.amountText = Money.sanitizeInput(newValue)
                }

            Button {
                splitPickerIndex = splitDrafts.firstIndex { $0.id == draft.wrappedValue.id }
            } label: {
                HStack(spacing: 8) {
                    if let cat = categories.first(where: { $0.uuid == draft.wrappedValue.categoryUUID }) {
                        CategoryIconTile(category: cat, size: 24)
                        Text(cat.displayName())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text("split.pick_category")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var splitFooter: some View {
        let v = splitValidation
        if splitDrafts.isEmpty {
            Text("split.hint")
        } else if v.isOverSum {
            // The reason Save is disabled — stated, not just enforced.
            Text(String(
                format: NSLocalizedString("split.over_sum.format", comment: ""),
                Money.format(cents: v.sumCents - (Money.parseCents(from: amountText) ?? 0),
                             currencyCode: defaultCurrencyCode)
            ))
            .foregroundStyle(Color.bcWarningInk)
        } else if v.hasInvalidRow {
            Text("split.incomplete_row")
                .foregroundStyle(Color.bcWarningInk)
        } else if v.remainderCents > 0 {
            Text(String(
                format: NSLocalizedString("split.remainder.format", comment: ""),
                Money.format(cents: v.remainderCents, currencyCode: defaultCurrencyCode),
                selectedCategory?.displayName() ?? NSLocalizedString("category.uncategorized", comment: "")
            ))
        } else {
            Text("split.fully_assigned")
        }
    }

    /// Identifiable box so `.sheet(item:)` re-presents correctly per row.
    private struct SplitPickerTarget: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var splitPickerBinding: Binding<SplitPickerTarget?> {
        Binding(
            get: { splitPickerIndex.map(SplitPickerTarget.init(index:)) },
            set: { splitPickerIndex = $0?.index }
        )
    }

    private var accountSection: some View {
        Section("add.section.source_optional") {
            Picker("edit.source.picker", selection: $selectedSourceUUID) {
                Text("common.none")
                    .tag(Optional<UUID>.none)

                ForEach(sources, id: \.uuid) { source in
                    Text(source.name)
                        .tag(Optional(source.uuid))
                }
            }

            Text("add.source.tip")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
        Section("edit.section.date") {
            DatePicker("edit.date.picker", selection: $date, displayedComponents: [.date])
        }
    }

    private var noteSection: some View {
        Section("edit.section.note") {
            TextField("edit.note.placeholder", text: $note, axis: .vertical)
                .plainTextEntry()
                .lineLimit(2...4)
        }
    }

    /// Identical to AddTransactionView.recurringSection, same keys — recurrence
    /// was creation-only until 1.0.3, so an existing charge that turned into a
    /// subscription had no way to say so (device QA).
    @ViewBuilder private var recurringSection: some View {
        Section {
            Toggle("addtx.recurring.toggle", isOn: $isRecurring)
                .onChange(of: isRecurring) { _, on in
                    if on { RecurrenceService.requestAuthorizationIfNeeded() }
                }

            if isRecurring {
                Picker("addtx.recurring.frequency", selection: $recurrenceType) {
                    ForEach(RecurrenceType.allCases) { type in
                        Text(LocalizedStringKey(type.labelKey)).tag(type)
                    }
                }
            }
        } header: {
            Text("addtx.recurring.header")
        } footer: {
            if isRecurring {
                Text("addtx.recurring.footer")
            }
        }
    }

    // MARK: - Load / Save

    private func loadFromTransaction() {
        typeRaw = transaction.typeRaw
        amountText = Money.plainDecimalString(cents: transaction.amountCents)
        taxText = transaction.taxCents.map { Money.plainDecimalString(cents: $0) } ?? ""
        merchantText = transaction.merchant ?? ""
        note = transaction.note ?? ""
        date = transaction.date

        selectedCategoryUUID = transaction.category?.uuid
        selectedSourceUUID = transaction.source?.uuid

        let recurrence = RecurrenceService.editState(for: transaction)
        isRecurring = recurrence.isRecurring
        recurrenceType = recurrence.type

        splitDrafts = CategoryAttribution.orderedSplits(of: transaction).map {
            SplitDraft(
                amountText: Money.plainDecimalString(cents: $0.amountCents),
                categoryUUID: $0.category?.uuid
            )
        }

        // If category doesn't match the type (legacy data), pick the first matching one.
        if let cat = selectedCategory, cat.kindRaw != typeRaw {
            selectedCategoryUUID = filteredCategories.first?.uuid
        }
    }

    private func save() {
        // Re-entrancy guard: one in-flight save at a time. Not reset on the happy
        // path — the view dismisses (mirrors QuickEntryView.handleSave).
        guard !isSaving else { return }

        guard let newCategory = selectedCategory else {
            fail(key: "edit.error.select_category", extra: nil)
            return
        }
        guard let amountCents = Money.parseCents(from: amountText) else {
            fail(key: "edit.error.invalid_amount", extra: nil)
            return
        }
        guard amountCents > 0 && amountCents <= 10_000_000_000_000 else {
            fail(key: "validation.amount.out_of_range", extra: nil)
            return
        }

        let taxCents = Money.parseCents(from: taxText)

        let merchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard merchant.count <= 200 else {
            fail(key: "validation.merchant.too_long", extra: nil)
            return
        }
        guard cleanNote.count <= 2_000 else {
            fail(key: "validation.note.too_long", extra: nil)
            return
        }
        let minDate = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!
        let maxDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        guard date >= minDate && date <= maxDate else {
            fail(key: "validation.date.out_of_range", extra: nil)
            return
        }

        // Splits: the gate above (`canSave` → splitValidation) already made an
        // over-sum or half-filled row unreachable; income edits drop any
        // leftover expense splits (the section is hidden for income).
        let splitInputs: [TransactionEditService.Fields.SplitInput]
        if typeRaw == TransactionType.expense.raw {
            splitInputs = splitDrafts.compactMap { draft in
                guard let cents = Money.parseCents(from: draft.amountText), cents > 0,
                      let uuid = draft.categoryUUID,
                      let category = categories.first(where: { $0.uuid == uuid }) else { return nil }
                return .init(amountCents: cents, category: category, note: nil)
            }
        } else {
            splitInputs = []
        }

        // Route through the guarded edit path: on a thrown save() it rolls the
        // mutation back so the long-lived mainContext is never poisoned (an
        // unguarded save() here silently lost the edit AND broke later saves —
        // the "editing is broken" report, QA round 2 #4).
        let fields = TransactionEditService.Fields(
            typeRaw: typeRaw,
            amountCents: amountCents,
            taxCents: taxCents,
            // Currency is locked to app default — keep the existing one unless the global default changed.
            currency: defaultCurrencyCode,
            merchant: merchant.isEmpty ? nil : merchant,
            note: cleanNote.isEmpty ? nil : cleanNote,
            date: date,
            category: newCategory,
            source: selectedSource,    // Account allowed for both income and expense.
            // Recurrence rides the SAME guarded save as every other field, so a
            // failed edit can't leave the row half-recurring. The notification
            // and period boundary are reconciled only after that save succeeds.
            recurrenceRaw: isRecurring ? recurrenceType.raw : nil,
            splits: splitInputs
        )
        let previousRecurrence = transaction.recurrence

        // Debounce a double-fire of THIS action. Validation stays outside the
        // gate so a validation error can't debounce away the fix-and-retap.
        saveGate.submit {
            isSaving = true
            do {
                try TransactionEditService.update(transaction, with: fields, in: modelContext)

                // Persisted — now reconcile the series: schedule/reschedule on
                // set-or-recadence, cancel + clear the boundary on removal,
                // nothing at all if the toggle wasn't touched. No second save.
                RecurrenceService.applyRecurrenceSideEffects(for: transaction, previous: previousRecurrence)

                MerchantLearningService.record(
                    merchant: merchant.isEmpty ? nil : merchant,
                    categoryName: newCategory.name,
                    in: modelContext
                )

                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                RatingPromptCoordinator.recordTransactionSaved()
                dismiss()
            } catch {
                fail(key: "edit.error.save_failed", extra: error.localizedDescription)
                isSaving = false   // allow the deliberate retry...
                saveGate.reset()   // ...and don't debounce it away
            }
        }
    }

    private func fail(key: String, extra: String?) {
        errorMessageKey = key
        errorExtra = extra
        showError = true
    }
}
