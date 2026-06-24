//
//  QuickAddSaveService.swift
//  FinanceTracker
//
//  Single source of truth for the Quick Add save path.
//  Both DashboardView's QuickAddBar and QuickEntryView use this.
//

import Foundation
import SwiftData

enum QuickAddSaveService {
    enum SaveError: Error { case noCategoryResolvable }

    /// Creates and persists a Transaction from a parsed Quick Add input.
    /// Records merchant→category learning via MerchantLearningService.
    static func save(
        parsed: QuickAddParsedInput,
        modelContext: ModelContext,
        defaultCurrencyCode: String
    ) throws -> Transaction {
        guard let category = resolveCategory(for: parsed, in: modelContext) else {
            throw SaveError.noCategoryResolvable
        }

        let tx = Transaction(
            typeRaw: parsed.typeRaw,
            amountCents: parsed.amountCents,
            currency: defaultCurrencyCode,
            date: .now,
            category: category,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: parsed.merchant,
            recurrenceRaw: nil
        )
        modelContext.insert(tx)
        try modelContext.save()

        MerchantLearningService.record(
            merchant: parsed.merchant,
            categoryName: category.name,
            in: modelContext
        )

        return tx
    }

    /// Priority: learned merchant mapping → parser suggestion → category named "Other".
    static func resolveCategory(for parsed: QuickAddParsedInput, in context: ModelContext) -> Category? {
        let suggestedName = parsed.merchant.flatMap {
            CategorySuggestionService.suggest(forMerchant: $0, in: context)
        } ?? parsed.suggestedCategoryName

        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        if let name = suggestedName {
            let target = name.lowercased()
            let subset = all.filter { $0.kindRaw == parsed.typeRaw }
            if let match = subset.first(where: { cat in
                let localized = cat.nameKey.map { NSLocalizedString($0, comment: "").lowercased() }
                return cat.name.lowercased() == target
                    || cat.displayName().lowercased() == target
                    || localized == target
            }) {
                return match
            }
        }

        return all.first { $0.name == "Other" }
    }
}
