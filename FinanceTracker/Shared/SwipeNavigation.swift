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

// MARK: - Right-edge forward swipe (top-level tabs)

/// A forward-only horizontal swipe that advances to the next sibling screen
/// **when it begins at the right screen edge**. Used for the main tab bar as an
/// additive accelerator on top of tap navigation.
///
/// We deliberately page **forward only**. A left-edge rightward swipe was dropped
/// because it competes with the iOS system back gesture (interactive pop) and
/// trains contradictory muscle memory; backward navigation is done by tapping the
/// tab bar — the canonical iOS pattern. Research-validated B-trimmed verdict.
///
/// - start within `edgeWidth` of the **right** edge + drag left → next screen
///
/// Still a low-priority `.gesture`, so the system's interactive back-swipe (when a
/// NavigationStack has something to pop) and a row's `.swipeActions` both win over
/// it; it only fires at a tab root where the right edge is otherwise inert.
private struct EdgeSwipeForward: ViewModifier {
    var onNext: () -> Void

    /// Width of the active zone at the right edge. Bug 4 (P1): widened from 30pt
    /// to 50pt because iOS reserves ~15pt of the trailing edge for its own system
    /// gestures, leaving the previous 30pt zone with an effective ~15pt landing
    /// strip. 50pt yields ~35pt of usable area, which testers reliably hit.
    private let edgeWidth: CGFloat = 50
    /// Minimum horizontal travel for a *slow* swipe (no velocity component).
    private let distanceThreshold: CGFloat = 50
    /// Reduced distance threshold when the swipe is fast — a flick covers less
    /// distance but still expresses clear intent. Combined with `velocityFast`.
    private let distanceThresholdFast: CGFloat = 30
    /// Points-per-second above which the swipe is considered a deliberate flick.
    /// 300 pt/s is roughly the lower bound for a "casual flick" on iOS; lower
    /// would catch accidental scrolls, higher would feel sluggish.
    private let velocityFast: CGFloat = 300
    /// Maximum vertical drift tolerated (strict, so scrolls never page).
    private let verticalTolerance: CGFloat = 40

    @State private var width: CGFloat = UIScreen.main.bounds.width
    /// Touch-down time, used to compute average velocity over the drag.
    @State private var touchDownAt: Date?

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
                    .onChanged { _ in
                        if touchDownAt == nil { touchDownAt = Date() }
                    }
                    .onEnded { value in
                        let startX = value.startLocation.x
                        let dx = value.translation.width
                        let dy = value.translation.height

                        // Velocity (pt/s). DragGesture.Value doesn't expose
                        // velocity directly on iOS 17, so we estimate from drag
                        // duration. Fall back to "slow" if timing is missing.
                        let duration = touchDownAt.map { max(Date().timeIntervalSince($0), 0.001) } ?? 1.0
                        touchDownAt = nil
                        let velocity = abs(dx) / CGFloat(duration)

                        let meetsDistance = abs(dx) > distanceThreshold
                        let meetsFlick = abs(dx) > distanceThresholdFast && velocity > velocityFast

                        guard (meetsDistance || meetsFlick),
                              abs(dy) < verticalTolerance,
                              abs(dx) > abs(dy) else { return }

                        if startX > width - edgeWidth, dx < 0 {
                            onNext()
                        }
                    }
            )
    }
}

extension View {
    /// Advances to the next top-level tab on a right-edge leftward swipe. See
    /// ``EdgeSwipeForward``. Backward navigation is intentionally tap-only.
    func edgeSwipeForward(onNext: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeForward(onNext: onNext))
    }
}

// MARK: - Edge hint

/// A discreet, non-interactive accent glow at the **right** screen edge, shown a
/// handful of times on early launches to teach the right-edge forward-swipe
/// affordance. Breathes gently then is faded out by its host. Single-edge to match
/// the forward-only gesture. HIG-aligned: subtle, never blocks touches.
struct EdgeSwipeHintView: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            edgeGlow
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var edgeGlow: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(pulse ? 0.30 : 0.05), .clear],
            startPoint: .trailing,
            endPoint: .leading
        )
        .frame(width: 24)
    }
}
