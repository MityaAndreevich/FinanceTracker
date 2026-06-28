//
//  TutorialPage3_YoursAlone.swift
//  FinanceTracker
//

import SwiftUI

struct TutorialPage3_YoursAlone: View {
    @Binding var offerDemoData: Bool
    @State private var pulsing = false

    private let mintColor = Color.brand

    private let bullets: [(String, String)] = [
        ("checkmark.circle.fill", "tutorial.page3.bullet1"),
        ("checkmark.circle.fill", "tutorial.page3.bullet2"),
        ("checkmark.circle.fill", "tutorial.page3.bullet3"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon with pulse
            ZStack {
                Circle()
                    .fill(mintColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: pulsing
                    )

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(mintColor)
            }
            .padding(.bottom, 32)

            // Bullets
            VStack(alignment: .leading, spacing: 14) {
                ForEach(bullets, id: \.1) { icon, key in
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(mintColor)
                        Text(LocalizedStringKey(key))
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)

            // Demo data toggle
            HStack {
                Text("tutorial.page3.demo_offer")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Toggle("", isOn: $offerDemoData)
                    .labelsHidden()
                    .tint(mintColor)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            Spacer()

            // Text content
            VStack(spacing: 12) {
                Text("tutorial.page3.headline")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
        .onAppear { pulsing = true }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.11, green: 0.09, blue: 0.22), Color(red: 0.15, green: 0.10, blue: 0.32)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        TutorialPage3_YoursAlone(offerDemoData: .constant(false))
    }
}
