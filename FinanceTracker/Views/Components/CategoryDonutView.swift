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

    /// Slices actually safe to plot: non-positive magnitudes dropped and a
    /// zero-total set collapsed to empty. A zero-total `SectorMark` domain is the
    /// classic pie-chart EXC_BREAKPOINT (each sweep angle is `value / 0` → NaN).
    private var renderableSlices: [Slice] {
        ChartGuards.renderableSlices(slices, magnitude: \.cents)
    }

    /// The donut is sized by a caller-supplied scalar that goes straight into a
    /// `.frame`, so it is clamped here rather than trusted. A non-finite or
    /// negative side would both trip SwiftUI's "Invalid frame dimension" and hand
    /// Charts a degenerate box to build an angular scale in.
    private var safeSize: CGFloat {
        ChartGuards.dimension(size)
    }

    var body: some View {
        ZStack {
            // Records the exact magnitudes about to be plotted (DEBUG only, no-op
            // in RELEASE). Bisection says WHICH chart; this says WITH WHAT — the
            // last line before a device trap is the degenerate input itself.
            let _ = ChartBisection.probe(.dashboardDonut, cents: renderableSlices.map(\.cents))

            // `ChartBisection` is a no-op in RELEASE; in DEBUG it lets the chart be
            // switched off on device to attribute the Charts EXC_BREAKPOINT.
            if renderableSlices.isEmpty || safeSize <= 0 || !ChartBisection.isEnabled(.dashboardDonut) {
                // No positive data (or no box to draw in) → a neutral placeholder
                // ring instead of a degenerate Chart. Stroke matches the 0.64
                // inner-radius ring.
                Circle()
                    .stroke(Color.bcSurface2, lineWidth: safeSize * 0.18)
                    .frame(width: safeSize, height: safeSize)
            } else {
                Chart(renderableSlices) { slice in
                    SectorMark(
                        angle: .value("amount", slice.cents),
                        innerRadius: .ratio(0.64),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(slice.color)
                }
                .chartLegend(.hidden)
                .guardedChartFrame()
                .frame(width: safeSize, height: safeSize)
            }

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
            .frame(width: safeSize * 0.58)
        }
        .frame(width: safeSize, height: safeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(centerTitle) + Text(", ") + Text(centerValue))
    }
}
