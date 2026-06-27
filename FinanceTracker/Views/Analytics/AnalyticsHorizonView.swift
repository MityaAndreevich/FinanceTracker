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

    @State private var rawSelectedDate: Date?
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
                        .foregroundStyle(selected.netCents >= 0 ? .green : .red)
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
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.netCents)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            if let selectedTotal {
                RuleMark(x: .value("analytics.axis.month", selectedTotal.date))
                    .foregroundStyle(Color.accentColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.netCents)
                )
                .foregroundStyle(Color.accentColor)
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
        .onChange(of: rawSelectedDate) { _, _ in
            // Soft haptic on scrub — premium feel (Apple Stocks reference).
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
        }
    }

    private var selectedTotal: MonthlyTotal? {
        guard let rawSelectedDate else { return nil }
        return monthlyTotals.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(rawSelectedDate)) <
            abs(rhs.date.timeIntervalSince(rawSelectedDate))
        }
    }
}
