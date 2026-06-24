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
        Money.parseCents(from: amountText) != nil && selectedCategoryUUID != nil
    }

    var body: some View {
        Form {
            typeSection
            amountSection
            titleSection
            categorySection
            accountSection
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
            // If type changes, reselect category to match.
            if let current = selectedCategory, current.kindRaw != typeRaw {
                selectedCategoryUUID = filteredCategories.first?.uuid
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
                .keyboardType(.decimalPad)
                .onChange(of: amountText) { _, newValue in
                    amountText = Money.sanitizeInput(newValue)
                }

            TextField("edit.tax.placeholder", text: $taxText)
                .keyboardType(.decimalPad)
                .onChange(of: taxText) { _, newValue in
                    taxText = Money.sanitizeInput(newValue)
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
                Text(typeRaw == TransactionType.income.raw ? "add.category.empty_income" : "add.category.empty_expense")
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
                .lineLimit(2...4)
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

        selectedCategoryUUID = transaction.category.uuid
        selectedSourceUUID = transaction.source?.uuid

        // If category doesn't match the type (legacy data), pick the first matching one.
        if let cat = selectedCategory, cat.kindRaw != typeRaw {
            selectedCategoryUUID = filteredCategories.first?.uuid
        }
    }

    private func save() {
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

        transaction.typeRaw = typeRaw
        transaction.amountCents = amountCents
        transaction.taxCents = taxCents
        // Currency is locked to app default — keep the existing one unless the global default changed.
        transaction.currency = defaultCurrencyCode
        transaction.merchant = merchant.isEmpty ? nil : merchant
        transaction.note = cleanNote.isEmpty ? nil : cleanNote
        transaction.date = date
        transaction.category = newCategory
        transaction.source = selectedSource     // Account allowed for both income and expense.
        transaction.updatedAt = Date()

        do {
            try modelContext.save()

            MerchantLearningService.record(
                merchant: merchant.isEmpty ? nil : merchant,
                categoryName: newCategory.name,
                in: modelContext
            )

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
}
