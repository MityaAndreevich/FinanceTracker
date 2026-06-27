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

    // Settings navigation is reset by recreating its NavigationStack whenever the
    // user leaves the tab (bumping this token changes the stack's `.id`, which pops
    // it to root). A language change (AppleLanguages override + appLanguageCode
    // cascade while a sheet/alert dismisses) could otherwise leave the stack in a
    // stuck transitional state — taps did nothing until switching tabs and back.
    //
    // We deliberately do NOT bind a `NavigationPath` here. SettingsView and HelpView
    // push with destination-based `NavigationLink`s; mixing those with a bound path
    // (which only tracks value-based links) corrupted the stack after a deep pop —
    // returning from a Help article left "General" unresponsive (Round 9 R1). A
    // plain, id-reset NavigationStack is the canonical pairing for destination links.
    @State private var settingsResetToken = UUID()

    var body: some View {
        ZStack {
            mainTabView

            // Feature tour. Rendered in-tree (not as a fullScreenCover) so its
            // opaque background covers the tab view from the very first frame —
            // a cover presents *after* appearance, which let the Dashboard flash
            // through before the tour animated up (round 8 feedback).
            if !hasSeenFeatureTour {
                TutorialFlow()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasSeenFeatureTour)
    }

    private var mainTabView: some View {
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
            .id(settingsResetToken)
            .tabItem { Label("tab.settings", systemImage: "gear") }
            .tag(4)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 2 {
                showAddSheet = true
                selectedTab = oldTab   // restore: the + tab never "sticks"
            }
            // Leaving Settings: recreate its NavigationStack so the next visit is a
            // clean root, never a stuck transitional state after a language change.
            if oldTab == 4 && newTab != 4 {
                settingsResetToken = UUID()
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
