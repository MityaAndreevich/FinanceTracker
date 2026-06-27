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

    struct DailyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let cents: Int
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
    }

    private var heroMetric: some View {
        VStack(spacing: 4) {
            Text("analytics.net_this_month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Money.formatSigned(
                cents: netCents,
                isPositive: netCents >= 0,
                currencyCode: currencyCode
            ))
            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(netCents >= 0 ? .green : .red)
            .privacySensitive(true)  // hidden in App Switcher per HIG
            .contentTransition(.numericText(value: Double(netCents) / 100))
        }
        .padding(.top, 16)
    }

    private var cashFlowChart: some View {
        Chart {
            ForEach(dailyTotals) { item in
                AreaMark(
                    x: .value("analytics.axis.date", item.date),
                    y: .value("analytics.axis.amount", item.cents)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.4),
                            Color.accentColor.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("analytics.axis.date", item.date),
                    y: .value("analytics.axis.amount", item.cents)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
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
    }

    private var summary: some View {
        VStack(spacing: 12) {
            summaryRow(
                icon: "arrow.up.right",
                label: "analytics.earned_total",
                value: dailyTotals.filter { $0.cents > 0 }.reduce(0) { $0 + $1.cents },
                color: .green
            )
            summaryRow(
                icon: "arrow.down.right",
                label: "analytics.spent_total",
                value: abs(dailyTotals.filter { $0.cents < 0 }.reduce(0) { $0 + $1.cents }),
                color: .red
            )
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label).font(.body)
            Spacer()
            Text(Money.format(cents: value, currencyCode: currencyCode))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .privacySensitive(true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
