//
//  CategoryDonutView.swift
//  FinanceTracker
//
//  Multi-color category donut (DESIGN_DIRECTION_v2 §3): one distinct color per
//  category, hollow center showing the total. Replaces the monochrome donut.
//  Reused by Analytics in Phase 2.
//

import SwiftUI
import Charts

struct CategoryDonutView: View {
    struct Slice: Identifiable {
        let id: String
        let name: String
        let cents: Int
        let color: Color
    }

    let slices: [Slice]
    let centerTitle: LocalizedStringKey
    let centerValue: String
    var size: CGFloat = 168

    var body: some View {
        ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("amount", slice.cents),
                    innerRadius: .ratio(0.64),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(slice.color)
            }
            .chartLegend(.hidden)
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(centerTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.bcTextSecondary)
                    .textCase(.uppercase)
                Text(centerValue)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.bcTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .privacySensitive(true)
            }
            .frame(width: size * 0.58)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(centerTitle) + Text(", ") + Text(centerValue))
    }
}
