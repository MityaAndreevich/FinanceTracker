//
//  TutorialPage1_TypeOrSpeak.swift
//  FinanceTracker
//

import SwiftUI

struct TutorialPage1_TypeOrSpeak: View {
    @State private var typedText: String = ""
    @State private var showPreviewCard: Bool = false
    @State private var animationPhase: Int = 0

    private let mintColor = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)
    private let targetText = "67 gas"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated demo area
            VStack(spacing: 16) {
                // Mock input bar
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18))
                        .foregroundStyle(mintColor)

                    Text(typedText.isEmpty ? " " : typedText)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .trailing) {
                            if !typedText.isEmpty && animationPhase < 2 {
                                Rectangle()
                                    .fill(.white)
                                    .frame(width: 2, height: 18)
                                    .opacity(animationPhase == 1 ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animationPhase)
                            }
                        }
                }
                .padding(12)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // Preview card
                if showPreviewCard {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(mintColor)

                        Text("− $67.00")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)

                        Text("→").foregroundStyle(.white.opacity(0.6))

                        Text("Transport")
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            Spacer()

            // Text content
            VStack(spacing: 12) {
                Text("tutorial.page1.headline")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("tutorial.page1.caption")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
        .onAppear { startTypingAnimation() }
        .onDisappear { stopAnimation() }
    }

    @State private var typingTask: Task<Void, Never>?

    private func startTypingAnimation() {
        animationPhase = 1
        typingTask = Task { await runLoop() }
    }

    private func stopAnimation() {
        typingTask?.cancel()
        typingTask = nil
    }

    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            // Type characters
            typedText = ""
            showPreviewCard = false
            for char in targetText {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(160))
                typedText += String(char)
            }
            // Show preview card
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showPreviewCard = true
            }
            // Pause, then reset
            try? await Task.sleep(for: .milliseconds(2500))
            withAnimation { showPreviewCard = false }
            try? await Task.sleep(for: .milliseconds(600))
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.11, green: 0.09, blue: 0.22), Color(red: 0.15, green: 0.10, blue: 0.32)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        TutorialPage1_TypeOrSpeak()
    }
}
