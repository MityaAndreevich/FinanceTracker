//
//  CategoryAttribution.swift
//  FinanceTracker
//
//  THE single source of truth for "which categories does this purchase's money
//  belong to" (design doc §2.3). Every category-dimension aggregation — both
//  donuts, the widget's top categories, the category drill-down, the day sheet,
//  category limits — must consume `shares(for:)` / `rows(...)` and never read
//  `tx.category` + `tx.amountCents` directly. Category-BLIND aggregations
//  (month totals, safe-to-spend, pace, time series, counts) must keep summing
//  the parent transaction and must never be routed through these rows: summing
//  parents AND split rows double-counts every split purchase. The SplitCanary
//  tests exist to fail loudly if either side of that contract is broken.
//
//  Attribution rules (remainder model, §2.2):
//    • no splits            → one share: (total, parent category)
//    • splits               → one share per split (split category, falling back
//                             to the parent's category when the split's category
//                             is nil — deleted or not-yet-synced), plus a
//                             remainder share (total − Σ splits, parent
//                             category) when the remainder is > 0
//    • over-sum (transient  → splits counted as stated, remainder clamped to 0.
//      two-device merge)      The editor prevents creating this locally.
//
//  Invariant: Σ shares == max(total, Σ splits) — equal to the parent total
//  whenever the editor's Σ splits ≤ total invariant holds.
//

import Foundation
import SwiftData

enum CategoryAttribution {

    // MARK: - Pure core (no SwiftData)

    /// One category-attributed piece of one purchase.
    struct Row: Equatable, Sendable {
        let amountCents: Int      // > 0
        let categoryUUID: UUID?   // nil = uncategorized bucket
        let date: Date            // always the PARENT's date
        let isIncome: Bool        // always the PARENT's direction
    }

    /// A split as the pure layer sees it — lets the arithmetic be tested
    /// without a ModelContainer (same pattern as SafeToSpend.Entry).
    struct SplitInput: Equatable, Sendable {
        let amountCents: Int
        let categoryUUID: UUID?
    }

    /// Decompose one purchase into category-attributed rows. Pure.
    static func rows(
        totalCents: Int,
        parentCategoryUUID: UUID?,
        date: Date,
        isIncome: Bool,
        splits: [SplitInput]
    ) -> [Row] {
        // Non-positive split amounts carry no money and are defensively ignored
        // (the editor forbids them; a sync merge should never produce them).
        let effective = splits.filter { $0.amountCents > 0 }

        guard !effective.isEmpty else {
            // Today's behavior, exactly: the whole purchase in the parent's category.
            guard totalCents > 0 else { return [] }
            return [Row(amountCents: totalCents,
                        categoryUUID: parentCategoryUUID,
                        date: date,
                        isIncome: isIncome)]
        }

        var out: [Row] = effective.map { split in
            Row(amountCents: split.amountCents,
                // nil split category (deleted / not yet synced) falls back to
                // the purchase's own category — money never silently vanishes
                // into a bucket the user can't see.
                categoryUUID: split.categoryUUID ?? parentCategoryUUID,
                date: date,
                isIncome: isIncome)
        }

        let assigned = effective.reduce(0) { $0 + $1.amountCents }
        let remainder = max(0, totalCents - assigned)   // over-sum rule: clamp, never scale
        if remainder > 0 {
            out.append(Row(amountCents: remainder,
                           categoryUUID: parentCategoryUUID,
                           date: date,
                           isIncome: isIncome))
        }
        return out
    }

    // MARK: - Model adapter

    /// One attributed share with the resolved Category object (what the view
    /// layer needs for name/color/symbol). nil category = uncategorized.
    struct AttributedShare {
        let amountCents: Int
        let category: Category?
    }

    /// The model-level decomposition every category-dimension consumer uses.
    ///
    /// A transaction without splits yields exactly one share — byte-for-byte
    /// today's (amount, category) pair — so pre-split stores and non-splitting
    /// users see zero behavioral change.
    ///
    /// NOTE (build order, §13): the split branch lands together with the
    /// `TransactionSplit` entity; until then every transaction is unsplit and
    /// this is exactly the pre-split identity decomposition. The SplitCanary
    /// suite pins that identity from day one.
    static func shares(for tx: Transaction) -> [AttributedShare] {
        [AttributedShare(amountCents: tx.amountCents, category: tx.category)]
    }

    /// Same decomposition as pure rows (for arithmetic-only consumers).
    static func rows(for tx: Transaction) -> [Row] {
        shares(for: tx).map {
            Row(amountCents: $0.amountCents,
                categoryUUID: $0.category?.uuid,
                date: tx.date,
                isIncome: tx.isIncome)
        }
    }
}
