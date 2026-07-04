//
//  FirstWinView.swift
//  FinanceTracker
//
//  The guided first-win prompt (Brief 28 Part B/C): after the coach-marks, invite the
//  user to land their first entry — the 30-90s activation moment. Two paths: add one
//  now (drops them onto the ready quick-add bar) or explore with demo data. The
//  success beat (haptic + spring + "You're set!") fires on the first REAL save via the
//  existing save path — NOT here — so the demo path lands in a populated dashboard as
//  its own aha, with no fake toast.
//
//  Demo-data action is wired in Task 3.
//

import SwiftUI

struct FirstWinView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    /// Ends onboarding and drops the user on the ready quick-add bar.
    let onAddNow: () -> Void
    /// Seeds the reversible demo sandbox and ends onboarding (wired in Task 3).
    var onExploreDemo: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("onboarding.firstwin.title")
                        .font(.system(size: 20, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bcTextPrimary)

                    Text("onboarding.firstwin.body")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        coordinator.finishFirstWin()
                        onAddNow()
                    } label: {
                        Text("onboarding.firstwin.add")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.bcAccent, in: Capsule())
                    }

                    if let onExploreDemo {
                        Button {
                            onExploreDemo()
                        } label: {
                            Text("onboarding.firstwin.demo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.bcAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.bcAccent.opacity(0.10), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.bcAccent.opacity(0.45), lineWidth: 1))
                        }
                    }

                    Button {
                        coordinator.finishFirstWin()
                    } label: {
                        Text("onboarding.firstwin.later")
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
