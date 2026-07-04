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
    /// Which way the pointing-hand glyph faces — toward where the target control
    /// actually sits relative to the bubble. `.up` for a target above (the
    /// Transactions period pager); `.down` for a target below (the Quick Entry
    /// "Use detailed form" button, which sits directly under this hint).
    enum Direction {
        case up, down
        var symbol: String {
            switch self {
            case .up:   return "hand.point.up.fill"
            case .down: return "hand.point.down.fill"
            }
        }
    }

    let text: LocalizedStringKey
    var pointing: Direction = .up
    let onDismiss: () -> Void

    var body: some View {
        // `.center` alignment (was `.top`) vertically centers the glyph and text
        // against the 44pt "Got it" tap target instead of pinning them to the top
        // edge, which read as cramped/crooked (device QA round 1 #5). lineSpacing +
        // even vertical padding give the copy room to breathe.
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: pointing.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bcTextPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Text("onboarding.hint.got_it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
                    .padding(.leading, 4)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.bcAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.bcAccent.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}
