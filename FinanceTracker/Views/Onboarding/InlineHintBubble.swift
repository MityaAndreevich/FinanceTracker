//
//  InlineHintBubble.swift
//  FinanceTracker
//
//  A one-shot, in-context hint (Brief 28 Part B). Used for the coach-mark targets
//  that live off the Dashboard — the QuickEntry "Use detailed form" button and the
//  Transactions period pager — surfaced the first time the user reaches each surface
//  rather than in a cross-tab tour. Dismiss is ≥44pt and honors Dynamic Type.
//

import SwiftUI

struct InlineHintBubble: View {
    let text: LocalizedStringKey
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Text("onboarding.hint.got_it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(Color.bcAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.bcAccent.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}
