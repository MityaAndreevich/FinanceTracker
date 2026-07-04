//
//  CategoryTileRow.swift
//  FinanceTracker
//
//  Redesigned transaction row (DESIGN_DIRECTION_v2 §3): a 36pt colored category
//  icon tile + merchant + "category · account" + amount. Amount uses the
//  directional money color (device QA round 1 #6): income in `bcPositive` (green),
//  expense in a calm coral (`bcDanger` via `Color.moneyDirectional`) — not the
//  earlier neutral `bcTextPrimary`, which made expenses read as inert next to green
//  income. Calm coral, not alarm red. The explicit +/− sign stays the
//  color-blind-safe cue, so color is a reinforcing accent, not the sole signal.
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
                // Directional money color (device QA round 1 #6): income green,
                // expense a calm coral (bcDanger) — NOT the neutral white it rendered
                // as before, which made expenses read as inert. Calm coral, not alarm
                // red; the explicit +/- sign remains the color-blind-safe cue.
                .foregroundStyle(Color.moneyDirectional(isPositive: tx.isIncome))
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
