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

            // Подсказка про redeem имеет смысл только когда есть подписки/коды
            if pm.hasSubscriptionProducts {
                Section {
                    Text("premium.redeem_hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)   // Bug 10: full wrap for longer RU/UK copy
                }
            }
        }
        .navigationTitle("settings.premium")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }
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

    private func redeemOfferCode() {
        guard let scene = activeWindowScene else { return }

        if #available(iOS 18.0, *) {
            Task { try? await AppStore.presentOfferCodeRedeemSheet(in: scene) }
        } else {
            // iOS 14–17 fallback (deprecated, but works)
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
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
