//
//  EmptyStateView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 20.01.2026.
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(.vertical, 16)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Empty State (localized keys)") {
    EmptyStateView(
        systemImage: "tray",
        title: "empty.noTransactions",
        message: "empty.addFirstTransaction"
    )
    .padding()
}
