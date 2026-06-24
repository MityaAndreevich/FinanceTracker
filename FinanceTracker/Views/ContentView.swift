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

    @State private var selectedTab: Int = 0
    @State private var showAddSheet: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("tab.dashboard", systemImage: "house") }
            .tag(0)

            NavigationStack {
                TransactionsView()
            }
            .tabItem { Label("tab.transactions", systemImage: "list.bullet") }
            .tag(1)

            // Center tab: tapping triggers Add sheet rather than navigating.
            // Per Apple HIG: "Use a tab bar to support navigation, not to provide actions."
            Color.clear
                .tabItem { Image(systemName: "plus.circle.fill") }
                .tag(2)

            NavigationStack {
                AnalyticsView()
            }
            .tabItem { Label("tab.analytics", systemImage: "chart.pie") }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab.settings", systemImage: "gear") }
            .tag(4)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 2 {
                showAddSheet = true
                selectedTab = oldTab   // restore: the + tab never "sticks"
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
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
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
