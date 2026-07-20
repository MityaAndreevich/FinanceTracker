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
//    • over-sum (only a bug → splits consume the total IN ORDER with a
//      or a future sync       running cap — truncated at the boundary, never
//      merge can create it)   scaled. The editor makes over-sum impossible to
//                             SAVE; this is the read-side guarantee on top.
//
//  Invariant: Σ shares == parent total, ALWAYS — including over-sum input.
//  Category totals can therefore never disagree with the grand total.
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

        // EXACT CONSERVATION: Σ rows == totalCents, always — including the
        // over-sum state (Σ splits > total) that only a bug or a future sync
        // merge could produce. Splits consume the total in order with a
        // running cap, so an over-sum is truncated at the boundary rather
        // than over-counting category totals against the grand total. The
        // editor independently makes over-sum impossible to SAVE; this is the
        // read-side guarantee that the numbers cannot lie even if bad data
        // arrives anyway.
        var out: [Row] = []
        var budget = max(0, totalCents)
        for split in effective {
            guard budget > 0 else { break }
            let take = min(split.amountCents, budget)
            budget -= take
            // nil split category (deleted / not yet synced) falls back to
            // the purchase's own category — money never silently vanishes
            // into a bucket the user can't see.
            out.append(Row(amountCents: take,
                           categoryUUID: split.categoryUUID ?? parentCategoryUUID,
                           date: date,
                           isIncome: isIncome))
        }
        if budget > 0 {
            out.append(Row(amountCents: budget,
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
    /// the pre-split (amount, category) pair — so existing stores and
    /// non-splitting users see zero behavioral change.
    static func shares(for tx: Transaction) -> [AttributedShare] {
        let splits = orderedSplits(of: tx)
        guard !splits.isEmpty else {
            return [AttributedShare(amountCents: tx.amountCents, category: tx.category)]
        }

        // Same exact-conservation walk as the pure core: Σ shares ==
        // tx.amountCents always, over-sum truncated at the boundary.
        var out: [AttributedShare] = []
        var budget = max(0, tx.amountCents)
        for split in splits {
            guard budget > 0 else { break }
            let take = min(split.amountCents, budget)
            budget -= take
            // nil split category (deleted / not yet synced) falls back to the
            // purchase's own category — money never silently vanishes.
            out.append(AttributedShare(amountCents: take,
                                       category: split.category ?? tx.category))
        }
        if budget > 0 {
            out.append(AttributedShare(amountCents: budget, category: tx.category))
        }
        return out
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

    /// The parent's splits in stable display order, with non-positive amounts
    /// defensively dropped. The single choke point so every consumer agrees on
    /// ordering and validity; nil and empty `splits` are equivalent here.
    static func orderedSplits(of tx: Transaction) -> [TransactionSplit] {
        (tx.splits ?? [])
            .filter { $0.amountCents > 0 }
            .sorted { $0.order < $1.order }
    }

    /// Whether the purchase carries any effective split.
    static func isSplit(_ tx: Transaction) -> Bool {
        !orderedSplits(of: tx).isEmpty
    }
}
