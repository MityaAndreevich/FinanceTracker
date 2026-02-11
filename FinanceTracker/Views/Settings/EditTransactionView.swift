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

    let transaction: Transaction

    // SwiftData
    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    // UI state (копия значений транзакции)
    @State private var typeRaw: String = "expense"
    @State private var amountText: String = ""
    @State private var taxText: String = ""
    @State private var currencyCode: String = "USD"
    @State private var merchantText: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()

    // ✅ Best practice: selection держим как UUID?
    @State private var selectedCategoryUUID: UUID? = nil
    @State private var selectedSourceUUID: UUID? = nil

    @State private var showError = false
    @State private var errorMessageKey: String = "edit.error.unknown"
    @State private var errorExtra: String? = nil

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
        parseCents(from: amountText) != nil && selectedCategoryUUID != nil
    }

    var body: some View {
        Form {
            typeSection
            amountSection
            currencySection
            titleSection
            categorySection
            sourceSection
            dateSection
            noteSection
        }
        .navigationTitle("edit.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear { loadFromTransaction() }
        .onChange(of: typeRaw) { _, _ in
            // если сменили тип — выбранная категория должна соответствовать
            if let current = selectedCategory, current.kindRaw != typeRaw {
                selectedCategoryUUID = filteredCategories.first?.uuid
            }

            // если это expense — source чистим (у тебя так задумано)
            if typeRaw != "income" {
                selectedSourceUUID = nil
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
                Text("add.type.expense").tag("expense")
                Text("add.type.income").tag("income")
            }
            .pickerStyle(.segmented)
        }
    }

    private var amountSection: some View {
        Section("edit.section.amount") {
            TextField("edit.amount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)
                .onChange(of: amountText) { _, newValue in
                    amountText = sanitizeMoneyInput(newValue)
                }

            TextField("edit.tax.placeholder", text: $taxText)
                .keyboardType(.decimalPad)
                .onChange(of: taxText) { _, newValue in
                    taxText = sanitizeMoneyInput(newValue)
                }
        }
    }

    private var currencySection: some View {
        Section("edit.section.currency") {
            Picker("edit.currency.picker", selection: $currencyCode) {
                ForEach(SupportedCurrency.allCases) { c in
                    Text("\(c.flag) \(c.code) — \(c.name)")
                        .tag(c.code)
                }
            }
        }
    }

    private var titleSection: some View {
        Section("edit.section.merchant") {
            TextField("edit.merchant.placeholder", text: $merchantText)
        }
    }

    private var categorySection: some View {
        Section("edit.section.category") {
            if filteredCategories.isEmpty {
                Text(typeRaw == "income" ? "add.category.empty_income" : "add.category.empty_expense")
                    .foregroundStyle(.secondary)
            } else {
                Picker("edit.category.picker", selection: $selectedCategoryUUID) {
                    Text("common.select")
                        .tag(Optional<UUID>.none)

                    ForEach(filteredCategories, id: \.uuid) { category in
                        Text(LocalizedStringKey(category.displayKeyOrName))
                            .tag(Optional(category.uuid))
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        Section(typeRaw == "income" ? "add.section.source" : "add.section.source_optional") {
            Picker("edit.source.picker", selection: $selectedSourceUUID) {
                Text("common.none")
                    .tag(Optional<UUID>.none)

                ForEach(sources, id: \.uuid) { source in
                    Text(source.name)
                        .tag(Optional(source.uuid))
                }
            }

            if typeRaw == "income" {
                Text("add.source.tip")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
                .lineLimit(2...4)
        }
    }

    // MARK: - Load / Save

    private func loadFromTransaction() {
        typeRaw = transaction.typeRaw
        amountText = formatDecimalFromCents(transaction.amountCents)
        taxText = transaction.taxCents != nil ? formatDecimalFromCents(transaction.taxCents!) : ""
        currencyCode = transaction.currency
        merchantText = transaction.merchant ?? ""
        note = transaction.note ?? ""
        date = transaction.date

        // ✅ Важно: сохраняем uuid связей
        selectedCategoryUUID = transaction.category.uuid
        selectedSourceUUID = transaction.source?.uuid

        // если категория не совпадает с типом — подправим
        if let cat = selectedCategory, cat.kindRaw != typeRaw {
            selectedCategoryUUID = filteredCategories.first?.uuid
        }

        if typeRaw != "income" {
            selectedSourceUUID = nil
        }
    }

    private func save() {
        guard let newCategory = selectedCategory else {
            fail(key: "edit.error.select_category", extra: nil)
            return
        }
        guard let amountCents = parseCents(from: amountText) else {
            fail(key: "edit.error.invalid_amount", extra: nil)
            return
        }

        let taxCents = parseCents(from: taxText)

        let merchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        transaction.typeRaw = typeRaw
        transaction.amountCents = amountCents
        transaction.taxCents = taxCents
        transaction.currency = currencyCode
        transaction.merchant = merchant.isEmpty ? nil : merchant
        transaction.note = cleanNote.isEmpty ? nil : cleanNote
        transaction.date = date
        transaction.category = newCategory
        transaction.source = (typeRaw == "income") ? selectedSource : nil
        transaction.updatedAt = Date()

        do {
            try modelContext.save()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } catch {
            fail(key: "edit.error.save_failed", extra: error.localizedDescription)
        }
    }

    private func fail(key: String, extra: String?) {
        errorMessageKey = key
        errorExtra = extra
        showError = true
    }

    // MARK: - Parsing helpers

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

    private func formatDecimalFromCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        return NSDecimalNumber(decimal: amount).stringValue
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
