//
//  CoachmarkOverlay.swift
//  FinanceTracker
//
//  The dimmed first-run coach-mark layer (Brief 28 Part B). Punches a rounded cutout
//  around the current target's resolved frame, rings it in mint, and shows a bottom
//  caption card with Next / Skip. The caption lives in a bottom card (not a floating
//  bubble) so it stays legible at every Dynamic Type size and device height while the
//  ring carries the "look here" signal. The host (ContentView) resolves `targetRect`
//  from the collected anchor preferences and passes it in.
//

import SwiftUI

struct CoachmarkOverlay: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    /// Current target's frame in the overlay's coordinate space, or nil if unresolved.
    let targetRect: CGRect?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cutoutPadding: CGFloat = 8
    private let cutoutRadius: CGFloat = 16

    var body: some View {
        if let step = coordinator.currentStep {
            ZStack {
                dimWithCutout
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { coordinator.advance() }
                    .accessibilityHidden(true)

                if let rect = targetRect {
                    RoundedRectangle(cornerRadius: cutoutRadius, style: .continuous)
                        .strokeBorder(Color.bcAccent, lineWidth: 2)
                        .frame(width: rect.width + cutoutPadding * 2,
                               height: rect.height + cutoutPadding * 2)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                VStack {
                    Spacer()
                    captionCard(step)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
            .transition(.opacity)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: coordinator.phase)
        }
    }

    // MARK: - Dim + cutout

    private var dimWithCutout: some View {
        Rectangle()
            .fill(Color.black.opacity(0.72))
            .reverseMask {
                if let rect = targetRect {
                    RoundedRectangle(cornerRadius: cutoutRadius, style: .continuous)
                        .frame(width: rect.width + cutoutPadding * 2,
                               height: rect.height + cutoutPadding * 2)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
    }

    // MARK: - Caption card

    private func captionCard(_ step: CoachmarkID) -> some View {
        VStack(spacing: 16) {
            Text(step.captionKey)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.bcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button { coordinator.skip() } label: {
                    Text("onboarding.skip")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.bcTextSecondary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }

                Spacer()

                stepDots(activeIndex: coordinator.steps.firstIndex(of: step) ?? 0)

                Spacer()

                Button { coordinator.advance() } label: {
                    Text("onboarding.next")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.black)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 22)
                        .background(Color.bcAccent, in: Capsule())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.bcSurface1)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.bcDivider, lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(step.accessibilityKey))
    }

    private func stepDots(activeIndex: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(coordinator.steps.indices, id: \.self) { i in
                Circle()
                    .fill(i == activeIndex ? Color.bcAccent : Color.bcTextMuted.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Reverse mask helper (punch a hole in a view)

extension View {
    /// Masks `self` with everything EXCEPT the given shape — i.e. cuts a hole. Used
    /// to make the dim backdrop transparent over the highlighted coach-mark target.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask().blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
