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

    private var tileColor: Color { tx.category.themeColorOrFallback }

    var body: some View {
        HStack(spacing: 12) {
            // Colored category icon tile
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tileColor.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: tx.category.symbolNameOrFallback)
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

                // Only flagged rows grow a third line. Before v1.0.2 the
                // possible-duplicate decision lived only in the import summary, so a
                // re-imported foreign CSV left duplicate rows the user could see but
                // never identify. The badge is where that decision becomes findable.
                if tx.isPossibleDuplicate {
                    DuplicateBadge()
                        .padding(.top, 2)
                }
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
        .accessibilityLabel(accessibilityDescription)
    }

    /// The row combines its children, so the badge's own label would be swallowed —
    /// the duplicate state has to be spoken here or VoiceOver users lose it
    /// entirely (icon+label+voice, never hue alone).
    private var accessibilityDescription: Text {
        let base = Text(primaryTitle)
            + Text(", ")
            + Text(tx.isIncome ? "analytics.label.income" : "analytics.label.expense")
            + Text(", ")
            + Text(Money.format(cents: tx.amountCents, currencyCode: tx.currency))

        guard tx.isPossibleDuplicate else { return base }
        return base + Text(", ") + Text("transactions.duplicate.badge")
    }

    private var primaryTitle: String {
        let merchant = (tx.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return tx.category.displayNameOrFallback()
    }

    private var subtitle: String {
        // A split purchase's subtitle names ALL its categories — the row is
        // one purchase (ledger rule), the subtitle is where its multi-category
        // nature shows (A4/A7 companion; the detail view has the amounts).
        let category: String
        if CategoryAttribution.isSplit(tx) {
            var names: [String] = []
            for share in CategoryAttribution.shares(for: tx) {
                let name = share.category.displayNameOrFallback()
                if !names.contains(name) { names.append(name) }
            }
            category = names.joined(separator: " + ")
        } else {
            category = tx.category.displayNameOrFallback()
        }
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
