//
//  TipOfTheDayCard.swift
//  FinanceTracker
//
//  The daily educational tip on the Dashboard. Calm, dismissible, never blocking.
//  Free — no premium gate: education drives retention, not willingness to pay.
//

import SwiftUI

struct TipOfTheDayCard: View {
    let tip: DailyTip
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header

            Text(tip.term)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)

            Text(tip.explanation)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            strategy
        }
        .padding(Spacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(Color.bcSurface1)
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("learn.tip_of_day", systemImage: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bcAccent)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bcTextMuted)
                    // Padding, not a frame: keeps the glyph small while giving the
                    // button a comfortable tap target.
                    .padding(Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("learn.dismiss")
        }
    }

    private var strategy: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)

            Text(tip.strategy)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dismiss() {
        guard !reduceMotion else { return onDismiss() }
        withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
    }
}

#Preview {
    TipOfTheDayCard(
        tip: DailyTip(
            id: "preview",
            term: "Sinking fund",
            explanation: "Money set aside each month for a known future cost.",
            strategy: "Name one for your next car service.",
            category: "sample"
        ),
        onDismiss: {}
    )
    .padding()
    .background(Color.bcPage)
}
