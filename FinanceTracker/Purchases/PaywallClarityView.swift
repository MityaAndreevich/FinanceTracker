//
//  PaywallClarityView.swift
//  FinanceTracker
//
//  The two pieces of the paywall that exist to *reduce anxiety* rather than sell:
//  the free-vs-Premium comparison table, and the data-safety promise beneath it.
//
//  Split out of PaywallView so it can be rendered and reviewed on its own — the
//  live paywall only presents inside a StoreKit-backed cover, which won't load
//  under `simctl`, so a self-contained view is the only way to see this layout
//  with real localized strings before shipping it.
//

import SwiftUI

struct PaywallClarityView: View {
    var body: some View {
        VStack(spacing: 20) {
            comparison
            dataSafety
        }
    }

    /// Exactly what is free and exactly what is paid, side by side.
    ///
    /// This replaced a one-sided "what Premium gives you" checklist. A checklist
    /// can only say what you *gain*, which forces the reader to infer what they
    /// lose — and users fill that gap pessimistically ("so my history goes away?").
    /// A two-column table answers the question they actually have, which is not
    /// "what do I get" but "what breaks if I don't pay". The answer is: nothing.
    ///
    /// Every cell is derived from the real gate (see `PaywallComparison`), so this
    /// table cannot advertise a limit the app doesn't enforce, or hide one it does.
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("paywall.compare.header")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    // The label column needs no header — the rows name themselves.
                    Color.clear.frame(width: 0, height: 0)

                    Text("paywall.compare.free")
                        .gridColumnAlignment(.center)
                    Text("paywall.compare.premium")
                        .gridColumnAlignment(.center)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                // Each row already speaks its own columns, so reading this header
                // aloud would just prepend "Free, Premium" to a table VoiceOver
                // never navigates cell-by-cell anyway.
                .accessibilityHidden(true)

                ForEach(PaywallComparison.rows) { row in
                    GridRow {
                        Text(LocalizedStringKey(row.labelKey))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        valueCell(row.free)
                        valueCell(row.premium)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.accessibilityLabel)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 4)
    }

    /// One cell of the comparison table.
    ///
    /// `.excluded` is a muted dash, never a red ✗: the free tier is a tier we are
    /// proud of, not a list of things the user is failing to have.
    @ViewBuilder
    private func valueCell(_ value: PaywallComparison.Value) -> some View {
        Group {
            switch value {
            case .included:
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brand)

            case .excluded:
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)

            case .unlimited:
                Image(systemName: "infinity")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brand)

            case .count(let limit):
                Text(limit, format: .number)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The sentence that decides whether a user feels safe saying no.
    ///
    /// It is not a soft reassurance we hope holds — it is a description of
    /// `FreeTierLimits`, where the caps block *adding* and nothing else. Nothing
    /// in the codebase deletes, hides or locks a user's rows when entitlement
    /// lapses, and if that ever changes, this paragraph is the thing that has
    /// become a lie and must change with it.
    private var dataSafety: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.brand)

            VStack(alignment: .leading, spacing: 4) {
                Text("paywall.data_safety.title")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("paywall.data_safety.body")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.brand.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        PaywallClarityView()
            .padding()
    }
    .preferredColorScheme(.dark)
}
