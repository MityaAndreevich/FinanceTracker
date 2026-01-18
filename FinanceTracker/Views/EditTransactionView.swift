//
//  EditTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    let tx: Transaction

    // UI state (копия текущих значений)
    @State private var typeRaw: String
    @State private var amountText: String
    @State private var selectedCategory: Category?
    @State private var selectedSource: Source?
    @State private var date: Date
    @State private var note: String
    @State private var taxText: String

    @State private var errorMessage: String?
    @State private var showError = false

    init(tx: Transaction) {
        self.tx = tx
        _typeRaw = State(initialValue: tx.typeRaw)
        _amountText = State(initialValue: EditTransactionView.toMoneyString(cents: tx.amountCents))
        _selectedCategory = State(initialValue: tx.category)
        _selectedSource = State(initialValue: tx.source)
        _date = State(initialValue: tx.date)
        _note = State(initialValue: tx.note ?? "")
        _taxText = State(initialValue: tx.taxCents.map(EditTransactionView.toMoneyString) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $typeRaw) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Amount") {
                    TextField("0.00", text: $amountText)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif

                    TextField("Tax (optional)", text: $taxText)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select…").tag(Optional<Category>.none)
                        ForEach(categories) { c in
                            Text(c.name).tag(Optional(c))
                        }
                    }
                }

                if typeRaw == "income" {
                    Section("Source (optional)") {
                        Picker("Source", selection: $selectedSource) {
                            Text("None").tag(Optional<Source>.none)
                            ForEach(sources) { s in
                                Text(s.name).tag(Optional(s))
                            }
                        }
                    }
                }

                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section("Note") {
                    TextField("Comment", text: $note)
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var canSave: Bool {
        parseCents(from: amountText) != nil && selectedCategory != nil
    }

    private func save() {
        guard let category = selectedCategory else {
            showErrorMessage("Please select a category.")
            return
        }
        guard let amountCents = parseCents(from: amountText) else {
            showErrorMessage("Invalid amount.")
            return
        }

        let taxCents = parseCents(from: taxText)

        // Обновляем существующий объект (SwiftData это отслеживает)
        tx.typeRaw = typeRaw
        tx.amountCents = amountCents
        tx.date = date
        tx.category = category
        tx.source = (typeRaw == "income") ? selectedSource : nil
        tx.taxCents = taxCents
        tx.note = note.trimmed.isEmpty ? nil : note.trimmed
        tx.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            showErrorMessage("Save failed: \(error.localizedDescription)")
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
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
        return NSDecimalNumber(decimal: centsDecimal).rounding(accordingToBehavior: nil).intValue
    }

    static func toMoneyString(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
