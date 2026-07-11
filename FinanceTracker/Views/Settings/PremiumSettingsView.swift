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
    @StateObject private var access = AccessManager.shared
    @State private var showPaywall = false
    @State private var showRedeem = false

    var body: some View {
        List {
            Section("premium.section.status") {
                HStack {
                    Label {
                        Text("settings.premium")
                    } icon: {
                        Image(systemName: "crown")
                    }

                    Spacer()

                    statusLabel
                }

                // Offered to trial users too — they have full access but own
                // nothing, and this is the honest place to convert them early.
                if !access.hasPaidEntitlement {
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
            await access.refreshFromStoreKit()
        }
    }

    // MARK: - Status

    /// Three honest states: bought, on the house (reverse trial, with the clock
    /// visible), or free. We never dress the trial up as a purchase.
    @ViewBuilder
    private var statusLabel: some View {
        if access.hasPaidEntitlement {
            Text("premium.status.active")
                .foregroundStyle(.green)
        } else if access.isReverseTrialActive {
            Text(String(format: NSLocalizedString("premium.status.trial.format", comment: ""),
                        access.trialDaysRemaining))
                .foregroundStyle(.green)
        } else {
            Text("premium.status.free")
                .foregroundStyle(.secondary)
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
