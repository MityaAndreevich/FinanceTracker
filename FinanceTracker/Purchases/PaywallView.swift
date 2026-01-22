//
//  PaywallView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 21.01.2026.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pm = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("Go Premium")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Unlock import & full export, and future power features.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(text: "Import CSV from Files")
                    FeatureRow(text: "Export all transactions")
                    FeatureRow(text: "Multi-currency & default currency (coming next)")
                    FeatureRow(text: "Recurring transactions, App Lock, OCR (v1.1)")
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                if pm.products.isEmpty {
                    ProgressView("Loading plans…")
                        .padding(.bottom, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(pm.products, id: \.id) { product in
                            Button {
                                Task { await pm.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                }
                                .padding(14)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Restore Purchases") {
                            Task { await pm.restorePurchases() }
                        }
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if let msg = pm.lastErrorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

            }
            .navigationTitle("Premium")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
}
