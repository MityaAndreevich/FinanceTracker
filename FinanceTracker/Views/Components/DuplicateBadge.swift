//
//  DuplicateBadge.swift
//  FinanceTracker
//
//  Marks a transaction the importer flagged as a possible duplicate.
//
//  Calm amber (`bcWarning`), never alarm red: a possible duplicate is a question
//  for the user, not an error. It is deliberately icon + LABEL, never hue alone —
//  a color-blind user must get the same signal, so the amber is a reinforcing
//  accent on top of text that already says it.
//
//  Contrast is why the ink is `bcWarningInk` rather than `bcWarning` itself:
//  bcWarning as text on the light row background measures 3.28:1, under the 4.5:1
//  minimum. bcWarningInk is the same amber darkened for light mode (and lifted for
//  dark) and clears 4.5:1 on both the tinted capsule and the plain row.
//

import SwiftUI

struct DuplicateBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 9, weight: .bold))
            Text("transactions.duplicate.badge")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.bcWarningInk)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.bcWarning.opacity(0.16)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("transactions.duplicate.badge"))
    }
}

#if DEBUG
#Preview("Duplicate badge") {
    VStack(spacing: 16) {
        DuplicateBadge()
        DuplicateBadge().environment(\.colorScheme, .dark)
    }
    .padding()
    .background(Color.bcSurface1)
}
#endif
