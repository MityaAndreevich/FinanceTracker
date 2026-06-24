import Foundation
import SwiftData

/// On-device record of which category a user picked for a given merchant.
/// Used by CategorySuggestionService to personalize suggestions over time.
///
/// Privacy: NEVER leaves the device. No analytics, no sync, no export.
/// Stored in the default SwiftData container alongside Transaction/Category.
@Model
final class MerchantCategoryLearning {
    @Attribute(.unique) var merchantNormalized: String
    var categoryName: String
    var useCount: Int
    var lastUsedAt: Date

    init(merchantNormalized: String, categoryName: String, useCount: Int = 1, lastUsedAt: Date = .now) {
        self.merchantNormalized = merchantNormalized
        self.categoryName = categoryName
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }

    /// Normalize merchant string for matching: trim, lowercase, strip diacritics.
    /// Examples: "  Starbucks  " → "starbucks", "Café" → "cafe", "ПЯТЁРОЧКА" → "пятерочка"
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
           .folding(options: .diacriticInsensitive, locale: .current)
           .lowercased()
    }
}
