//
//  TutorialPage2_LearnsAsYouGo.swift
//  FinanceTracker
//

import SwiftUI

struct TutorialPage2_LearnsAsYouGo: View {
    @State private var phase: Int = 0
    @State private var animTask: Task<Void, Never>?

    private let mintColor = Color.brand

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation area
            VStack(spacing: 14) {
                // First entry
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Trader Joe's 45")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 8) {
                        Text("→")
                            .foregroundStyle(.white.opacity(0.5))
                        Text(phase == 0 ? "Other" : "Food & Drink")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(phase == 0 ? .white.opacity(0.5) : mintColor)
                            .animation(.easeInOut(duration: 0.4), value: phase)

                        if phase == 0 {
                            Image(systemName: "hand.point.up.left")
                                .font(.system(size: 14))
                                .foregroundStyle(mintColor)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Arrow between frames
                Image(systemName: "arrow.down")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.4))
                    .opacity(phase >= 1 ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: phase)

                // Second entry
                if phase >= 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Trader Joe's 80")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        if phase >= 2 {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundStyle(mintColor)
                                Text("Food & Drink")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(mintColor)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: phase)

            Spacer()

            // Text content
            VStack(spacing: 12) {
                Text("tutorial.page2.headline")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("tutorial.page2.caption")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
        .onAppear { startAnimation() }
        .onDisappear { animTask?.cancel() }
    }

    private func startAnimation() {
        animTask = Task { await runLoop() }
    }

    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            phase = 0
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            withAnimation { phase = 1 }
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            withAnimation { phase = 2 }
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            withAnimation { phase = 0 }
            try? await Task.sleep(for: .milliseconds(800))
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.11, green: 0.09, blue: 0.22), Color(red: 0.15, green: 0.10, blue: 0.32)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        TutorialPage2_LearnsAsYouGo()
    }
}
