//
//  AddTransactionIntent.swift
//  FinanceTracker
//
//  "Hey Siri, add twelve dollars groceries in Budget Crab" → transaction saved
//  without launching the app. Reuses QuickAddSaveService so merchant
//  learning and all save side-effects fire consistently with in-app entry.
//

import AppIntents
import SwiftData

struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transaction"
    static var description = IntentDescription(
        "Quickly add a transaction with Shortcuts.",
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
        // Bug 8: a negative amount means expense; otherwise income vocabulary in
        // the merchant ("paycheck", "salary", "+…") drives the direction even when
        // the (defaulted) type parameter says expense. The amount magnitude is the
        // absolute value — the sign only conveys direction.
        let cents = Int((abs(amount) * 100).rounded())
        let merchantValue = merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let typeRawValue = Self.effectiveTypeRaw(
            explicitType: type.rawValue,
            merchant: merchantValue,
            amount: amount
        )

        // Bug 8: when the user named no category and we can't confidently guess one
        // for an expense (no keyword match), ask rather than silently defaulting —
        // App Intents resolves the parameter interactively.
        var chosenCategory = category
        if chosenCategory == nil,
           typeRawValue == TransactionType.expense.raw,
           merchantValue.flatMap({ CategorySuggestionService.suggest(forMerchant: $0) }) == nil {
            chosenCategory = try? await $category.requestValue(IntentDialog("Which category?"))
        }
        let categoryID = chosenCategory?.id

        // Run SwiftData work on the main actor, then return the entity to the caller.
        let entity: TransactionEntity = try await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            let currencyCode = UserDefaults.appGroup.string(forKey: "defaultCurrencyCode") ?? "USD"
            let all = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []

            func category(named name: String, kind: String? = nil) -> Category? {
                if let kind {
                    if let m = all.first(where: { $0.name == name && $0.kindRaw == kind }) { return m }
                }
                return all.first { $0.name == name }
            }

            // Resolve the category deterministically: explicit pick → income's
            // dedicated "Income" → merchant keyword suggestion → "Other". Never
            // borrow an unrelated default (Bug 8).
            let resolvedCategory: Category = try {
                if let cid = categoryID, let cat = all.first(where: { $0.uuid == cid }) {
                    return cat
                }
                if typeRawValue == TransactionType.income.raw,
                   let income = category(named: "Income", kind: TransactionType.income.raw) {
                    return income
                }
                if typeRawValue == TransactionType.expense.raw,
                   let m = merchantValue,
                   let suggested = CategorySuggestionService.suggest(forMerchant: m),
                   let cat = category(named: suggested, kind: TransactionType.expense.raw) {
                    return cat
                }
                if let other = category(named: "Other", kind: typeRawValue) ?? category(named: "Other") {
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

            // Pass the resolved category as an override so the save path uses it
            // verbatim (honoring an explicit pick / our income logic) instead of
            // re-running merchant suggestion.
            let tx = try QuickAddSaveService.save(
                parsed: parsed,
                modelContext: ctx,
                defaultCurrencyCode: currencyCode,
                overrideCategory: resolvedCategory
            )

            return TransactionEntity(from: tx)
        }

        // This write just changed the spend, so any pending proactive alert now carries a
        // stale number. Cancel it rather than reschedule: an intent runs out-of-process,
        // without the app's LocalizedBundle swizzle, so scheduling here could also emit
        // the notification in the wrong language — the same Bundle.main trap the widget
        // hit. The app re-creates it correctly on next foreground.
        //
        // A missed low-stakes nudge beats a wrong one on a money app.
        ProactiveAlertScheduler.cancel()

        return .result(value: entity)
    }

    /// Direction for an intent invocation: an explicit `income` pick wins; a
    /// negative amount is always an expense; otherwise income vocabulary in the
    /// merchant promotes a defaulted expense to income (Bug 8). Pure + testable.
    static func effectiveTypeRaw(explicitType: String, merchant: String?, amount: Double) -> String {
        if explicitType == TransactionType.income.raw { return TransactionType.income.raw }
        if amount < 0 { return TransactionType.expense.raw }
        if let merchant, QuickAddParser.isIncome(merchant) { return TransactionType.income.raw }
        return TransactionType.expense.raw
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
