//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

/// Root tab view. Onboarding is gated upstream by RootView, so by the time
/// this view appears we know `hasCompletedOnboarding == true`.
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
            // --demo-mode launch arg (used by simctl during App Store screenshot capture)
            // resets all user data and seeds a deterministic, HIG-compliant dataset.
            // See DemoSeeder for the full rationale and the seed contents.
            if DemoSeeder.isDemoMode {
                DemoSeeder.resetAndSeedDemoData(modelContext: modelContext)
            } else {
                // Seed default categories on first launch. Idempotent — safe to call again.
                SeedService.seedIfNeeded(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
