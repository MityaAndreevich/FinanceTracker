//
//  AddTransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Достаём категории и источники из SwiftData
    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    // UI state
    @State private var typeRaw: String = "expense"      // "expense" or "income"
    @State private var amountText: String = ""          // пользователь вводит как текст
    @State private var selectedCategory: Category?
    @State private var selectedSource: Source?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var taxText: String = ""

    @State private var errorMessage: String?
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type")) {
                    Picker("Type", selection: $typeRaw) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Amount")) {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)

                    TextField("Tax (optional)", text: $taxText)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select…").tag(Optional<Category>.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                }

                // Источник имеет смысл только для доходов
                if typeRaw == "income" {
                    Section(header: Text("Source (optional)")) {
                        Picker("Source", selection: $selectedSource) {
                            Text("None").tag(Optional<Source>.none)
                            ForEach(sources) { source in
                                Text(source.name).tag(Optional(source))
                            }
                        }
                    }
                }

                Section(header: Text("Date")) {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section(header: Text("Note (optional)")) {
                    TextField("Comment", text: $note)
                }
            }
            .navigationTitle("title.add")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Если категории есть и ничего не выбрано — выбираем первую (UX лучше)
                if selectedCategory == nil {
                    selectedCategory = categories.first
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
        // Минимальная валидация
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

        let taxCents = parseCents(from: taxText) // может быть nil

        let tx = Transaction(
            typeRaw: typeRaw,
            amountCents: amountCents,
            currency: "USD",
            date: date,
            category: category,
            source: selectedSource,
            taxCents: taxCents,
            note: note.isEmpty ? nil : note,
            merchant: nil
        )

        modelContext.insert(tx)

        do {
            try modelContext.save()
            // На MVP можно просто очистить форму, чтобы добавлять следующую транзакцию
            resetForm()
        } catch {
            showErrorMessage("Save failed: \(error.localizedDescription)")
        }
    }

    private func resetForm() {
        amountText = ""
        taxText = ""
        note = ""
        date = Date()
        typeRaw = "expense"
        selectedSource = nil
        selectedCategory = categories.first
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Парсим строку вида "12.34" в cents (1234).
    /// Возвращает nil, если строка пустая или невалидная.
    private func parseCents(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Заменяем запятую на точку, чтобы "12,34" тоже работало
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")

        // Разрешаем только цифры и одну точку
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        // Decimal даёт точность (в отличие от Double)
        guard let decimal = Decimal(string: normalized) else { return nil }

        // *100 → cents
        let centsDecimal = decimal * 100
        // Округляем до ближайшего целого (на случай "12.345")
        let rounded = NSDecimalNumber(decimal: centsDecimal).rounding(accordingToBehavior: nil).intValue
        return rounded
    }
}
