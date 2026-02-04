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
    @State private var selectedCategory: Category?
    @State private var selectedSource: Source?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var taxText: String = ""

    @State private var errorMessageKey: String = "add.error.unknown"
    @State private var showError: Bool = false

    @State private var showAddCategorySheet = false
    @State private var showAddSourceSheet = false

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    private var canAdd: Bool {
        parseCents(from: amountText) != nil && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("add.type.picker.title", selection: $typeRaw) {
                        Text("add.type.expense").tag("expense")
                        Text("add.type.income").tag("income")
                    }
                    .pickerStyle(.segmented)
                }

                Section("add.section.amount") {
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
                }

                Section("add.section.title") {
                    TextField("add.title.placeholder", text: $merchantText)
                }

                Section("add.section.category") {
                    if filteredCategories.isEmpty {
                        Text(typeRaw == "income"
                             ? "add.category.empty_income"
                             : "add.category.empty_expense")
                        .foregroundStyle(.secondary)

                        Button { showAddCategorySheet = true } label: {
                            Label("add.category.add", systemImage: "plus.circle")
                        }
                    } else {
                        Picker("add.category.picker.title", selection: $selectedCategory) {
                            Text("add.select.placeholder").tag(Optional<Category>.none)
                            ForEach(filteredCategories) { category in
                                Text(category.name).tag(Optional(category))
                            }
                        }

                        Button { showAddCategorySheet = true } label: {
                            Label("add.category.add", systemImage: "plus.circle")
                        }
                    }
                }

                Section(typeRaw == "income" ? "add.section.source" : "add.section.source_optional") {
                    Picker("add.source.picker.title", selection: $selectedSource) {
                        Text("add.source.none").tag(Optional<Source>.none)
                        ForEach(sources) { source in
                            Text(source.name).tag(Optional(source))
                        }
                    }

                    if typeRaw == "income" {
                        Button { showAddSourceSheet = true } label: {
                            Label("add.source.add", systemImage: "plus.circle")
                        }

                        Text("add.source.tip")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("add.section.date") {
                    DatePicker("add.date.picker.title", selection: $date, displayedComponents: [.date])
                }

                Section("add.section.note") {
                    TextField("add.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
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
                if typeRaw != "income" { selectedSource = nil }
                ensureValidCategorySelection()
            }
            .alert("common.error", isPresented: $showError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(errorMessageKey)
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(
                    kindRaw: typeRaw,
                    existingMaxOrder: (categories.filter { $0.kindRaw == typeRaw }.map(\.order).max() ?? 0),
                    onCreated: { newCat in selectedCategory = newCat }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddSourceSheet) {
                AddSourceSheet { newSource in selectedSource = newSource }
                    .presentationDetents([.medium])
            }
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
            source: selectedSource,
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
            // Динамический текст нельзя как LocalizedStringKey-ключом с подстановкой без String(localized:)
            // Поэтому делаем общий ключ.
            showErrorKey("add.error.save_failed")
            print("Save failed: \(error.localizedDescription)")
        }
    }

    private func ensureValidCategorySelection() {
        let subset = filteredCategories

        if let current = selectedCategory, current.kindRaw != typeRaw {
            selectedCategory = nil
        }

        if selectedCategory == nil {
            selectedCategory = subset.first
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
            selectedSource = nil
        }
    }

    private func showErrorKey(_ key: String) {
        errorMessageKey = key
        showError = true
    }

    private func parseCents(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        guard let decimal = Decimal(string: normalized) else { return nil }

        let centsDecimal = decimal * 100
        let rounded = NSDecimalNumber(decimal: centsDecimal).rounding(accordingToBehavior: nil).intValue
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

// MARK: - Add Category Sheet

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
                Section("add.category_sheet.section.title") {
                    TextField("add.category_sheet.name.placeholder", text: $name)

                    TextField("add.category_sheet.icon.placeholder", text: $icon)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(kindRaw == "income" ? "add.category_sheet.type_income" : "add.category_sheet.type_expense")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            order: nextOrder
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

// MARK: - Add Source Sheet

private struct AddSourceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onCreated: (Source) -> Void

    @State private var name: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("add.source_sheet.section.title") {
                    TextField("add.source_sheet.name.placeholder", text: $name)
                    TextField("add.source_sheet.note.placeholder", text: $note)
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
