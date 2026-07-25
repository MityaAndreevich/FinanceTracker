//
//  SplitBadge.swift
//  FinanceTracker
//
//  Marks a purchase whose money is split across several categories.
//
//  Why a badge and not silence (2026-07-23 hands-on report): search now agrees
//  with Analytics by attribution, so a 3,500 purchase filed under Питомцы and
//  fully split into two other categories no longer appears under Питомцы at all.
//  That is the correct number — and, unexplained, it reads as a purchase that
//  went missing. The badge is the explanation: the row still shows the full
//  amount it cost, and the badge says why that amount can land somewhere else in
//  Analytics. Correct-and-legible beats correct-and-silent.
//
//  Neutral, not amber: `DuplicateBadge` is a question FOR the user (something may
//  be wrong); a split is a thing the user deliberately did (nothing is wrong).
//  Reusing the warning tint here would cry wolf on a healthy state, so this rides
//  the same capsule geometry in secondary ink instead.
//
//  Icon + LABEL, never hue alone — same color-blind rule the duplicate badge
//  follows.
//

import SwiftUI

struct SplitBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9, weight: .bold))
            Text("transactions.split.badge")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.bcTextSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.bcTextSecondary.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("transactions.split.badge"))
    }
}

#if DEBUG
#Preview("Split badge") {
    VStack(spacing: 16) {
        SplitBadge()
        SplitBadge().environment(\.colorScheme, .dark)
    }
    .padding()
    .background(Color.bcSurface1)
}
#endif
