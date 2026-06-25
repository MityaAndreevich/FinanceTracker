//
//  AddTransactionIntent.swift
//  FinanceTracker
//
//  "Hey Siri, add twelve dollars groceries in Vela" → transaction saved
//  without launching the app. Reuses QuickAddSaveService so merchant
//  learning and all save side-effects fire consistently with in-app entry.
//

import AppIntents
import SwiftData

struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transaction"
    static var description = IntentDescription(
        "Quickly add a transaction with Siri or Shortcuts.",
        categoryName: "Money"
    )

    @Parameter(
        title: "Amount",
        description: "How much did you spend or earn?",
        requestValueDialog: IntentDialog("How much?")
    )
    var amount: Double

    @Parameter(
        title: "Category",
        description: "Which category?",
        requestValueDialog: IntentDialog("Which category?")
    )
    var category: CategoryEntity?

    @Parameter(
        title: "Merchant",
        description: "Where? (optional)"
    )
    var merchant: String?

    @Parameter(
        title: "Type",
        description: "Income or expense?",
        default: TransactionTypeAppEnum.expense
    )
    var type: TransactionTypeAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) for \(\.$category)") {
            \.$merchant
            \.$type
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<TransactionEntity> {
        let cents = Int((amount * 100).rounded())
        let typeRawValue = type.rawValue
        let merchantValue = merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let categoryID = category?.id

        // Run SwiftData work on the main actor, then return the entity to the caller.
        let entity: TransactionEntity = try await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            let currencyCode = UserDefaults.appGroup.string(forKey: "defaultCurrencyCode") ?? "USD"

            let resolvedCategory: Category = try {
                if let cid = categoryID,
                   let cat = (try? ctx.fetch(FetchDescriptor<Category>(
                       predicate: #Predicate { $0.uuid == cid }
                   )))?.first {
                    return cat
                }
                if let other = (try? ctx.fetch(FetchDescriptor<Category>(
                    predicate: #Predicate { $0.name == "Other" }
                )))?.first {
                    return other
                }
                throw IntentError.custom("No categories found. Open Budget Crab to set up categories.")
            }()

            let parsed = QuickAddParsedInput(
                amountCents: cents,
                typeRaw: typeRawValue,
                merchant: merchantValue,
                suggestedCategoryName: resolvedCategory.name
            )

            let tx = try QuickAddSaveService.save(
                parsed: parsed,
                modelContext: ctx,
                defaultCurrencyCode: currencyCode
            )

            return TransactionEntity(from: tx)
        }
        return .result(value: entity)
    }
}

// MARK: - Supporting enums

enum TransactionTypeAppEnum: String, AppEnum {
    case expense
    case income

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Transaction Type")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .expense: "Expense",
        .income: "Income",
    ]
}

// MARK: - Private helpers

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

private enum IntentError: Error, LocalizedError {
    case custom(String)
    var errorDescription: String? {
        if case .custom(let msg) = self { return msg }
        return nil
    }
}
