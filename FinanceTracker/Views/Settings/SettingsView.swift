//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var pm = PurchaseManager.shared

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
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("settings.about", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("settings.title")
        .listStyle(.insetGrouped)
    }

    private var premiumRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .foregroundStyle(.yellow)

            Text("settings.premium")

            Spacer()

            Text(pm.isPremium ? "premium.status.active" : "premium.status.free")
                .font(.subheadline)
                .foregroundStyle(pm.isPremium ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("settings.premium"))
        .accessibilityValue(Text(pm.isPremium ? "premium.status.active" : "premium.status.free"))
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
