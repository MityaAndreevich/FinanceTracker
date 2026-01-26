//
//  PremiumSettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import SwiftUI
import StoreKit
import UIKit

struct PremiumSettingsView: View {
    @StateObject private var pm = PurchaseManager.shared
    @State private var showPaywall = false

    var body: some View {
        List {
            Section("Status") {
                HStack {
                    Label("Premium", systemImage: "crown")
                    Spacer()
                    Text(pm.isPremium ? "Active" : "Free")
                        .foregroundStyle(pm.isPremium ? .green : .secondary)
                }

                if !pm.isPremium {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Upgrade to Premium", systemImage: "star.circle.fill")
                    }
                }
            }

            Section("Manage") {
                Button {
                    openManageSubscriptions()
                } label: {
                    Label("Manage Subscription", systemImage: "gearshape")
                }

                Button {
                    redeemOfferCode()
                } label: {
                    Label("Redeem Code", systemImage: "qrcode")
                }

                Button {
                    Task { await pm.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }

            Section {
                Text("Use “Redeem Code” if you have a promo code for Premium.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Premium")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Manage subscription

    private func openManageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Task {
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }

    private func redeemOfferCode() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        if #available(iOS 18.0, *) {
            Task {
                try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
            }
        } else {
            // iOS 14–17 fallback (deprecated, but works)
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }
}

#Preview {
    NavigationStack { PremiumSettingsView() }
}
