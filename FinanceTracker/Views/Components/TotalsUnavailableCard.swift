//
//  TotalsUnavailableCard.swift
//  FinanceTracker
//
//  The "this total cannot be shown" state, extracted from DashboardView so that
//  Analytics and Reports render the SAME card with the SAME sentence. It is
//  deliberately not a number: a zero or a clamped ceiling here is a plausible
//  wrong figure, the defect D5 exists to remove.
//
//  The copy is a CLAIM (ARCHITECTURE.md): "Nothing has been lost" is verifiable
//  and true — the rows are still in the store; only their sum is not.
//

import SwiftUI

struct TotalsUnavailableCard: View {
    /// `dashboard.totals_unavailable.*` says "this month"; every other surface
    /// uses the period-neutral `totals_unavailable.*` pair.
    var titleKey: LocalizedStringKey = "totals_unavailable.title"
    var bodyKey: LocalizedStringKey = "totals_unavailable.body"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.bcWarning)
                Text(titleKey)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bcTextPrimary)
            }
            Text(bodyKey)
                .font(.system(size: 14))
                .foregroundStyle(Color.bcTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bcCard(padding: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("totals_unavailable_card")
    }
}
