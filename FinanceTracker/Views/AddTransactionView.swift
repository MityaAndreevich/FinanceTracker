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

    // Settings (будем управлять из Settings → General позже)
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    // SwiftData
    @Query(sort: \Category.order, order: .forward) private var categories: [Category]
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    // UI state
    @State private var typeRaw: String = "expense"      // "expense" or "income"
    @State private var amountText: String = ""
    @State private var merchantText: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSource: Source?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var taxText: String = ""

    @State private var errorMessage: String?
    @State private var showError: Bool = false

    // MARK: - Computed

    private var filteredCategories: [Category] {
        categories.filter { $0.kindRaw == typeRaw }
    }

    private var canAdd: Bool {
        parseCents(from: amountText) != nil && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // ===== Type =====
                Section {
                    Picker("Type", selection: $typeRaw) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)
                }

                // ===== Amount =====
                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)

                    TextField("Tax (optional)", text: $taxText)
                        .keyboardType(.decimalPad)
                }

                // ===== Merchant / Title =====
                Section("Title (optional)") {
                    TextField("e.g., Starbucks, Rent, Salary", text: $merchantText)
                }

                // ===== Category =====
                Section("Category") {
                    if filteredCategories.isEmpty {
                        Text(typeRaw == "income"
                             ? "No income categories yet. Add one in Settings."
                             : "No expense categories yet. Add one in Settings.")
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

                // ===== Source =====
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

                // ===== Date =====
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                // ===== Note =====
                Section("Note (optional)") {
                    TextField("Comment", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("title.add")
            .toolbar {
                // Cancel (если экран будет открыт модально)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        hideKeyboard()
                        dismiss()
                    }
                }

                // Hide keyboard (decimalPad без кнопки Done)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hide Keyboard") {
                        hideKeyboard()
                    }
                }

                // Add (нативно вместо Save)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        add()
                    }
                    .disabled(!canAdd)
                }
            }
            .onAppear {
                ensureValidCategorySelection()
            }
            .onChange(of: typeRaw) { _, _ in
                // при смене типа — подставляем первую категорию соответствующего типа
                selectedSource = (typeRaw == "income") ? selectedSource : nil
                ensureValidCategorySelection()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Actions

    private func add() {
        hideKeyboard()

        guard let category = selectedCategory else {
            showErrorMessage("Please select a category.")
            return
        }
        guard let amountCents = parseCents(from: amountText) else {
            showErrorMessage("Invalid amount.")
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

            // лёгкий "успех" (нативно)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif

            resetFormKeepType()
        } catch {
            showErrorMessage("Save failed: \(error.localizedDescription)")
        }
    }

    private func ensureValidCategorySelection() {
        let subset = filteredCategories

        // если текущая выбранная категория не подходит по типу — сбрасываем
        if let current = selectedCategory, current.kindRaw != typeRaw {
            selectedCategory = nil
        }

        // если ничего не выбрано — ставим первую подходящую
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

        // Оставляем выбранный тип (обычно пользователь добавляет пачкой)
        // Категорию оставляем, если она всё ещё валидна
        ensureValidCategorySelection()

        // Source по UX: для income логично оставить, для expense очищаем
        if typeRaw != "income" {
            selectedSource = nil
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Парсим строку вида "12.34" в cents (1234).
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
}

#Preview {
    NavigationStack { AddTransactionView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
