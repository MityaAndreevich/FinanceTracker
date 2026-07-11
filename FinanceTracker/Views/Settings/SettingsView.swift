//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var pm = PurchaseManager.shared
    @StateObject private var access = AccessManager.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    Label("settings.general", systemImage: "slider.horizontal.3")
                }

                NavigationLink {
                    PremiumSettingsView()
                } label: {
                    premiumRow
                }

                NavigationLink {
                    DataSettingsView()
                } label: {
                    Label("settings.data", systemImage: "externaldrive")
                }

                NavigationLink {
                    CategoriesSourcesView()
                } label: {
                    Label("settings.categories", systemImage: "square.grid.2x2")
                }

                NavigationLink {
                    RecurringSettingsView()
                } label: {
                    Label("settings.recurring", systemImage: "arrow.triangle.2.circlepath")
                }

                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    Label("settings.privacy", systemImage: "lock.shield")
                }
            }

            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("settings.help", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    AboutView()
                } label: {
                    Label("settings.about", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("settings.title")
        .listStyle(.insetGrouped)
        .task {
            // Гарантируем актуальный статус, если вернулись с paywall/restore.
            await pm.refreshStatus()
        }
        // Re-localize the row labels live on an in-app language change (device QA
        // round 1 #2) without popping the Settings navigation stack.
        .languageReactive()
    }

    private var premiumRow: some View {
        let status = premiumStatusText

        return HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .foregroundStyle(.yellow)

            Text("settings.premium")

            Spacer()

            Text(status)
                .font(.subheadline)
                .foregroundStyle(access.isPremium ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("settings.premium"))
        .accessibilityValue(Text(status))
    }

    /// Paid, on the reverse trial (with days left), or free.
    private var premiumStatusText: String {
        if access.hasPaidEntitlement {
            return NSLocalizedString("premium.status.active", comment: "")
        }
        if access.isReverseTrialActive {
            return String(format: NSLocalizedString("premium.status.trial.format", comment: ""),
                          access.trialDaysRemaining)
        }
        return NSLocalizedString("premium.status.free", comment: "")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
