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

    // Screenshot automation: which settings-detail / paywall screen to present
    // over the tab view on launch. Stays nil in Release (set only from the
    // DEBUG-gated ScreenshotMode). See applyScreenshotRoutingIfNeeded().
    @State private var screenshotCover: ScreenshotMode.Screen?

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
        .fullScreenCover(item: $screenshotCover) { screen in
            NavigationStack { screenshotDestination(for: screen) }
        }
        .task {
            if DemoSeeder.isDemoMode {
                DemoSeeder.resetAndSeedDemoData(modelContext: modelContext)
            } else {
                SeedService.seedIfNeeded(modelContext: modelContext)
            }
            applyScreenshotRoutingIfNeeded()
            handlePendingIntentNavigation()
            RatingPromptCoordinator.recordSessionOpen()
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active { handlePendingIntentNavigation() }
        }
    }

    // MARK: - Screenshot automation routing

    /// Routes to the requested storyboard screen on launch when running under the
    /// capture script. No-op in Release (ScreenshotMode.requestedScreen is nil).
    private func applyScreenshotRoutingIfNeeded() {
        guard let screen = ScreenshotMode.requestedScreen else { return }
        switch screen {
        case .dashboard:  selectedTab = 0
        case .analytics:  selectedTab = 3   // AnalyticsView selects .breakdown itself
        case .quickentry: showAddSheet = true
        case .privacy, .categories, .export, .lifetime:
            screenshotCover = screen
        case .lock:
            break   // handled upstream by AuthGateView
        }
    }

    /// The view presented over the tab bar for settings-detail / paywall captures.
    @ViewBuilder
    private func screenshotDestination(for screen: ScreenshotMode.Screen) -> some View {
        switch screen {
        case .privacy:    PrivacySettingsView()
        case .categories: CategoriesSourcesView()
        case .export:     DataSettingsView()
        case .lifetime:   PaywallView()
        default:          EmptyView()
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
