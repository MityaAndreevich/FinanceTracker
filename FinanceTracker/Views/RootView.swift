//
//  RootView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    // Fresh installs follow the device setting (System). Users can pin Light / Dark
    // in Settings → General → Appearance. The paywall forces dark for a premium look.
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false

    @StateObject private var access = AccessManager.shared
    @State private var showTrialEndPaywall = false

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    // Branded splash gate. Shown on cold start while we warm up SwiftData +
    // the language bundle, then crossfades to the app. `.task` runs once per
    // RootView lifetime, so a background→resume never re-shows the splash.
    @State private var isReady = false
    @State private var splashStartTime = Date()

    var body: some View {
        ZStack {
            if isReady {
                appContent
                    .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isReady)
        .preferredColorScheme(appearanceMode.colorScheme)
        .task {
            await waitForReadiness()
            // Floor the splash at 0.8s so an instant-ready launch doesn't flicker.
            let elapsed = Date().timeIntervalSince(splashStartTime)
            let minDuration: TimeInterval = 0.8
            if elapsed < minDuration {
                try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
            }
            isReady = true
        }
    }

    /// Triggers (already-eager) warmups so the splash genuinely overlaps any
    /// deferred init: the SwiftData container and the language bundle.
    private func waitForReadiness() async {
        _ = SharedModelContainer.shared
        _ = LocalizedBundle.shared.languageCode
    }

    private var appContent: some View {
        Group {
            // Brief 28 Part E: no language/currency wall. Locale is auto-detected at
            // launch (FinanceTrackerApp.init) and the first-run experience is now the
            // in-app coach-mark flow driven by OnboardingCoordinator inside ContentView.
            AuthGateView()
        }
        .animation(.easeInOut(duration: 0.25), value: hasCompletedOnboarding)
        // T-8: cover screen before iOS takes the app-switcher snapshot.
        // .inactive fires before the snapshot; .background keeps it covered.
        .overlay {
            if showPrivacyOverlay {
                PrivacyOverlayView()
                    .transition(.opacity.animation(.easeIn(duration: 0.1)))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                showPrivacyOverlay = true
            case .active:
                showPrivacyOverlay = false
                raiseTrialEndPaywallIfNeeded()
            @unknown default:
                break
            }
        }
        .task { raiseTrialEndPaywallIfNeeded() }
        .sheet(isPresented: $showTrialEndPaywall) { PaywallView() }
    }

    /// The reverse trial's payoff moment: it lapsed, they didn't buy, so we make
    /// the case once — on the next foreground, not mid-task. `shouldShowTrialEnd
    /// Paywall` consumes the trigger, so this can never become a nag on every
    /// launch. From here on the contextual gates do the asking.
    private func raiseTrialEndPaywallIfNeeded() {
        access.refresh()
        if access.shouldShowTrialEndPaywall() {
            showTrialEndPaywall = true
        }
    }
}

#Preview { RootView() }
