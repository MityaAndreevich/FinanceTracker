//
//  SwipeNavigation.swift
//  FinanceTracker
//
//  Edge-to-edge horizontal swipe navigation between sibling screens — used for
//  the main tab bar (Dashboard / Transactions / Analytics / Settings) and the
//  Analytics sub-tabs (Pulse / Breakdown / Horizon).
//

import SwiftUI

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
