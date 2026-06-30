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
    @State private var showRedeem = false

    var body: some View {
        let statusKey: LocalizedStringKey = pm.isPremium ? "premium.status.active" : "premium.status.free"

        return List {
            Section("premium.section.status") {
                HStack {
                    Label {
                        Text("settings.premium")
                    } icon: {
                        Image(systemName: "crown")
                    }

                    Spacer()

                    Text(statusKey)
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
                }

                // Always available — App Review redeems promo codes here to test
                // IAPs, regardless of whether products have finished loading (Bug 6).
                Button {
                    showRedeem = true
                } label: {
                    Label("premium.redeem_code", systemImage: "qrcode")
                }

                Button {
                    Task { await pm.restorePurchases() }
                } label: {
                    Label("premium.restore", systemImage: "arrow.clockwise")
                }
            }

            // Shown alongside the always-available Redeem Code button (Bug 6).
            Section {
                Text("premium.redeem_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)   // Bug 10: full wrap for longer RU/UK copy

                #if DEBUG
                // Bug 6 (device test #5): the Redeem sheet's input is disabled when
                // the app runs against the local FinanceTracker.storekit config —
                // Apple's local StoreKit environment can't redeem offer codes. The
                // binding/availability are correct; the real test path is a
                // TestFlight/App Store build. DEBUG-only so users never see this.
                Text("premium.redeem.debug_hint")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
        }
        .navigationTitle("settings.premium")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        // iOS 16+ native redemption sheet — functional text field + button,
        // unlike the scene-based presentCodeRedemptionSheet path (Bug 6).
        .offerCodeRedemption(isPresented: $showRedeem) { result in
            switch result {
            case .success:
                Task { await pm.refreshStatus() }
            case .failure(let error):
                #if DEBUG
                print("Offer code redemption failed: \(error.localizedDescription)")
                #endif
            }
        }
        .task {
            // При заходе на экран — перечитать entitlement
            await pm.refreshStatus()
        }
    }

    // MARK: - Manage subscription

    private func openManageSubscriptions() {
        guard let scene = activeWindowScene else { return }
        Task { try? await AppStore.showManageSubscriptions(in: scene) }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}
