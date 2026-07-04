//
//  CoachmarkID.swift
//  FinanceTracker
//
//  First-run coach-mark targets and the anchor-preference plumbing that lets the
//  overlay highlight the REAL Dashboard/tab-bar controls in place (Brief 28 Part B).
//  A tagged view publishes its bounds via `.coachmarkTarget(_:)`; the host reads the
//  collected frames through an `overlayPreferenceValue` + `GeometryProxy` and hands
//  the resolved rect to `CoachmarkOverlay`.
//

import SwiftUI

/// The co-located first-run coach-mark targets (Dashboard + tab bar). Off-screen
/// surfaces (open-form sheet, period pager) use one-shot inline hints instead.
enum CoachmarkID: String, CaseIterable, Identifiable {
    case quickAdd
    case budget
    case analyticsTab

    var id: String { rawValue }

    /// Caption shown in the coach-mark bubble for this target.
    var captionKey: LocalizedStringKey {
        switch self {
        case .quickAdd:     return "onboarding.coach.quickadd"
        case .budget:       return "onboarding.coach.budget"
        case .analyticsTab: return "onboarding.coach.analytics"
        }
    }

    /// VoiceOver label describing the highlighted target.
    var accessibilityKey: LocalizedStringKey {
        switch self {
        case .quickAdd:     return "onboarding.coach.quickadd.a11y"
        case .budget:       return "onboarding.coach.budget.a11y"
        case .analyticsTab: return "onboarding.coach.analytics.a11y"
        }
    }
}

/// Collects target bounds keyed by `CoachmarkID`. Last writer wins so a re-render
/// refreshes a target's frame (e.g. after rotation or a layout change).
struct CoachmarkAnchorKey: PreferenceKey {
    static let defaultValue: [CoachmarkID: Anchor<CGRect>] = [:]
    static func reduce(
        value: inout [CoachmarkID: Anchor<CGRect>],
        nextValue: () -> [CoachmarkID: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this view's bounds as a coach-mark target the overlay can highlight.
    func coachmarkTarget(_ id: CoachmarkID) -> some View {
        anchorPreference(key: CoachmarkAnchorKey.self, value: .bounds) { [id: $0] }
    }
}
