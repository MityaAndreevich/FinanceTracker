//
//  EditTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 28.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct EditTransactionViewLegacy: View {
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

    @State private var selectedCategory: Category?
    @State private var selectedSource: Source?

    @State private var showError = false
    @State private var errorMessage: String = ""

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    private var canSave: Bool {
        parseCents(from: amountText) != nil && selectedCategory != nil
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
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear { loadFromTransaction() }
        .onChange(of: typeRaw) { _, _ in
            // Если сменили тип — категория должна соответствовать типу
            if let current = selectedCategory, current.kindRaw != typeRaw {
                selectedCategory = filteredCategories.first
            }
            // Если это expense — source можно оставить optional, но обычно чистим
            if typeRaw != "income" { selectedSource = nil }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $typeRaw) {
                Text("Expense").tag("expense")
                Text("Income").tag("income")
            }
            .pickerStyle(.segmented)
        }
    }

    private var amountSection: some View {
        Section("Amount") {
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)

            TextField("Tax (optional)", text: $taxText)
                .keyboardType(.decimalPad)
        }
    }

    private var currencySection: some View {
        Section("Currency") {
            Picker("Currency", selection: $currencyCode) {
                ForEach(SupportedCurrency.allCases) { c in
                    Text("\(c.flag) \(c.code) — \(c.name)")
                        .tag(c.code)
                }
            }
        }
    }

    private var titleSection: some View {
        Section("Title (optional)") {
            TextField("e.g., Starbucks, Rent, Salary", text: $merchantText)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            if filteredCategories.isEmpty {
                Text(typeRaw == "income" ? "No income categories yet." : "No expense categories yet.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Category", selection: $selectedCategory) {
                    Text("Select…").tag(Optional<Category>.none)
                    ForEach(filteredCategories) { category in
                        Text(category.name).tag(Optional(category))
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        Section(typeRaw == "income" ? "Source" : "Source (optional)") {
            Picker("Source", selection: $selectedSource) {
                Text("None").tag(Optional<Source>.none)
                ForEach(sources) { source in
                    Text(source.name).tag(Optional(source))
                }
            }

            if typeRaw == "income" {
                Text("Tip: Use Source to track where income comes from (job, client, etc.).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateSection: some View {
        Section("Date") {
            DatePicker("Date", selection: $date, displayedComponents: [.date])
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("Comment", text: $note, axis: .vertical)
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

        selectedCategory = transaction.category
        selectedSource = transaction.source

        // если категория не совпадает с типом (вдруг данные грязные) — подправим
        if let cat = selectedCategory, cat.kindRaw != typeRaw {
            selectedCategory = filteredCategories.first
        }
    }

    private func save() {
        guard let newCategory = selectedCategory else {
            fail("Please select a category.")
            return
        }
        guard let amountCents = parseCents(from: amountText) else {
            fail("Invalid amount.")
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

        do {
            try modelContext.save()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } catch {
            fail("Save failed: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
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
}
