//
//  CategoryBreakdown.swift
//  FinanceTracker
//
//  The ONE category fold. Until 1.0.6 the same accumulation lived three times —
//  `MonthTotals.categorySpendBuckets` (guarded), `AnalyticsView.recomputeBreakdown`
//  and `DaySpendingSheet.categorySlices` (both plain `+=`) — and the "Other" tail
//  fold twice more (`DashboardView.donutSlices`, `AnalyticsBreakdownView
//  .displaySlices`, both plain `reduce(0)`). Reports must equal Analytics, and a
//  fold that exists once cannot disagree with itself.
//
//  Every sum here reports overflow. Nil is the unavailable state (D5); callers
//  show it, never a wrapped, saturated or zeroed number. Note that a fold's
//  inputs can each be representable while their sum is not — the Dashboard
//  buckets fit and the Breakdown total still overflows — which is why the tail
//  fold and the total are guarded even when every bucket was.
//

import Foundation

enum CategoryBreakdown {

    /// One category's attributed money in a period. Income and expense
    /// categories carry distinct UUIDs in this taxonomy, so one uuid-keyed
    /// dictionary never merges directions.
    struct Bucket: Equatable, Sendable {
        let id: UUID
        let cents: Int
        let isIncome: Bool
    }

    /// Pure form over attribution rows (the `CategoryLimitPolicy.spentByCategory`
    /// shape). `includeIncome: false` is the Dashboard donut's expense-only view.
    static func buckets(rows: [CategoryAttribution.Row], includeIncome: Bool = true) -> [Bucket]? {
        var acc: [UUID: Bucket] = [:]
        for row in rows {
            if row.isIncome && !includeIncome { continue }
            let key = row.categoryUUID ?? CategoryAttribution.uncategorizedBucketID
            let running = acc[key]?.cents ?? 0
            let (sum, overflow) = running.addingReportingOverflow(row.amountCents)
            guard !overflow else { return nil }
            acc[key] = Bucket(id: key, cents: sum, isIncome: row.isIncome)
        }
        return Array(acc.values)
    }

    /// Model form: attributes each transaction through `CategoryAttribution.shares`
    /// and returns the category alongside the bucket so views can label it.
    /// Transactions outside `range` are skipped (nil range = all given rows).
    static func buckets(
        transactions: [Transaction],
        in range: Range<Date>? = nil,
        includeIncome: Bool = true
    ) -> [UUID: (category: Category?, cents: Int, isIncome: Bool)]? {
        var acc: [UUID: (category: Category?, cents: Int, isIncome: Bool)] = [:]
        for tx in transactions {
            if let range, !range.contains(tx.date) { continue }
            if tx.isIncome && !includeIncome { continue }
            for share in CategoryAttribution.shares(for: tx) {
                let key = share.category.bucketID
                let running = acc[key]?.cents ?? 0
                let (sum, overflow) = running.addingReportingOverflow(share.amountCents)
                guard !overflow else { return nil }
                acc[key] = (share.category, sum, tx.isIncome)
            }
        }
        return acc
    }

    /// Σ over any collection of cents. Nil on overflow.
    static func total<S: Sequence>(_ items: S, cents: (S.Element) -> Int) -> Int? {
        var acc = 0
        for item in items {
            let (sum, overflow) = acc.addingReportingOverflow(cents(item))
            guard !overflow else { return nil }
            acc = sum
        }
        return acc
    }

    /// The "Other" fold: keep the first `maxNamed` of an already-sorted list and
    /// sum the rest. Returns the input unchanged when folding would save nothing
    /// (`count <= maxNamed + 1`), the same condition every screen used before.
    /// `otherCents == 0` means no fold happened (a fold of zero is not shown).
    /// Nil on overflow of the tail.
    static func fold<T>(_ sorted: [T], maxNamed: Int, cents: (T) -> Int) -> (named: [T], otherCents: Int)? {
        guard sorted.count > maxNamed + 1 else { return (sorted, 0) }
        let named = Array(sorted.prefix(maxNamed))
        guard let tail = total(sorted.dropFirst(maxNamed), cents: cents) else { return nil }
        return (named, tail)
    }
}
