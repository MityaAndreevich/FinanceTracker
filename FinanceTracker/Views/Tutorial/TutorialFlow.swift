//
//  TutorialFlow.swift
//  FinanceTracker
//
//  3-screen skippable feature tour shown once after onboarding completes.
//  Presented as fullScreenCover from ContentView.
//

import SwiftUI

struct TutorialFlow: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenFeatureTour") private var hasSeenFeatureTour = false

    @State private var page: Int = 0
    @State private var offerDemoData: Bool = false

    private let totalPages = 3
    private let mintColor = Color.brand

    var body: some View {
        ZStack {
            LinearGradient.tutorialBackdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button — always visible
                HStack {
                    Spacer()
                    Button("tutorial.skip") { finish(offerDemo: false) }
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 16))
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Paged content
                TabView(selection: $page) {
                    TutorialPage1_TypeOrSpeak()
                        .tag(0)
                    TutorialPage2_LearnsAsYouGo()
                        .tag(1)
                    TutorialPage3_YoursAlone(offerDemoData: $offerDemoData)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: page)

                // CTA button
                Button(action: nextOrFinish) {
                    Text(page == totalPages - 1
                         ? LocalizedStringKey("tutorial.cta.get_started")
                         : LocalizedStringKey("tutorial.cta.next"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(mintColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func nextOrFinish() {
        if page < totalPages - 1 {
            withAnimation { page += 1 }
        } else {
            finish(offerDemo: offerDemoData)
        }
    }

    private func finish(offerDemo: Bool) {
        if offerDemo { DemoDataController.seedDemoData() }
        hasSeenFeatureTour = true
        dismiss()
    }
}

#Preview {
    TutorialFlow()
}

// MARK: - Shared backdrop

extension LinearGradient {
    /// Quiet-Premium dark backdrop tinted toward the Budget Crab brand mint
    /// (replaces the earlier indigo/purple gradient). Stays dark enough for the
    /// white tutorial text to keep its contrast.
    static let tutorialBackdrop = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.13, blue: 0.11),   // deep forest-teal
            Color(red: 0.06, green: 0.18, blue: 0.15)    // slightly lifted teal
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
