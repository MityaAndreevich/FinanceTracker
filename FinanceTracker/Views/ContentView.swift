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
    @Environment(\.scenePhase) private var scenePhase

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
            QuickEntryView()
        }
        .task {
            if DemoSeeder.isDemoMode {
                DemoSeeder.resetAndSeedDemoData(modelContext: modelContext)
            } else {
                SeedService.seedIfNeeded(modelContext: modelContext)
            }
            handlePendingIntentNavigation()
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active { handlePendingIntentNavigation() }
        }
    }

    private func handlePendingIntentNavigation() {
        let defaults = UserDefaults.appGroup
        if defaults.bool(forKey: "pendingPresentQuickEntry") {
            defaults.set(false, forKey: "pendingPresentQuickEntry")
            showAddSheet = true
        }
        if defaults.bool(forKey: "pendingNavigateToAnalytics") {
            defaults.set(false, forKey: "pendingNavigateToAnalytics")
            selectedTab = 3
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
