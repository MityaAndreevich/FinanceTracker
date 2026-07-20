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

    /// Gross expense of the given (already month-scoped) transactions.
    static func expenseCents(_ transactions: [Transaction]) -> Int {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }
    }

    /// Gross income of the given (already month-scoped) transactions.
    static func incomeCents(_ transactions: [Transaction]) -> Int {
        transactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCents }
    }
}
