//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import Combine

/// Root tab view. Onboarding is gated upstream by RootView, so by the time
/// this view appears we know `hasCompletedOnboarding == true`.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // First-run coach-mark flow (Brief 28 Part B) — replaces the retired passive
    // TutorialFlow carousel. Drives greeting → Dashboard coach-marks → guided first win.
    @StateObject private var onboarding = OnboardingCoordinator()
    // Observing the shared bundle re-runs body on an in-app language change so the
    // tab-bar item labels re-localize live (device QA round 1 #2). Selection and the
    // per-tab NavigationStacks keep their identity, so nothing pops — only the labels
    // re-render. Each tab's content re-localizes via its own `.languageReactive()`.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared
    // Teach the edge-swipe affordance on the first few launches, then stop.
    @AppStorage("swipe_hint_shown_count") private var swipeHintShownCount = 0
    @State private var selectedTab: Int = 0
    @State private var showAddSheet: Bool = false
    @State private var showSwipeHint = false

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

    // Tab tags in left-to-right swipe order. The center "+" tab (tag 2) is an
    // action, not a destination, so swipe navigation skips over it: Transactions
    // (1) pages straight to Analytics (3).
    private let swipeableTabTags = [0, 1, 3, 4]

    var body: some View {
        ZStack {
            mainTabView
                // Reads the coach-mark target frames published by `.coachmarkTarget`
                // on the real Dashboard controls and resolves the active one to a rect
                // for the overlay. Only rendered during a `.coachmark` phase.
                .overlayPreferenceValue(CoachmarkAnchorKey.self) { anchors in
                    if onboarding.currentStep != nil {
                        GeometryReader { proxy in
                            CoachmarkOverlay(
                                coordinator: onboarding,
                                targetRect: onboarding.currentStep
                                    .flatMap { anchors[$0] }
                                    .map { proxy[$0] }
                            )
                        }
                        .ignoresSafeArea()
                        .zIndex(1)
                    }
                }

            // Greeting and guided-first-win phases render as their own centered cards
            // over a dim backdrop (no anchor needed).
            switch onboarding.phase {
            case .greeting:
                MascotGreetingView(coordinator: onboarding)
                    .zIndex(2)
            case .firstWin:
                FirstWinView(
                    coordinator: onboarding,
                    onAddNow: { showAddSheet = true },
                    onExploreDemo: {
                        // Guarded, reversible sandbox seed (Brief 28 Part C). Lands the
                        // user in a populated dashboard — its own aha — then ends the flow.
                        _ = try? DemoSeeder.seedOnboardingDemoGuarded(modelContext: modelContext)
                        onboarding.finishFirstWin()
                    }
                )
                .zIndex(2)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: onboarding.phase)
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
        // Active tab + the center "+" render in the brand mint (redesign v2 tokens).
        .tint(Color.bcAccent)
        // Right-edge swipe advances forward through the main tabs (skipping the
        // "+" tab), clamping at the last so the user is never disoriented by a
        // wrap. Forward-only: a left-edge back swipe was dropped because it
        // competes with the iOS system back gesture; backward navigation is
        // tap-only (canonical iOS pattern). Anchoring to the right edge keeps it
        // from competing with charts, lists, and scroll views in the content
        // area. Within Analytics the gesture is shadowed by that screen's own
        // content-wide sub-tab swipe (a descendant gesture wins), so paging out
        // of Analytics is done via the tab bar — see AnalyticsView.
        .edgeSwipeForward(
            onNext: { selectAdjacentTab(forward: true) }
        )
        .sensoryFeedback(.selection, trigger: selectedTab)
        .overlay {
            if showSwipeHint {
                EdgeSwipeHintView()
                    .transition(.opacity)
            }
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
            // testHookInput is nil in normal use; under the screenshot capture with
            // --screenshot-quickentry-parsed it preloads a locale-appropriate parsed
            // transaction so frame 03 shows the rich parsed-preview state.
            QuickEntryView(testHookInput: ScreenshotMode.quickEntryParsedInput)
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
            maybeShowSwipeHint()
            // Start the first-run coach-mark flow on a genuine first launch (or a
            // Settings replay). Suppressed under screenshot/demo automation so captures
            // aren't covered by the greeting — except the DEBUG onboarding-step hook,
            // which forces a specific phase for per-step screenshots.
            if let step = ScreenshotMode.onboardingStep {
                onboarding.startAtDebugPhase(step)
            } else if ScreenshotMode.requestedScreen == nil && !DemoSeeder.isDemoMode {
                onboarding.startIfNeeded()
            }
            #if DEBUG
            // Screenshot seam: seed the reversible onboarding demo sandbox so the
            // populated dashboard + "Demo data" banner can be captured deterministically.
            if CommandLine.arguments.contains("--seed-onboarding-demo") {
                _ = try? DemoSeeder.seedOnboardingDemoGuarded(modelContext: modelContext)
            }
            #endif
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active { handlePendingIntentNavigation() }
        }
        // App-opening intents post this right after writing their flag, so the
        // app consumes the *fresh* flag even when it's already foreground and no
        // scenePhase transition fires. Without it, "Show Spending" could land on a
        // stale Quick Entry flag left over from an earlier missed consumption.
        .onReceive(NotificationCenter.default.publisher(for: .budgetCrabPendingIntent)) { _ in
            DispatchQueue.main.async { handlePendingIntentNavigation() }
        }
        // Settings → Replay tutorial: jump to the Dashboard and re-run the coach-marks
        // (the coordinator consumes the one-shot replay flag armed by Settings).
        .onReceive(NotificationCenter.default.publisher(for: .budgetCrabReplayOnboarding)) { _ in
            selectedTab = 0
            onboarding.startIfNeeded()
        }
        // Dashboard "Recent → See all": jump to the Transactions tab (device QA round 1 #7).
        .onReceive(NotificationCenter.default.publisher(for: .budgetCrabNavigateToTransactions)) { _ in
            selectedTab = 1
        }
    }

    // MARK: - Swipe navigation

    /// Flashes the edge-swipe hint on the first few launches, then never again.
    private func maybeShowSwipeHint() {
        guard swipeHintShownCount < 3, !showSwipeHint else { return }
        swipeHintShownCount += 1
        withAnimation(.easeIn(duration: 0.4)) { showSwipeHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.5)) { showSwipeHint = false }
        }
    }

    /// Advances to the adjacent swipeable tab, clamping at the ends (no wrap).
    private func selectAdjacentTab(forward: Bool) {
        guard let index = swipeableTabTags.firstIndex(of: selectedTab) else { return }
        let target = forward ? index + 1 : index - 1
        guard swipeableTabTags.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedTab = swipeableTabTags[target]
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
        // Slot 08 renders the calm, no-price ownership close — not the mock
        // paywall. Prices are banned in screenshots and off-brand vs the Ruler
        // close; the real in-app paywall is unaffected. See OwnershipCloseView.
        case .lifetime:   OwnershipCloseView()
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
