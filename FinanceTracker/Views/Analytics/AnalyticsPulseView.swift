//
//  AnalyticsPulseView.swift
//  FinanceTracker
//
//  Analytics screen 1 of 3 — "The Pulse". This-month cash flow: a hero net
//  metric over a 30-day area/line chart, plus earned/spent summary rows.
//  Brief 28H addendum (research-validated). Balances are .privacySensitive()
//  so they redact in the App Switcher.
//

import SwiftUI
import Charts

struct AnalyticsPulseView: View {
    let dailyTotals: [DailyTotal]   // current month, signed net per day
    let netCents: Int
    let currencyCode: String

    // `chartXSelection` resets to nil on touch-end; keep a sticky selection so
    // the scrubbed day (and its tappable drill-down) survives finger lift.
    @State private var rawSelectedDate: Date?
    @State private var stickySelectedDate: Date?
    @State private var detailDay: DailyTotal?

    // Bug 3 (P2): Swift Charts axis labels use `.dateTime.month(.abbreviated)`,
    // which captures the locale at first render and ignores `environment(\.locale)`
    // changes. Observe the in-app language so we can force a full chart rebuild
    // via `.id()` when the user switches languages — refreshes "Jan/Feb" to
    // "янв/фев" without an app restart.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    struct DailyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let cents: Int
    }

    /// Day nearest the sticky selection, or nil when nothing is selected.
    private var selectedDay: DailyTotal? {
        guard let stickySelectedDate else { return nil }
        return nearestDay(to: stickySelectedDate)
    }

    private func nearestDay(to date: Date) -> DailyTotal? {
        dailyTotals.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                heroMetric
                cashFlowChart
                summary
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .sheet(item: $detailDay) { day in
            DaySpendingSheet(day: day.date, currencyCode: currencyCode)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var heroMetric: some View {
        VStack(spacing: 4) {
            if let selectedDay {
                // Selected day → tappable, opens the day drill-down sheet.
                Button {
                    detailDay = selectedDay
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Text(selectedDay.date.formatted(.dateTime.day().month(.wide)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(Money.formatSigned(
                                cents: selectedDay.cents,
                                isPositive: selectedDay.cents >= 0,
                                currencyCode: currencyCode
                            ))
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.moneyDirectional(isPositive: selectedDay.cents >= 0))
                            .privacySensitive(true)
                            .contentTransition(.numericText())
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("analytics.pulse.tap_hint"))
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
                Text("analytics.net_this_month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Money.formatSigned(
                    cents: netCents,
                    isPositive: netCents >= 0,
                    currencyCode: currencyCode
                ))
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.moneyDirectional(isPositive: netCents >= 0))
                .privacySensitive(true)  // hidden in App Switcher per HIG
                .contentTransition(.numericText(value: Double(netCents) / 100))
            }
        }
        .padding(.top, 16)
        .animation(.easeInOut(duration: 0.15), value: selectedDay?.id)
    }

    @ViewBuilder
    private var cashFlowChart: some View {
        // A single day of data (e.g. the 1st of the month, when the dense day range
        // is just [today]) collapses the date domain to one instant and makes
        // `catmullRom` divide by a 0 inter-point distance → non-finite geometry →
        // EXC_BREAKPOINT inside Charts. Need ≥2 points before drawing the trend.
        if ChartGuards.canRenderContinuous(pointCount: dailyTotals.count) {
            cashFlowChartBody
        } else {
            insufficientDataHint
        }
    }

    private var insufficientDataHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 34))
                .foregroundStyle(Color.bcTextMuted)
            Text("analytics.pulse.needs_more_days")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .padding(.vertical, 8)
    }

    private var cashFlowChartBody: some View {
        Chart {
            ForEach(dailyTotals) { item in
                AreaMark(
                    x: .value("analytics.axis.date", item.date),
                    y: .value("analytics.axis.amount", item.cents)
                )
                // Solid low-opacity mint fill (no gradient — DESIGN_DIRECTION_v2 §2).
                .foregroundStyle(Color.bcAccent.opacity(0.14))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("analytics.axis.date", item.date),
                    y: .value("analytics.axis.amount", item.cents)
                )
                .foregroundStyle(Color.bcAccent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            if let selectedDay {
                RuleMark(x: .value("analytics.axis.date", selectedDay.date))
                    .foregroundStyle(Color.bcAccent.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                PointMark(
                    x: .value("analytics.axis.date", selectedDay.date),
                    y: .value("analytics.axis.amount", selectedDay.cents)
                )
                .foregroundStyle(Color.bcAccent)
                .symbolSize(120)
            }
        }
        .chartXSelection(value: $rawSelectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 240)
        .padding(.vertical, 8)
        // Bug 3: rebuild the chart when in-app language changes so axis labels
        // re-format under the new locale. `.dateTime.month(.abbreviated)` cached
        // its locale otherwise.
        .id(localizedBundle.languageCode ?? "system")
        .onChange(of: rawSelectedDate) { _, newValue in
            // Ignore touch-end reset; commit live scrub into the sticky selection.
            guard let newValue, let nearest = nearestDay(to: newValue) else { return }
            if nearest.date != stickySelectedDate {
                stickySelectedDate = nearest.date
                // Soft haptic on scrub — matches Horizon (Apple Stocks reference).
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            // Income is the highlight (green + up-arrow); spend is neutral — a
            // month's spend is normal, not an alert (DESIGN_DIRECTION_v2 §2).
            summaryRow(
                icon: "arrow.up.right",
                label: "analytics.earned_total",
                value: dailyTotals.filter { $0.cents > 0 }.reduce(0) { $0 + $1.cents },
                color: .bcPositive
            )
            summaryRow(
                icon: "arrow.down.right",
                label: "analytics.spent_total",
                value: abs(dailyTotals.filter { $0.cents < 0 }.reduce(0) { $0 + $1.cents }),
                color: .bcTextSecondary
            )
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.body)
                .foregroundStyle(Color.bcTextPrimary)
            Spacer()
            Text(Money.format(cents: value, currencyCode: currencyCode))
                .font(.body.monospacedDigit())
                .foregroundStyle(Color.bcTextSecondary)
                .privacySensitive(true)
        }
        .bcCard(padding: 14)
    }
}
