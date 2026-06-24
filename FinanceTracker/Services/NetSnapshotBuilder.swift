//
//  NetSnapshotBuilder.swift
//  FinanceTracker
//
//  Builds the display-ready NetSnapshot for the Home Screen widget from the
//  current month's transactions and writes it to the shared App Group, then
//  nudges WidgetKit to reload. App-target only (uses Money + SwiftData models).
//

import Foundation
import WidgetKit

enum NetSnapshotBuilder {

    /// Build, persist to the App Group, and reload widget timelines.
    static func updateSnapshot(transactions: [Transaction], currencyCode: String, locale: Locale = .current) {
        let snapshot = build(transactions: transactions, currencyCode: currencyCode, locale: locale)
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func build(transactions: [Transaction], currencyCode: String, locale: Locale = .current) -> NetSnapshot {
        let scope = PeriodScope.currentMonth
        let month = scope.filter(transactions)

        let incomeCents = month.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCents }
        let expenseCents = month.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }
        let netCents = incomeCents - expenseCents

        // Top-3 expense categories by spend.
        let grouped = Dictionary(grouping: month.filter { !$0.isIncome }) { $0.category.uuid }
        let topCategories: [NetSnapshot.Item] = grouped
            .compactMap { _, txns -> (String, Int)? in
                guard let first = txns.first else { return nil }
                let total = txns.reduce(0) { $0 + $1.amountCents }
                return (first.category.displayName(locale: locale), total)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { NetSnapshot.Item(name: $0.0, amount: Money.format(cents: $0.1, currencyCode: currencyCode)) }

        // Most-recent 3 transactions (any type), already sorted reverse-by-date upstream.
        let recent: [NetSnapshot.Recent] = month.prefix(3).map { tx in
            let title = (tx.merchant?.isEmpty == false) ? tx.merchant! : tx.category.displayName(locale: locale)
            return NetSnapshot.Recent(
                id: tx.uuid.uuidString,
                title: title,
                amount: Money.formatSigned(cents: tx.amountCents, isPositive: tx.isIncome, currencyCode: currencyCode),
                isIncome: tx.isIncome
            )
        }

        let sign = netCents >= 0 ? "+\u{00A0}" : "−\u{00A0}"
        let heroAmount = sign + Money.format(cents: abs(netCents), currencyCode: currencyCode)
        let spentText = String(format: String(localized: "widget.spent.format"),
                               Money.format(cents: expenseCents, currencyCode: currencyCode))
        let earnedText = String(format: String(localized: "widget.earned.format"),
                                Money.format(cents: incomeCents, currencyCode: currencyCode))

        return NetSnapshot(
            monthLabel: scope.label(locale: locale),
            netCents: netCents,
            heroAmount: heroAmount,
            spentText: spentText,
            earnedText: earnedText,
            topCategories: topCategories,
            recent: recent,
            generatedAt: Date()
        )
    }
}
