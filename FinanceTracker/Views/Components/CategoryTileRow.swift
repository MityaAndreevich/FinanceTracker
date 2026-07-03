//
//  CategoryTileRow.swift
//  FinanceTracker
//
//  Redesigned transaction row (DESIGN_DIRECTION_v2 §3): a 36pt colored category
//  icon tile + merchant + "category · account" + amount. Expenses render in
//  `bcTextPrimary` (NOT red); income renders in `bcPositive`. The explicit +/−
//  sign is the color-blind-safe cue, so color is decorative only.
//
//  Reusable — the Dashboard "this week" list uses it now; Transactions adopts it
//  in Phase 2.
//

import SwiftUI

struct CategoryTileRow: View {
    let tx: Transaction

    private var tileColor: Color { tx.category.themeColor }

    var body: some View {
        HStack(spacing: 12) {
            // Colored category icon tile
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tileColor.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: tx.category.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tileColor)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bcTextPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bcTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(signedAmount)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tx.isIncome ? Color.bcPositive : Color.bcTextPrimary)
                .privacySensitive(true)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(primaryTitle)
            + Text(", ")
            + Text(tx.isIncome ? "analytics.label.income" : "analytics.label.expense")
            + Text(", ")
            + Text(Money.format(cents: tx.amountCents, currencyCode: tx.currency))
        )
    }

    private var primaryTitle: String {
        let merchant = (tx.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return tx.category.displayName()
    }

    private var subtitle: String {
        let category = tx.category.displayName()
        if let source = tx.source?.name.trimmingCharacters(in: .whitespaces), !source.isEmpty {
            return "\(category) · \(source)"
        }
        return category
    }

    private var signedAmount: String {
        Money.formatSigned(
            cents: tx.amountCents,
            isPositive: tx.isIncome,
            currencyCode: tx.currency
        )
    }
}
