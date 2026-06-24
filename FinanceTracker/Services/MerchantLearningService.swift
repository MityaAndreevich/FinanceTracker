import Foundation
import SwiftData

/// Records and queries the user's per-merchant category choices.
/// Privacy: 100% on-device, never transmitted.
enum MerchantLearningService {

    /// Call after every successful transaction save (create or edit) where
    /// both merchant and category are non-blank.
    ///
    /// Upsert: new merchant → insert; existing merchant → increment useCount,
    /// update lastUsedAt, OVERWRITE categoryName to the latest pick.
    /// Latest-wins because a user correction is the highest-signal training
    /// data — it directly tells us our previous suggestion was wrong.
    static func record(
        merchant: String?,
        categoryName: String?,
        in context: ModelContext
    ) {
        guard let rawMerchant = merchant?.nilIfBlank,
              let categoryName = categoryName?.nilIfBlank else { return }
        let normalized = MerchantCategoryLearning.normalize(rawMerchant)
        guard !normalized.isEmpty else { return }

        do {
            let descriptor = FetchDescriptor<MerchantCategoryLearning>(
                predicate: #Predicate { $0.merchantNormalized == normalized }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.useCount += 1
                existing.lastUsedAt = .now
                existing.categoryName = categoryName
            } else {
                context.insert(MerchantCategoryLearning(
                    merchantNormalized: normalized,
                    categoryName: categoryName
                ))
            }
            try context.save()
        } catch {
            #if DEBUG
            print("[MerchantLearning] record failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Returns the user's previously-chosen category for this merchant, or nil
    /// if the merchant has never been categorized by the user.
    static func suggestedCategoryName(
        for merchant: String?,
        in context: ModelContext
    ) -> String? {
        guard let rawMerchant = merchant?.nilIfBlank else { return nil }
        let normalized = MerchantCategoryLearning.normalize(rawMerchant)
        guard !normalized.isEmpty else { return nil }

        let descriptor = FetchDescriptor<MerchantCategoryLearning>(
            predicate: #Predicate { $0.merchantNormalized == normalized }
        )
        return (try? context.fetch(descriptor).first)?.categoryName
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
