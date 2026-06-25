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
    private let mintColor = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.09, blue: 0.22),
                    Color(red: 0.15, green: 0.10, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
