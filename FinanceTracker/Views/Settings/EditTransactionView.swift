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
        .sheet(isPresented: $showCategoryPicker) {
            // Same shared, searchable, full-list picker used by Quick Entry and the
            // Add form — including its "＋ New category" affordance. Routing the edit
            // surface through it (instead of a per-view Picker) is what lets you
            // create a category while editing a transaction (device QA, Item 1).
            CategoryPickerSheet(currentType: typeRaw) { picked in
                selectedCategoryUUID = picked.uuid
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
        // Always route through the shared bottom sheet — even when no category of this
        // kind exists yet, the sheet's "＋ New category" affordance is the way out, so
        // the edit screen is never a dead end (device QA, Item 1).
        Section("edit.section.category") {
            categorySelectRow
        }
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
            source: selectedSource     // Account allowed for both income and expense.
        )

        // Debounce a double-fire of THIS action. Validation stays outside the
        // gate so a validation error can't debounce away the fix-and-retap.
        saveGate.submit {
            isSaving = true
            do {
                try TransactionEditService.update(transaction, with: fields, in: modelContext)

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
