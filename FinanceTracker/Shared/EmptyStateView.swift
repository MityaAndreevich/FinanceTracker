//
//  EmptyStateView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 20.01.2026.
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(.vertical, 16)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "tray",
        title: "No transactions yet",
        message: "Add your first income or expense to see analytics and dashboard insights."
    )
}
