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
                    Label("General", systemImage: "slider.horizontal.3")
                }

                NavigationLink {
                    PremiumSettingsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)

                        Text("Premium")

                        Spacer()

                        Text(pm.isPremium ? "Active" : "Free")
                            .font(.subheadline)
                            .foregroundStyle(pm.isPremium ? .green : .secondary)
                    }
                }

                NavigationLink {
                    DataSettingsView()
                } label: {
                    Label("Data", systemImage: "externaldrive")
                }

                NavigationLink {
                    CategoriesSourcesView()
                } label: {
                    Label("Categories & Sources", systemImage: "square.grid.2x2")
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}

