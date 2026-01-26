//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {

            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("tab.dashboard", systemImage: "house") }

            NavigationStack {
                TransactionsView()
            }
            .tabItem { Label("tab.transactions", systemImage: "list.bullet") }

            NavigationStack {
                AddTransactionView()
            }
            .tabItem { Label("tab.add", systemImage: "plus.circle.fill") }

            NavigationStack {
                AnalyticsView()
            }
            .tabItem { Label("tab.analytics", systemImage: "chart.pie") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab.settings", systemImage: "gear") }
        }
        .task {
            SeedService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
