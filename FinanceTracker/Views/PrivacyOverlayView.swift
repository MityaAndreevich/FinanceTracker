//
//  PrivacyOverlayView.swift
//  FinanceTracker
//
//  Security: T-8 — prevents the multitasking switcher from capturing a
//  screenshot of financial data by covering the window with a neutral
//  logo view before iOS takes its app-switcher snapshot.
//

import SwiftUI

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)

                Text("Budget Crab")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
