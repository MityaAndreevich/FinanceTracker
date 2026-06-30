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

    // Progressive disclosure picker
    @State private var showAllCategories = false
    // True when auto-defaulted to "Other" and user hasn't manually picked
    @State private var showPickCategoryTip = false
    // Non-nil when opened from Quick Add with a pre-detected category
    @State private var prefillDetectedCategoryName: String? = nil
    @State private var showCategoryPickerOverride = false

    @State private var showAddCategorySheet = false
    @State private var showAddSourceSheet = false

    // MARK: - Derived

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    /// Categories shown in the picker: primary only unless expanded or selected is secondary.
    private var displayedCategories: [Category] {
        let filtered = filteredCategories
        if showAllCategories { return filtered }
        var primary = filtered.filter { $0.isPrimary }
        // Always reveal the currently selected category even if it is secondary
        if let sel = selectedCategoryUUID,
           !primary.contains(where: { $0.uuid == sel }),
           let selectedCat = filtered.first(where: { $0.uuid == sel }) {
            primary.append(selectedCat)
            primary.sort { $0.order < $1.order }
        }
        return primary
    }

    private var hasSecondaryCategories: Bool {
        filteredCategories.contains { !$0.isPrimary }
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
                showAllCategories = false
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
        }
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
                Button { showAddCategorySheet = true } label: {
                    Label("add.category.add", systemImage: "plus.circle")
                }
            } else if let detectedName = prefillDetectedCategoryName, !showCategoryPickerOverride {
                // Quick Add pre-fill path — show chip instead of full picker
                autoDetectedPill(detectedName)
                Button { showAddCategorySheet = true } label: {
                    Label("add.category.add", systemImage: "plus.circle")
                }
            } else {
                // Inline suggestion (from manual merchant typing)
                if let suggested = suggestedCategoryName {
                    suggestionPill(suggested)
                }

                // Progressive disclosure picker
                Picker("", selection: categoryPickerBinding) {
                    Text("common.select").tag(Optional<UUID>.none)
                    ForEach(displayedCategories, id: \.uuid) { category in
                        Text(LocalizedStringKey(category.displayKeyOrName))
                            .tag(Optional(category.uuid))
                    }
                }
                .labelsHidden()

                // "Show all / Show fewer" toggle for secondary categories
                if hasSecondaryCategories {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            showAllCategories.toggle()
                        }
                    } label: {
                        if showAllCategories {
                            Text("category.show_fewer")
                                .font(.footnote)
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("\(String(localized: "category.show_all")) (\(filteredCategories.count))")
                                .font(.footnote)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Tip shown when "Other" was auto-selected (cleared on first manual pick)
                if showPickCategoryTip && !categoryManuallyChosen {
                    Text("category.tip_pick_other")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button { showAddCategorySheet = true } label: {
                    Label("add.category.add", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("add.section.category")
        }
    }

    /// Custom binding so a *user* pick is distinguishable from a programmatic
    /// one: this setter only fires on direct UI interaction, never on our own
    /// assignments (suggestion / prefill / auto-select).
    private var categoryPickerBinding: Binding<UUID?> {
        Binding(
            get: { selectedCategoryUUID },
            set: { newValue in
                selectedCategoryUUID = newValue
                categoryManuallyChosen = true
                suggestedCategoryName = nil
                showPickCategoryTip = false
                prefillDetectedCategoryName = nil
            }
        )
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

            Button { showAddSourceSheet = true } label: {
                Label("add.source.add", systemImage: "plus.circle")
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

        modelContext.insert(tx)

        do {
            try modelContext.save()

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
            showErrorKey("add.error.save_failed")
            #if DEBUG
            print("Save failed: \(error.localizedDescription)")
            #endif
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
            // Prefer "Other" over the first alphabetical/order category —
            // "Other" is a safe default that doesn't mislead analytics.
            let other = subset.first { $0.nameKey == "category.other" }
            selectedCategoryUUID = (other ?? subset.first)?.uuid
            showPickCategoryTip = other != nil && !categoryManuallyChosen
        }
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
