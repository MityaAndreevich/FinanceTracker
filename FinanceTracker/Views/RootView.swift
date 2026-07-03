//
//  RootView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    // Dark is the default for the redesigned look (fresh installs land in dark).
    // Users can switch to System / Light in Settings → General → Appearance.
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.dark.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .dark
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
            if hasCompletedOnboarding {
                AuthGateView()
            } else {
                OnboardingView()
            }
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
            @unknown default:
                break
            }
        }
    }
}

#Preview { RootView() }
