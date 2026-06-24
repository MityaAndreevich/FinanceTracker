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

    @State private var showAddCategorySheet = false
    @State private var showAddSourceSheet = false

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
                ensureValidCategorySelection()
            }
            .alert("common.error", isPresented: $showError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(errorMessageKey))
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(
                    kindRaw: typeRaw,
                    existingMaxOrder: (categories.filter { $0.kindRaw == typeRaw }.map(\.order).max() ?? 0),
                    onCreated: { newCat in
                        selectedCategoryUUID = newCat.uuid
                    }
                )
                .presentationDetents([.medium])
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
            } else {
                Picker("", selection: $selectedCategoryUUID) {
                    Text("common.select")
                        .tag(Optional<UUID>.none)

                    ForEach(filteredCategories, id: \.uuid) { category in
                        Text(LocalizedStringKey(category.displayKeyOrName))
                            .tag(Optional(category.uuid))
                    }
                }
                .labelsHidden()

                Button { showAddCategorySheet = true } label: {
                    Label("add.category.add", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("add.section.category")
        }
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

            if isRecurring {
                RecurrenceService.scheduleNotification(for: tx)
            }

            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            dismiss()
        } catch {
            showErrorKey("add.error.save_failed")
            print("Save failed: \(error.localizedDescription)")
        }
    }

    private func applyPrefillIfNeeded() {
        guard let p = prefill, !didApplyPrefill else { return }
        didApplyPrefill = true

        typeRaw = p.typeRaw
        amountText = p.amountText
        merchantText = p.merchant
        selectedCategoryUUID = p.categoryUUID
        selectedSourceUUID = p.sourceUUID
        if let rec = p.recurrence {
            isRecurring = true
            recurrenceType = rec
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
            selectedCategoryUUID = subset.first?.uuid
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

private struct AddCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let kindRaw: String
    let existingMaxOrder: Int
    let onCreated: (Category) -> Void

    @State private var name: String = ""
    @State private var icon: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("add.category_sheet.name.placeholder", text: $name)

                    TextField("add.category_sheet.icon.placeholder", text: $icon)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(kindRaw == TransactionType.income.raw ? "add.category_sheet.type_income" : "add.category_sheet.type_expense")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("add.category_sheet.section.title")
                }
            }
            .navigationTitle("add.category_sheet.nav_title")
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

        let lowerName = cleanName.lowercased()
        let allCats = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        if let existing = allCats.filter({ $0.kindRaw == kindRaw }).first(where: { cat in
            if let custom = cat.nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty, custom.lowercased() == lowerName { return true }
            if let key = cat.nameKey, !key.isEmpty {
                let loc = NSLocalizedString(key, comment: "").lowercased()
                return loc != key.lowercased() && loc == lowerName
            }
            return false
        }) {
            onCreated(existing)
            dismiss()
            return
        }

        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextOrder = existingMaxOrder + 1

        let category = Category(
            name: cleanName,
            kindRaw: kindRaw,
            icon: cleanIcon.isEmpty ? nil : cleanIcon,
            order: nextOrder,
            nameKey: nil,
            nameCustom: cleanName
        )

        modelContext.insert(category)

        do {
            try modelContext.save()
            onCreated(category)
            dismiss()
        } catch {
            print("Failed to create category: \(error.localizedDescription)")
        }
    }
}

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
            print("Failed to create source: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack { AddTransactionView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
