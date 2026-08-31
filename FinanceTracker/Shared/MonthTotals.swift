//
//  MonthTotals.swift
//  FinanceTracker
//
//  The Dashboard's gross month totals, extracted (design doc §8.1) so the
//  SplitCanary suite pins the PRODUCTION formula instead of a copy.
//
//  ⚠️ CATEGORY-BLIND BY DESIGN — parent transactions only. These sums must
//  never be routed through CategoryAttribution rows: summing parents AND split
//  rows double-counts every split purchase. Canary:
//  SplitCanaryTests.monthTotalsAreUnchangedBySplitting (design doc §8.2 C2).
//

import Foundation

enum MonthTotals {

    /// Gross expense of the given (already month-scoped) transactions, or nil when
    /// the total cannot be represented in `Int`.
    ///
    /// nil is not "zero" and not "very large". A total that cannot be represented
    /// is not a total, and the only honest thing to do with it is say so — which
    /// is the same rule import now follows for an amount it cannot read. Wrapping
    /// (`&+`) or saturating at `Int.max` would hand the dashboard a plausible
    /// wrong number, and widening to a bigger integer only moves the cliff.
    ///
    /// Before this returned an optional, `reduce(0, +)` TRAPPED here, and because
    /// the dashboard is tab 0 and `selectedTab` is not persisted, that trap made
    /// the app unlaunchable — the user could not reach any screen from which to
    /// delete the row that caused it. Reproduced end to end in
    /// ImportOverflowChainTests.
    static func expenseCents(_ transactions: [Transaction]) -> Int? {
        sum(transactions.filter { !$0.isIncome })
    }

    /// Gross income of the given (already month-scoped) transactions, or nil when
    /// the total cannot be represented in `Int`.
    static func incomeCents(_ transactions: [Transaction]) -> Int? {
        sum(transactions.filter { $0.isIncome })
    }

    /// Month-to-date spend per category bucket, over ATTRIBUTION shares, or nil
    /// when a bucket cannot be summed in `Int`.
    ///
    /// This lived inline in `DashboardView.monthCategorySpendPass` and was the
    /// site that three separate greps missed — it reads `running + share.amount`
    /// `Cents`, matching neither `+=` nor `reduce(0`. It is here so that every
    /// money sum the launch screen performs is in one file, findable by anyone
    /// looking for them, and testable without rendering a view.
    static func categorySpendBuckets(_ transactions: [Transaction]) -> [UUID: (Category?, Int)]? {
        var byBucket: [UUID: (Category?, Int)] = [:]
        for tx in transactions where !tx.isIncome {
            for share in CategoryAttribution.shares(for: tx) {
                let key = share.category.bucketID
                let running = byBucket[key]?.1 ?? 0
                let (sum, overflow) = running.addingReportingOverflow(share.amountCents)
                guard !overflow else { return nil }
                byBucket[key] = (share.category, sum)
            }
        }
        return byBucket
    }

    private static func sum(_ transactions: [Transaction]) -> Int? {
        var total = 0
        for tx in transactions {
            let (next, overflow) = total.addingReportingOverflow(tx.amountCents)
            guard !overflow else { return nil }
            total = next
        }
        return total
    }
}
