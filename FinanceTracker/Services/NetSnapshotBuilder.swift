//
//  NetSnapshotBuilder.swift
//  FinanceTracker
//
//  Builds the display-ready NetSnapshot for the Home Screen widget from the
//  current month's transactions + the user's monthly budget, and writes it to
//  the shared App Group, then nudges WidgetKit to reload. App-target only (uses
//  Money + SwiftData models).
//
//  v1.0.1 redesign: the widget leads with **Safe to spend** (gain-framed budget
//  remainder) and a spent-vs-budget ring. Every display string + fraction is
//  decided here and frozen into the snapshot so the extension stays a dumb, safe
//  renderer. Fraction/ring math lives in pure static helpers (mirrors
//  PaceMetric) so the guards are unit-testable without SwiftData.
//

import Foundation
import WidgetKit

enum NetSnapshotBuilder {

    /// Build, persist to the App Group, and reload widget timelines.
    static func updateSnapshot(transactions: [Transaction],
                               currencyCode: String,
                               monthlyBudgetCents: Int,
                               locale: Locale = .current) {
        let snapshot = build(transactions: transactions,
                             currencyCode: currencyCode,
                             monthlyBudgetCents: monthlyBudgetCents,
                             locale: locale)
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func build(transactions: [Transaction],
                      currencyCode: String,
                      monthlyBudgetCents: Int,
                      locale: Locale = .current) -> NetSnapshot {
        let scope = PeriodScope.currentMonth
        let month = scope.filter(transactions)

        let incomeCents = month.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCents }
        let expenseCents = month.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }

        func compact(_ cents: Int) -> String {
            Money.formatCompact(cents: cents, currencyCode: currencyCode, locale: locale)
        }

        // Top-3 expense categories by spend, each with its curated SF Symbol and
        // its share of this period's spend (for the mini bars).
        let grouped = Dictionary(grouping: month.filter { !$0.isIncome }) { $0.category.uuid }
        let topCategories: [NetSnapshot.Item] = grouped
            .compactMap { _, txns -> (Category, Int)? in
                guard let first = txns.first else { return nil }
                return (first.category, txns.reduce(0) { $0 + $1.amountCents })
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { category, cents in
                NetSnapshot.Item(
                    name: category.displayName(locale: locale),
                    symbol: category.symbolName,
                    amount: compact(cents),
                    fraction: categoryFraction(cents: cents, totalSpentCents: expenseCents)
                )
            }

        // Ring: spent-vs-budget, else spent-vs-income, else a neutral track.
        let ring = ringComponents(spentCents: expenseCents,
                                  budgetCents: monthlyBudgetCents,
                                  incomeCents: incomeCents)

        // Hero — gain-framed safe-to-spend when a budget exists; otherwise the
        // calm "Spent" total (never a green net that reads as a gain — QA #8).
        let heroLabel: String
        let heroAmount: String
        let heroSubtitle: String
        let heroIsAlert: Bool
        if monthlyBudgetCents > 0 {
            let remaining = monthlyBudgetCents - expenseCents
            heroIsAlert = remaining < 0
            heroLabel = String(localized: heroIsAlert ? "widget.over_budget" : "widget.safe_to_spend")
            heroAmount = compact(abs(remaining))
            heroSubtitle = String(format: String(localized: "widget.of_budget.format"),
                                  compact(monthlyBudgetCents))
        } else {
            heroIsAlert = false
            heroLabel = String(localized: "widget.hero.spent")
            heroAmount = compact(expenseCents)
            heroSubtitle = incomeCents > 0
                ? String(format: String(localized: "widget.of_earned.format"), compact(incomeCents))
                : ""
        }

        let spentText = String(format: String(localized: "widget.spent.format"), compact(expenseCents))
        let earnedText = String(format: String(localized: "widget.earned.format"), compact(incomeCents))

        return NetSnapshot(
            monthLabel: scope.label(locale: locale),
            currencyCode: currencyCode,
            heroLabel: heroLabel,
            heroAmount: heroAmount,
            heroSubtitle: heroSubtitle,
            heroIsAlert: heroIsAlert,
            ringFraction: ring.fraction,
            ringIsNeutral: ring.isNeutral,
            spentText: spentText,
            earnedText: earnedText,
            topCategories: topCategories,
            hasData: !month.isEmpty || monthlyBudgetCents > 0,
            generatedAt: Date()
        )
    }

    // MARK: - Pure guarded math (testable without SwiftData)

    /// Ring fill + whether it's a neutral (track-only) state.
    /// - budget set → spent / budget (the safe-to-spend progress).
    /// - no budget but income → spent / income (burn-through of what came in).
    /// - neither → neutral: nothing meaningful to fill against, so track only.
    /// Always finite and clamped 0…1 (guards divide-by-zero the ChartGuards way).
    static func ringComponents(spentCents: Int, budgetCents: Int, incomeCents: Int) -> (fraction: Double, isNeutral: Bool) {
        if budgetCents > 0 {
            return (clamp01(Double(spentCents) / Double(budgetCents)), false)
        }
        if incomeCents > 0 {
            return (clamp01(Double(spentCents) / Double(incomeCents)), false)
        }
        return (0, true)
    }

    /// A category's share of the period's spend, clamped and divide-by-zero safe.
    static func categoryFraction(cents: Int, totalSpentCents: Int) -> Double {
        guard totalSpentCents > 0 else { return 0 }
        return clamp01(Double(cents) / Double(totalSpentCents))
    }

    private static func clamp01(_ x: Double) -> Double {
        guard x.isFinite else { return 0 }
        return min(max(x, 0), 1)
    }
}
