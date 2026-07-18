//
//  SplashView.swift
//  FinanceTracker
//
//  Post-launch branded splash. The OS launch screen (`LaunchScreen.storyboard`)
//  is static per Apple HIG; animation belongs here, in the SwiftUI layer. This
//  view mirrors that storyboard exactly — same `MascotCrab` asset, same 160×145
//  size, same `systemBackground` — so launch → splash → content introduces no
//  color flash and no jump in the mark.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.85
    @State private var rotation: Double = -4

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // Same transparent crab, at the same size, as the static launch
            // screen — so the launch → splash handoff swaps nothing but the
            // motion. (The old app-icon PNG carried a baked navy square, which
            // reappeared here one beat after the launch screen dropped it.)
            Image("MascotCrab")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 145)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .accessibilityHidden(true)
                .onAppear {
                    guard !reduceMotion else {
                        scale = 1.0
                        rotation = 0
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        scale = 1.0
                        rotation = 4
                    }
                }
        }
    }
}

#Preview { SplashView() }
