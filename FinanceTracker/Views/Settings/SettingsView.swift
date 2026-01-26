//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    PremiumSettingsView()
                } label: {
                    Label("Premium", systemImage: "crown.fill")
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

