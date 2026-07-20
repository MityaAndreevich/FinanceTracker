//
//  Category+Fallback.swift
//  FinanceTracker
//
//  The nil-category presentation contract (design doc §1.4). As of V2,
//  `Transaction.category` is optional — a real, transient state once iCloud
//  ships (a Transaction record can arrive before its Category record), and the
//  post-repair state of a reference whose category was deleted pre-V2.
//
//  One rule, applied everywhere via these helpers so no view invents its own
//  fallback: nil displays as localized "Uncategorized" with a neutral glyph,
//  and aggregations bucket it under one stable reserved UUID. NEVER
//  force-unwrap `tx.category` — nil is normal, not corruption.
//

import SwiftUI

extension CategoryAttribution {
    /// The stable aggregation bucket for nil-category money. A reserved
    /// constant (not a random UUID) so every grouping — donuts, drill-downs,
    /// day sheets — agrees on the bucket across recomputes and processes.
    static let uncategorizedBucketID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

extension Optional where Wrapped == Category {

    /// Display name with the localized "Uncategorized" fallback. Mirrors
    /// `Category.displayName(locale:)`.
    func displayNameOrFallback(locale: Locale = .current) -> String {
        switch self {
        case .some(let category): return category.displayName(locale: locale)
        case .none: return NSLocalizedString("category.uncategorized", comment: "")
        }
    }

    /// Same, resolved against an explicit `.lproj` bundle (in-app language
    /// override / widget-snapshot baking). Mirrors `Category.displayName(bundle:)`.
    func displayNameOrFallback(bundle: Bundle) -> String {
        switch self {
        case .some(let category): return category.displayName(bundle: bundle)
        case .none:
            return bundle.localizedString(forKey: "category.uncategorized",
                                          value: "Uncategorized", table: nil)
        }
    }

    /// Neutral glyph for the nil bucket.
    var symbolNameOrFallback: String {
        self?.symbolName ?? "tray"
    }

    /// Neutral gray for the nil bucket — deliberately not a theme hue.
    var themeColorOrFallback: Color {
        self?.themeColor ?? Color.gray
    }

    /// The aggregation key: the category's uuid, or the reserved bucket.
    var bucketID: UUID {
        self?.uuid ?? CategoryAttribution.uncategorizedBucketID
    }
}
