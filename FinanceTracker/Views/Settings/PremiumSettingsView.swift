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
            Section("premium.section.status") {
                HStack {
                    Label("settings.premium", systemImage: "crown")
                    Spacer()
                    Text(pm.isPremium ? "premium.status.active" : "premium.status.free")
                        .foregroundStyle(pm.isPremium ? .green : .secondary)
                }

                if !pm.isPremium {
                    Button { showPaywall = true } label: {
                        Label("premium.upgrade", systemImage: "star.circle.fill")
                    }
                }
            }

            Section("premium.section.manage") {

                if pm.hasSubscriptionProducts {
                    Button {
                        openManageSubscriptions()
                    } label: {
                        Label("premium.manage_subscription", systemImage: "gearshape")
                    }

                    Button {
                        redeemOfferCode()
                    } label: {
                        Label("premium.redeem_code", systemImage: "qrcode")
                    }
                }

                Button {
                    Task { await pm.restorePurchases() }
                } label: {
                    Label("premium.restore", systemImage: "arrow.clockwise")
                }
            }

            Section {
                Text("premium.redeem_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.premium")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func openManageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Task { try? await AppStore.showManageSubscriptions(in: scene) }
    }

    private func redeemOfferCode() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }

        if #available(iOS 18.0, *) {
            Task { try? await AppStore.presentOfferCodeRedeemSheet(in: scene) }
        } else {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }
}
