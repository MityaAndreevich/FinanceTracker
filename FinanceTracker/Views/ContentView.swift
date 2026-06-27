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

    @AppStorage("hasSeenFeatureTour") private var hasSeenFeatureTour = false
    @State private var selectedTab: Int = 0
    @State private var showAddSheet: Bool = false

    // Settings navigation is path-driven so we can pop it to root whenever the user
    // leaves the tab. Without this, a language change (AppleLanguages override +
    // appLanguageCode cascade while a sheet/alert dismisses) could leave the Settings
    // NavigationStack in a stuck transitional state — taps on the tab did nothing
    // until the user switched tabs and back. Resetting on leave gives a clean slate.
    @State private var settingsNavPath = NavigationPath()

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

            NavigationStack(path: $settingsNavPath) {
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
            // Leaving Settings: clear its navigation path so the next visit is a
            // clean root, never a stuck transitional state after a language change.
            if oldTab == 4 && newTab != 4 {
                settingsNavPath = NavigationPath()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            QuickEntryView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenFeatureTour },
            set: { _ in }
        )) {
            TutorialFlow()
        }
        .task {
            if DemoSeeder.isDemoMode {
                DemoSeeder.resetAndSeedDemoData(modelContext: modelContext)
            } else {
                SeedService.seedIfNeeded(modelContext: modelContext)
            }
            handlePendingIntentNavigation()
            RatingPromptCoordinator.recordSessionOpen()
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
