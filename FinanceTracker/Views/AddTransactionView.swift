//
//  AddTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    @State private var typeRaw: String = "expense"
    @State private var amountText: String = ""
    @State private var merchantText: String = ""

    /// ✅ Best practice: selection по нашему внешнему стабильному uuid
    @State private var selectedCategoryUUID: UUID? = nil
    @State private var selectedSourceUUID: UUID? = nil

    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var taxText: String = ""

    @State private var errorMessageKey: String = "add.error.unknown"
    @State private var showError: Bool = false

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
        parseCents(from: amountText) != nil && selectedCategoryUUID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                amountSection
                titleSection
                categorySection
                sourceSection
                dateSection
                noteSection
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
            .onAppear { ensureValidCategorySelection() }
            .onChange(of: typeRaw) { _, _ in
                if typeRaw != "income" { selectedSourceUUID = nil }
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
                Text("add.type.expense").tag("expense")
                Text("add.type.income").tag("income")
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var amountSection: some View {
        Section {
            TextField("add.amount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)
                .onChange(of: amountText) { _, newValue in
                    amountText = sanitizeMoneyInput(newValue)
                }

            TextField("add.tax.placeholder", text: $taxText)
                .keyboardType(.decimalPad)
                .onChange(of: taxText) { _, newValue in
                    taxText = sanitizeMoneyInput(newValue)
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
                Text(typeRaw == "income" ? "add.category.empty_income" : "add.category.empty_expense")
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

    @ViewBuilder private var sourceSection: some View {
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
            .disabled(typeRaw != "income") // ✅ вот сюда

            if typeRaw == "income" {
                Button { showAddSourceSheet = true } label: {
                    Label("add.source.add", systemImage: "plus.circle")
                }

                Text("add.source.tip")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("add.source.expense_disabled_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(typeRaw == "income" ? "add.section.source" : "add.section.source_optional")
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

    // MARK: - Actions

    private func add() {
        hideKeyboard()

        guard let category = selectedCategory else {
            showErrorKey("add.error.select_category")
            return
        }
        guard let amountCents = parseCents(from: amountText) else {
            showErrorKey("add.error.invalid_amount")
            return
        }

        let taxCents = parseCents(from: taxText)

        let merchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let tx = Transaction(
            typeRaw: typeRaw,
            amountCents: amountCents,
            currency: defaultCurrencyCode,
            date: date,
            category: category,
            source: (typeRaw == "income") ? selectedSource : nil,   // ✅
            taxCents: taxCents,
            note: cleanNote.isEmpty ? nil : cleanNote,
            merchant: merchant.isEmpty ? nil : merchant
        )

        modelContext.insert(tx)

        do {
            try modelContext.save()

            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif

            resetFormKeepType()
        } catch {
            showErrorKey("add.error.save_failed")
            print("Save failed: \(error.localizedDescription)")
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

        if typeRaw != "income" {
            selectedSourceUUID = nil
        }
    }

    private func showErrorKey(_ key: String) {
        errorMessageKey = key
        showError = true
    }

    // MARK: - Money helpers

    private func parseCents(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        guard let decimal = Decimal(string: normalized) else { return nil }

        let centsDecimal = decimal * 100
        let rounded = NSDecimalNumber(decimal: centsDecimal)
            .rounding(accordingToBehavior: nil)
            .intValue
        return rounded
    }

    private func sanitizeMoneyInput(_ input: String) -> String {
        var s = input.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }

        if let firstDot = s.firstIndex(of: ".") {
            let afterFirst = s.index(after: firstDot)
            let prefix = s[..<afterFirst]
            let suffix = s[afterFirst...].replacingOccurrences(of: ".", with: "")
            s = String(prefix) + suffix
        }

        if let dot = s.firstIndex(of: ".") {
            let afterDot = s.index(after: dot)
            let decimals = s[afterDot...]
            if decimals.count > 2 {
                let end = s.index(afterDot, offsetBy: 2)
                s = String(s[..<end])
            }
        }

        return s
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

                    Text(kindRaw == "income" ? "add.category_sheet.type_income" : "add.category_sheet.type_expense")
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
            print("Failed to create category: \(error)")
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
            print("Failed to create source: \(error)")
        }
    }
}

#Preview {
    NavigationStack { AddTransactionView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
