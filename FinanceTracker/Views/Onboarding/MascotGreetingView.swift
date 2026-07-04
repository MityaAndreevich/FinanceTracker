//
//  MascotGreetingView.swift
//  FinanceTracker
//
//  The first-run greeting (Brief 28 Part B): a single small card on a dimmed
//  backdrop — Budget Crab + one privacy line + Show me / Skip. Not a carousel.
//
//  TODO (post-launch polish): swap the reused LaunchLogo for a purpose-drawn Budget
//  Crab mascot illustration.
//

import SwiftUI

struct MascotGreetingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("onboarding.greeting.title")
                        .font(.system(size: 20, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bcTextPrimary)

                    Text("onboarding.greeting.privacy")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        coordinator.beginCoachmarks()
                    } label: {
                        Text("onboarding.greeting.cta")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.bcAccent, in: Capsule())
                    }

                    Button {
                        coordinator.skip()
                    } label: {
                        Text("onboarding.skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.bcTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.bcSurface1)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.bcDivider, lineWidth: 1))
            )
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}
