//
//  MascotGreetingView.swift
//  FinanceTracker
//
//  The first-run greeting (Brief 28 Part B, mascot-polish pass): the Budget Crab
//  on the app's own full-bleed surface — one privacy line + Show me / Skip. Not a
//  card floating on a scrim, and not a carousel. The crab is a transparent
//  illustration (`MascotCrab`) so it reads as part of the page, not a sticker
//  pasted onto it. Quiet Premium: one mint accent, a lot of air.
//
//  The visible content lives in `MascotGreetingContent` — a ScrollView-free subview
//  so it can be rendered directly by ImageRenderer (which reports blank through a
//  live ScrollView). The outer view owns the full-bleed surface, the scroll/centre
//  behaviour, and the appear motion.
//

import SwiftUI

struct MascotGreetingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-bleed canonical surface — opaque, so it fully covers the live
                // Dashboard this greeting is layered over (no scrim needed).
                Color.bcPage
                    .ignoresSafeArea()

                ScrollView {
                    MascotGreetingContent(
                        containerSize: geo.size,
                        onShowMe: coordinator.beginCoachmarks,
                        onSkip: coordinator.skip
                    )
                    // Fill the screen so the content centres; overflow (large Dynamic
                    // Type on a small device) scrolls instead of clipping.
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                    // Fade + scale the *content* only. The bcPage surface stays
                    // opaque from the first frame — so the Dashboard beneath never
                    // flashes through the fade, and the surface's opacity is a
                    // testable invariant (the original defect was a translucent
                    // scrim/card over the live Dashboard).
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                appeared = true
            }
        }
        .transition(.opacity)
    }
}

/// Greeting content, sized against an explicit container so the crab scales by
/// proportion of the safe area rather than a magic point value. ScrollView-free by
/// design (see file header). Actions default to no-ops so it renders standalone.
struct MascotGreetingContent: View {
    let containerSize: CGSize
    var onShowMe: () -> Void = {}
    var onSkip: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                crab

                VStack(spacing: 10) {
                    Text("onboarding.greeting.title")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        // Shrink-to-fit at accessibility Dynamic Type so a long,
                        // unbreakable title word never truncates ("Welcom…").
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.bcTextPrimary)

                    Text("onboarding.greeting.privacy")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions
                    .padding(.top, 4)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            Spacer(minLength: 0)
        }
    }

    // MARK: Crab

    /// Capped so it never dominates a large screen, and eased down at accessibility
    /// Dynamic Type sizes to leave room for the (now larger) copy.
    private var crab: some View {
        let base = min(containerSize.width, containerSize.height) * 0.42
        let capped = min(max(base, 132), 232)
        let side = dynamicTypeSize.isAccessibilitySize ? capped * 0.7 : capped

        return Image("MascotCrab")
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .background(
                // One soft mint accent behind the crab — depth, not decoration.
                // Vector radial gradient, so it never bands.
                RadialGradient(
                    colors: [Color.brand.opacity(0.16), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: side * 0.85
                )
                .frame(width: side * 2.1, height: side * 2.1)
            )
            .accessibilityHidden(true)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onShowMe) {
                Text("onboarding.greeting.cta")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.bcAccent, in: Capsule())
            }

            Button(action: onSkip) {
                Text("onboarding.skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.bcTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }
}
