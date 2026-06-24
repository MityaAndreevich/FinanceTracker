//
//  RootView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false

    var body: some View {
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
