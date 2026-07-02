//
//  OwnershipCloseView.swift
//  FinanceTracker
//
//  App Store storyboard slot 08 — the calm "ownership close". Replaces the mock
//  paywall (prices + CTAs) that used to fill this shelf position. Prices are
//  banned in App Store screenshots and fragile to every pricing change, and the
//  loud plan cards read off-brand against the Quiet Premium / Ruler close the
//  storyboard specifies: "calm, no price text, generous whitespace, single sage
//  accent" (see AppStore/screenshots-storyboard.md, SCREENSHOT 8).
//
//  This renders a raw, caption-free frame — the marketing caption ("Yours to
//  keep, for life") is composed later in Figma, never baked in-app. Used only
//  under the DEBUG screenshot capture; production paywall flow is untouched.
//

import SwiftUI

struct OwnershipCloseView: View {

    /// Warm cream backdrop — the storyboard's "strongest finish" for the closing
    /// frame, matching the cohesive shelf background used across the set.
    private static let cream = Color(red: 0.98, green: 0.965, blue: 0.925)

    var body: some View {
        ZStack {
            Self.cream
                .ignoresSafeArea()

            // Single sage accent: a soft radial glow lifting the mark off the
            // cream without a hard shape or gradient banding.
            RadialGradient(
                colors: [Color.brand.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 168, height: 168)
                // Source PNG is the full square app icon; clip to the iOS
                // continuous-corner squircle so it reads as the app's mark.
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                .accessibilityHidden(true)
        }
        // Presented inside ContentView's screenshot NavigationStack; hide the
        // chrome so the capture is a clean full-bleed frame.
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { OwnershipCloseView() }
