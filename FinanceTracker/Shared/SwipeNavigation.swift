//
//  SwipeNavigation.swift
//  FinanceTracker
//
//  Edge-to-edge horizontal swipe navigation between sibling screens — used for
//  the main tab bar (Dashboard / Transactions / Analytics / Settings) and the
//  Analytics sub-tabs (Pulse / Breakdown / Horizon).
//

import SwiftUI
import UIKit

/// A horizontal swipe gesture that pages between sibling screens.
///
/// Attached as a **low-priority** `.gesture` (deliberately *not*
/// `.simultaneousGesture`). SwiftUI resolves drag conflicts in favor of
/// descendant recognizers, so this gesture only wins when no descendant wants
/// the drag. That single decision handles every conflict the swipe could create:
///
/// - **Vertical scrolling** — a `ScrollView` claims drags in its own axis, so a
///   vertical scroll never reaches us. The direction guard rejects whatever
///   diagonal slips through.
/// - **List swipe-actions** — a row's trailing/leading `.swipeActions` recognizer
///   is a descendant; it claims a horizontal drag over a row before we do.
/// - **Chart scrubbing** — a Swift Charts plot's drag recognizer is a descendant;
///   scrubbing over the chart wins over paging.
///
/// We therefore only page on a horizontal swipe over inert content (card
/// padding, the segmented control, empty list area, chart margins). The guard
/// requires a decisive, horizontal-dominant swipe so near-vertical flicks and
/// short taps are ignored.
private struct HorizontalSwipeNavigation: ViewModifier {
    /// Finger moves right-to-left: advance to the next screen.
    var onNext: () -> Void
    /// Finger moves left-to-right: return to the previous screen.
    var onPrevious: () -> Void

    /// Minimum horizontal travel before a swipe counts as navigation.
    private let distanceThreshold: CGFloat = 60
    /// How much horizontal travel must dominate vertical travel.
    private let dominanceRatio: CGFloat = 2

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > distanceThreshold,
                          abs(dx) > abs(dy) * dominanceRatio else { return }
                    if dx < 0 { onNext() } else { onPrevious() }
                }
        )
    }
}

extension View {
    /// Pages between sibling screens on a horizontal swipe. `onNext` fires on a
    /// leftward swipe (advance), `onPrevious` on a rightward swipe (go back). See
    /// ``HorizontalSwipeNavigation`` for how this coexists with scrolling, list
    /// swipe-actions, and chart scrubbing.
    func horizontalSwipeNavigation(
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) -> some View {
        modifier(HorizontalSwipeNavigation(onNext: onNext, onPrevious: onPrevious))
    }
}

// MARK: - Edge-only swipe (top-level tabs)

/// A horizontal swipe that pages between sibling screens **only when it begins at
/// the left or right screen edge**. Used for the main tab bar, where a
/// content-wide swipe fired unpredictably — descendant charts/lists/scrolls won
/// the drag, so users couldn't tell which zone navigated. Anchoring to the edges
/// makes the gesture a deliberate, discoverable affordance:
///
/// - start within `edgeWidth` of the **left** edge + drag right → previous screen
/// - start within `edgeWidth` of the **right** edge + drag left  → next screen
///
/// Still a low-priority `.gesture`, so the system's interactive back-swipe (when a
/// NavigationStack has something to pop) and a row's `.swipeActions` both win over
/// it; it only fires at a tab root where the left edge is otherwise inert.
private struct EdgeSwipeNavigation: ViewModifier {
    var onNext: () -> Void
    var onPrevious: () -> Void

    /// Width of the active zone at each edge.
    private let edgeWidth: CGFloat = 30
    /// Minimum horizontal travel before a swipe counts.
    private let distanceThreshold: CGFloat = 60
    /// Maximum vertical drift tolerated (strict, so scrolls never page).
    private let verticalTolerance: CGFloat = 40

    @State private var width: CGFloat = UIScreen.main.bounds.width

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { width = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in width = w }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let startX = value.startLocation.x
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > distanceThreshold,
                              abs(dy) < verticalTolerance,
                              abs(dx) > abs(dy) else { return }

                        if startX < edgeWidth, dx > 0 {
                            onPrevious()
                        } else if startX > width - edgeWidth, dx < 0 {
                            onNext()
                        }
                    }
            )
    }
}

extension View {
    /// Pages between top-level tabs on a swipe that starts at a screen edge. See
    /// ``EdgeSwipeNavigation``. `onNext` fires on a right-edge leftward swipe,
    /// `onPrevious` on a left-edge rightward swipe.
    func edgeSwipeNavigation(
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) -> some View {
        modifier(EdgeSwipeNavigation(onNext: onNext, onPrevious: onPrevious))
    }
}

// MARK: - Edge hint

/// A discreet, non-interactive accent glow at both screen edges, shown a handful
/// of times on early launches to teach the edge-swipe affordance. Breathes gently
/// then is faded out by its host. HIG-aligned: subtle, never blocks touches.
struct EdgeSwipeHintView: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            edgeGlow(leading: true)
            Spacer()
            edgeGlow(leading: false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func edgeGlow(leading: Bool) -> some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(pulse ? 0.30 : 0.05), .clear],
            startPoint: leading ? .leading : .trailing,
            endPoint: leading ? .trailing : .leading
        )
        .frame(width: 24)
    }
}
