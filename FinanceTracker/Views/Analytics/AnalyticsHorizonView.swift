//
//  AnalyticsHorizonView.swift
//  FinanceTracker
//
//  Analytics screen 3 of 3 — "The Horizon". 12-month net trend with Apple
//  Stocks-style haptic scrubbing: drag across the line to read any month's net.
//  Brief 28H addendum (research-validated). Balances are .privacySensitive().
//

import SwiftUI
import Charts

struct AnalyticsHorizonView: View {
    let monthlyTotals: [MonthlyTotal]   // 12 months
    let currencyCode: String

    // `chartXSelection` resets its binding to nil the instant the finger lifts,
    // which made the selection (and the tappable tooltip/Show-details affordance)
    // vanish on touch-end. We treat `rawSelectedDate` as the *transient* scrub
    // position and commit it into `stickySelectedDate`, which persists until the
    // user scrubs elsewhere or explicitly clears. (Apple Health-style sticky.)
    @State private var rawSelectedDate: Date?
    @State private var stickySelectedDate: Date?
    @State private var detailMonth: MonthlyTotal?

    struct MonthlyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let netCents: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            tooltipBar
            trendChart
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .sheet(item: $detailMonth) { month in
            MonthDetailSheet(month: month, currencyCode: currencyCode)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var tooltipBar: some View {
        if let selected = selectedTotal {
            Button {
                detailMonth = selected
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Text(selected.date.formatted(.dateTime.month(.wide).year()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(Money.formatSigned(
                            cents: selected.netCents,
                            isPositive: selected.netCents >= 0,
                            currencyCode: currencyCode
                        ))
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.money(isPositive: selected.netCents >= 0))
                        .privacySensitive(true)
                        .contentTransition(.numericText())
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("analytics.horizon.tap_hint"))
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { stickySelectedDate = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
                .accessibilityLabel(Text("analytics.selection.clear"))
            }
        } else {
            Text("analytics.horizon.hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 16)
        }
    }

    private var trendChart: some View {
        Chart {
            ForEach(monthlyTotals) { item in
                LineMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.netCents)
                )
                .foregroundStyle(netTrendGradient)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.netCents)
                )
                .foregroundStyle(netAreaGradient)
                .interpolationMethod(.catmullRom)
            }

            if let selectedTotal {
                RuleMark(x: .value("analytics.axis.month", selectedTotal.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.netCents)
                )
                .foregroundStyle(Color.money(isPositive: selectedTotal.netCents >= 0))
                .symbolSize(120)
            }
        }
        .chartXSelection(value: $rawSelectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel().font(.caption2)
            }
        }
        .frame(height: 320)
        .onChange(of: rawSelectedDate) { _, newValue in
            // Ignore the touch-end reset (newValue == nil); commit live scrub
            // positions into the sticky selection so it persists after release.
            guard let newValue,
                  let nearest = nearestMonth(to: newValue) else { return }
            if nearest.date != stickySelectedDate {
                stickySelectedDate = nearest.date
                // Soft haptic on scrub — premium feel (Apple Stocks reference).
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
            }
        }
    }

    // MARK: - Sign-aware coloring
    //
    // The Horizon trend is a single *net* line (income − expense). It used to be
    // drawn entirely in `Color.accentColor`, so a month with net spending looked
    // identical to a month with net income — users read the chart as "income only,
    // no expenses" because there was never any terracotta on screen. We now split
    // the line/area at the zero line: emerald (`.bcIncome`) above zero, terracotta
    // (`.bcExpense`) below. This keeps the single-line "Stocks-style" design while
    // making expense-led months visually unmistakable, using the shared semantic
    // money tokens (no new strings, no separate series).

    /// Position of the zero line within the value range, as a fraction from the
    /// top (0) to the bottom (1) of the chart's plotted bounding box. Drives the
    /// hard color stop in the gradients below.
    private var zeroFraction: CGFloat {
        let values = monthlyTotals.map(\.netCents)
        guard let maxV = values.max(), let minV = values.min(), maxV != minV else {
            return (values.first ?? 0) >= 0 ? 1 : 0
        }
        if maxV <= 0 { return 0 }   // every month net-negative → all terracotta
        if minV >= 0 { return 1 }   // every month net-positive → all emerald
        return CGFloat(maxV) / CGFloat(maxV - minV)
    }

    private var netTrendGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .bcIncome, location: 0),
                .init(color: .bcIncome, location: zeroFraction),
                .init(color: .bcExpense, location: zeroFraction),
                .init(color: .bcExpense, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var netAreaGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .bcIncome.opacity(0.28), location: 0),
                .init(color: .bcIncome.opacity(0.04), location: zeroFraction),
                .init(color: .bcExpense.opacity(0.04), location: zeroFraction),
                .init(color: .bcExpense.opacity(0.28), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func nearestMonth(to date: Date) -> MonthlyTotal? {
        monthlyTotals.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private var selectedTotal: MonthlyTotal? {
        guard let stickySelectedDate else { return nil }
        return nearestMonth(to: stickySelectedDate)
    }
}
