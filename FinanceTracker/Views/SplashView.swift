//
//  SplashView.swift
//  FinanceTracker
//
//  Post-launch branded splash. The OS launch screen (auto-generated, system
//  background) is static per Apple HIG; animation belongs here, in the SwiftUI
//  layer. Background is `systemBackground` so it matches the launch screen for a
//  seamless launch → splash → content transition with no color flash.
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

            Image("LaunchLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                // The source PNG is the full square app icon; clip to the iOS
                // continuous-corner squircle so it reads as the app's mark.
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
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
