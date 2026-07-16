//
//  AddTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

/// Optional initial values, used when re-opening the form to edit a due
/// recurring charge (see RecurringPromptSheet → "Edit").
struct AddTransactionPrefill {
    var typeRaw: String
    var amountText: String
    var merchant: String
    var categoryUUID: UUID?
    var sourceUUID: UUID?
    var recurrence: RecurrenceType?
}

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    /// Non-nil only when the form is opened to edit a recurring charge.
    var prefill: AddTransactionPrefill? = nil
    /// Raw text from QuickEntryView "Use detailed form" path. Parsed on appear.
    var prefillText: String? = nil
    @State private var didApplyPrefill = false

    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    @State private var typeRaw: String = TransactionType.expense.raw
    @State private var amountText: String = ""
    @State private var merchantText: String = ""

    /// Selection by stable external uuid.
    @State private var selectedCategoryUUID: UUID? = nil
    @State private var selectedSourceUUID: UUID? = nil

    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var taxText: String = ""

    @State private var errorMessageKey: String = "add.error.unknown"
    @State private var showError: Bool = false

    // Recurring
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .monthly

    // On-device category suggestion
    @State private var suggestedCategoryName: String?
    @State private var categoryManuallyChosen: Bool = false
    @State private var suggestTask: Task<Void, Never>?

    // Drives the full-category bottom sheet (CategoryPickerSheet) — the same sheet
    // Quick Entry uses. Replaces the old primary-subset Picker + "Show all" toggle so
    // the complete set is one tap away, in place, instead of a two-step reveal.
    @State private var showCategoryPicker = false
    // True when auto-defaulted to "Other" and user hasn't manually picked
    @State private var showPickCategoryTip = false
    // Non-nil when opened from Quick Add with a pre-detected category
    @State private var prefillDetectedCategoryName: String? = nil
    @State private var showCategoryPickerOverride = false

    @State private var showAddCategorySheet = false
    @State private var showAddSourceSheet = false

    @StateObject private var access = AccessManager.shared
    @State private var showPaywall = false

    // Double-submit protection, standardized across all three entry surfaces
    // (v1.0.2 release review, item 1). `isSaving` blocks re-entry while a save is
    // in flight; the gate debounces a fast double-fire of the SAME action (both
    // Add buttons route through `add()`). Content-blind by design — it can only
    // drop a second tap, never a distinct entry — see SaveActionGate.
    @State private var isSaving = false
    @State private var saveGate = SaveActionGate()

    // MARK: - Derived

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    private var selectedCategory: Category? {
        guard let u = selectedCategoryUUID else { return nil }
        return categories.first { $0.uuid == u }
    }

    private var selectedSource: Source? {
        guard let u = selectedSourceUUID else { return nil }
        return sources.first { $0.uuid == u }
    }

    private var canAdd: Bool {
        Money.parseCents(from: amountText) != nil && selectedCategoryUUID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                amountSection
                titleSection
                categorySection
                accountSection
                dateSection
                noteSection
                recurringSection
                saveSection
            }
            .navigationTitle("title.add")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") {
                        hideKeyboard()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("add.keyboard.hide") { hideKeyboard() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") { add() }
                        .disabled(!canAdd)
                }
            }
            .onAppear {
                applyPrefillIfNeeded()
                ensureValidCategorySelection()
            }
            .onChange(of: typeRaw) { _, _ in
                showPickCategoryTip = false
                ensureValidCategorySelection()
                suggestedCategoryName = nil
                scheduleSuggestion()
            }
            .alert("common.error", isPresented: $showError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(errorMessageKey))
            }
            .sheet(isPresented: $showAddCategorySheet) {
                // Unified with Settings → Categories: the preset grid (Bills, Pets,
                // Salary, …) plus a custom field, defaulting to the current type.
                AddCategorySheet(initialKind: typeRaw) { newCat in
                    // Bug 34.5: a category the user just created inline is an explicit
                    // choice — treat it exactly like a manual pick (lines 290–293).
                    // Without marking it chosen (and cancelling any debounced
                    // suggestion), a subsequent merchant keyword guess would silently
                    // overwrite it via applySuggestion, filing the transaction under
                    // the wrong category even though "Test" was saved.
                    suggestTask?.cancel()
                    selectedCategoryUUID = newCat.uuid
                    categoryManuallyChosen = true
                    showPickCategoryTip = false
                }
            }
            .sheet(isPresented: $showAddSourceSheet) {
                AddSourceSheet { newSource in
                    selectedSourceUUID = newSource.uuid
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showCategoryPicker) {
                // Same full-list, searchable, add-new picker Quick Entry uses. Filtered
                // by the current direction; a pick routes through applyCategoryPick.
                CategoryPickerSheet(currentType: typeRaw) { picked in
                    applyCategoryPick(picked)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: - Free-tier caps
    //
    // Only the ADD is gated. Every existing account and category stays pickable
    // here on every tier — a free user who built six accounts during the trial
    // can still file transactions against all six.

    private var canAddSource: Bool {
        access.canAdd(.addAccountBeyondFreeCap, currentCount: sources.count)
    }

    private var canAddCategory: Bool {
        access.canAdd(.addCustomCategoryBeyondFreeCap,
                      currentCount: categories.customCategoryCount)
    }

    private func attemptAddSource() {
        CapGate.attempt(.addAccountBeyondFreeCap,
                        currentCount: sources.count,
                        access: access,
                        showPaywall: $showPaywall) { showAddSourceSheet = true }
    }

    private func attemptAddCategory() {
        CapGate.attempt(.addCustomCategoryBeyondFreeCap,
                        currentCount: categories.customCategoryCount,
                        access: access,
                        showPaywall: $showPaywall) { showAddCategorySheet = true }
    }

    // MARK: - Sections

    @ViewBuilder private var typeSection: some View {
        Section {
            Picker("add.type.picker.title", selection: $typeRaw) {
                Text("add.type.expense").tag(TransactionType.expense.raw)
                Text("add.type.income").tag(TransactionType.income.raw)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var amountSection: some View {
        Section {
            TextField("add.amount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)
                .onChange(of: amountText) { _, newValue in
                    amountText = Money.sanitizeInput(newValue)
                }

            TextField("add.tax.placeholder", text: $taxText)
                .keyboardType(.decimalPad)
                .onChange(of: taxText) { _, newValue in
                    taxText = Money.sanitizeInput(newValue)
                }
        } header: {
            Text("add.section.amount")
        }
    }

    @ViewBuilder private var titleSection: some View {
        Section {
            TextField("add.title.placeholder", text: $merchantText)
                .onChange(of: merchantText) { _, _ in
                    scheduleSuggestion()
                }
        } header: {
            Text("add.section.title")
        }
    }

    @ViewBuilder private var categorySection: some View {
        Section {
            if filteredCategories.isEmpty {
                Text(typeRaw == TransactionType.income.raw ? "add.category.empty_income" : "add.category.empty_expense")
                    .foregroundStyle(.secondary)
                Button { attemptAddCategory() } label: {
                    Label("add.category.add",
                          systemImage: canAddCategory ? "plus.circle" : "lock")
                }
            } else if let detectedName = prefillDetectedCategoryName, !showCategoryPickerOverride {
                // Quick Add pre-fill path — show chip instead of full picker
                autoDetectedPill(detectedName)
                Button { attemptAddCategory() } label: {
                    Label("add.category.add",
                          systemImage: canAddCategory ? "plus.circle" : "lock")
                }
            } else {
                // Inline suggestion (from manual merchant typing)
                if let suggested = suggestedCategoryName {
                    suggestionPill(suggested)
                }

                // Full-set category picker: tapping this row opens CategoryPickerSheet
                // (the same searchable, all-categories, add-new bottom sheet Quick Entry
                // uses), so the complete list is one tap away in place — no primary-only
                // subset and no separate "Show all" step.
                categorySelectRow

                // Tip shown when "Other" was auto-selected (cleared on first manual pick)
                if showPickCategoryTip && !categoryManuallyChosen {
                    Text("category.tip_pick_other")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button { attemptAddCategory() } label: {
                    Label("add.category.add",
                          systemImage: canAddCategory ? "plus.circle" : "lock")
                }
            }
        } header: {
            Text("add.section.category")
        }
    }

    /// Tappable row showing the current category selection; opens the full-set
    /// bottom sheet. Mirrors a standard Form disclosure row (value + chevron).
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

    /// Applies a pick from CategoryPickerSheet. A pick here is a direct user choice,
    /// so it marks the selection manual (same semantics as the old picker binding's
    /// setter): clears any pending suggestion, the "pick Other" tip, and the Quick Add
    /// prefill pill so a later merchant guess can't silently overwrite it.
    private func applyCategoryPick(_ category: Category) {
        selectedCategoryUUID = category.uuid
        categoryManuallyChosen = true
        suggestedCategoryName = nil
        showPickCategoryTip = false
        prefillDetectedCategoryName = nil
    }

    private func suggestionPill(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)

            Text(String(format: String(localized: "addtx.suggestion.pill"), name))
                .font(.footnote)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                suggestedCategoryName = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("common.close"))
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.accentColor.opacity(0.10))
    }

    /// Shown when the view is opened from Quick Add with a pre-detected category.
    /// Tap the pencil icon to expand the full picker and change the selection.
    private func autoDetectedPill(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)

            Text(String(format: String(localized: "category.auto_detected"), name))
                .font(.footnote)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showCategoryPickerOverride = true
                prefillDetectedCategoryName = nil
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("edit.category.picker"))
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.accentColor.opacity(0.10))
    }

    /// Renamed UI label "Source" → "Account". Now available for BOTH income and expense.
    @ViewBuilder private var accountSection: some View {
        Section {
            Picker("", selection: $selectedSourceUUID) {
                Text("common.none")
                    .tag(Optional<UUID>.none)

                ForEach(sources, id: \.uuid) { source in
                    Text(source.name)
                        .tag(Optional(source.uuid))
                }
            }
            .labelsHidden()

            Button { attemptAddSource() } label: {
                Label("add.source.add",
                      systemImage: canAddSource ? "plus.circle" : "lock")
            }

            Text("add.source.tip")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("add.section.source_optional")
        }
    }

    @ViewBuilder private var dateSection: some View {
        Section {
            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
        } header: {
            Text("add.section.date")
        }
    }

    @ViewBuilder private var noteSection: some View {
        Section {
            TextField("add.note.placeholder", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("add.section.note")
        }
    }

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

    @ViewBuilder private var saveSection: some View {
        Section {
            Button(action: add) {
                Text("common.add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(!canAdd)
        }
    }

    // MARK: - Actions

    private func add() {
        hideKeyboard()

        // Re-entrancy guard: ignore repeat invocations while a save is in flight.
        // On the happy path the view dismisses, so isSaving is deliberately not
        // reset there — mirrors QuickEntryView.handleSave.
        guard !isSaving else { return }

        guard let category = selectedCategory else {
            showErrorKey("add.error.select_category")
            return
        }
        guard let amountCents = Money.parseCents(from: amountText) else {
            showErrorKey("add.error.invalid_amount")
            return
        }
        guard amountCents > 0 && amountCents <= 10_000_000_000_000 else {
            showErrorKey("validation.amount.out_of_range")
            return
        }

        let taxCents = Money.parseCents(from: taxText)

        let merchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard merchant.count <= 200 else {
            showErrorKey("validation.merchant.too_long")
            return
        }
        guard cleanNote.count <= 2_000 else {
            showErrorKey("validation.note.too_long")
            return
        }
        let minDate = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!
        let maxDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        guard date >= minDate && date <= maxDate else {
            showErrorKey("validation.date.out_of_range")
            return
        }

        let tx = Transaction(
            typeRaw: typeRaw,
            amountCents: amountCents,
            currency: defaultCurrencyCode,        // Currency is locked to app default.
            date: date,
            category: category,
            source: selectedSource,               // Account available for both income and expense.
            taxCents: taxCents,
            note: cleanNote.isEmpty ? nil : cleanNote,
            merchant: merchant.isEmpty ? nil : merchant,
            recurrenceRaw: isRecurring ? recurrenceType.raw : nil
        )

        // Debounce an accidental double-fire of THIS action (fast double-tap on
        // either Add button, a11y double-fire). Validation stays OUTSIDE the gate:
        // a validation error must not consume the window and debounce away the
        // fix-and-retap that follows it.
        saveGate.submit {
            isSaving = true
            do {
                try AddTransactionSaveService.save(tx, in: modelContext)

                MerchantLearningService.record(
                    merchant: merchant.isEmpty ? nil : merchant,
                    categoryName: category.name,
                    in: modelContext
                )

                if isRecurring {
                    RecurrenceService.scheduleNotification(for: tx)
                }

                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif

                RatingPromptCoordinator.recordTransactionSaved()
                dismiss()
            } catch {
                logSaveFailure("AddTransactionView.add", error)
                showErrorKey("add.error.save_failed")
                isSaving = false   // allow a retry after a genuine failure...
                saveGate.reset()   // ...and don't debounce that retry away
                #if DEBUG
                print("Save failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func applyPrefillIfNeeded() {
        guard !didApplyPrefill else { return }
        didApplyPrefill = true

        if let p = prefill {
            typeRaw = p.typeRaw
            amountText = p.amountText
            merchantText = p.merchant
            selectedCategoryUUID = p.categoryUUID
            selectedSourceUUID = p.sourceUUID
            if let rec = p.recurrence {
                isRecurring = true
                recurrenceType = rec
            }
            // A prefilled category is an explicit choice — don't let inline suggestion override it.
            if let uuid = p.categoryUUID {
                categoryManuallyChosen = true
                showPickCategoryTip = false
                // Show "Auto-detected: [name] ✓" chip instead of full picker
                prefillDetectedCategoryName = categories.first { $0.uuid == uuid }?.displayName()
            }
        } else if let text = prefillText {
            if let p = QuickAddParser.parse(text) {
                typeRaw = p.typeRaw
                amountText = Money.plainDecimalString(cents: p.amountCents)
                merchantText = p.merchant ?? ""
            } else {
                merchantText = text
            }
        }
    }

    // MARK: - On-device category suggestion (Task B)

    private func scheduleSuggestion() {
        suggestTask?.cancel()
        let merchant = merchantText
        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)   // 300ms debounce
            if Task.isCancelled { return }
            await MainActor.run { applySuggestion(for: merchant) }
        }
    }

    private func applySuggestion(for merchant: String) {
        guard !categoryManuallyChosen else { return }
        guard let suggestedName = CategorySuggestionService.suggest(forMerchant: merchant),
              let match = matchCategory(named: suggestedName) else {
            suggestedCategoryName = nil
            return
        }
        selectedCategoryUUID = match.uuid          // programmatic — keeps manual flag false
        suggestedCategoryName = match.displayName()
    }

    /// Match a canonical suggested name against the user's categories for the
    /// current type (legacy name, localized name, or display name).
    private func matchCategory(named name: String) -> Category? {
        let target = name.lowercased()
        return filteredCategories.first { cat in
            if cat.name.lowercased() == target { return true }
            if cat.displayName().lowercased() == target { return true }
            if let key = cat.nameKey {
                let loc = NSLocalizedString(key, comment: "").lowercased()
                if loc == target { return true }
            }
            return false
        }
    }

    private func ensureValidCategorySelection() {
        let subset = filteredCategories

        if let u = selectedCategoryUUID,
           let current = categories.first(where: { $0.uuid == u }),
           current.kindRaw != typeRaw {
            selectedCategoryUUID = nil
        }

        if selectedCategoryUUID == nil {
            let (defaultCat, isOther) = Self.defaultCategory(from: subset)
            selectedCategoryUUID = defaultCat?.uuid
            // Only nudge with the "pick a real category" tip when we fell back to Other.
            showPickCategoryTip = isOther && !categoryManuallyChosen
        }
    }

    /// Default category when none is chosen: prefer "Other" (a safe bucket that does not
    /// mislead analytics) over the first ordered category. Pure and static so the
    /// default-to-Other behavior is unit-testable without standing up the view.
    static func defaultCategory(from subset: [Category]) -> (category: Category?, isOther: Bool) {
        let other = subset.first { $0.nameKey == "category.other" }
        return (other ?? subset.first, other != nil)
    }

    private func resetFormKeepType() {
        amountText = ""
        taxText = ""
        note = ""
        merchantText = ""
        date = Date()

        ensureValidCategorySelection()
        // Account selection is preserved across rapid entries — this is desired
        // when the user is logging multiple expenses from the same card.
    }

    private func showErrorKey(_ key: String) {
        errorMessageKey = key
        showError = true
    }
}

// MARK: - Sheets

private struct AddSourceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onCreated: (Source) -> Void

    @State private var name: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("add.source_sheet.name.placeholder", text: $name)
                    TextField("add.source_sheet.note.placeholder", text: $note)
                } header: {
                    Text("add.source_sheet.section.title")
                }
            }
            .navigationTitle("add.source_sheet.nav_title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let source = Source(
            name: cleanName,
            note: cleanNote.isEmpty ? nil : cleanNote
        )

        modelContext.insert(source)

        do {
            try modelContext.save()
            onCreated(source)
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to create source: \(error.localizedDescription)")
            #endif
        }
    }
}

#Preview {
    NavigationStack { AddTransactionView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
