//
//  AnalyticsBreakdownView.swift
//  FinanceTracker
//
//  Analytics screen 2 of 3 — "The Breakdown". This-month expenses by category
//  as a donut (SectorMark) using hierarchical Mint opacity (NOT category-rainbow
//  colors) to match the Quiet Premium palette. Tap a legend row to focus a slice.
//  Brief 28H addendum (research-validated). VoiceOver-accessible via AXChartDescriptor.
//

import SwiftUI
import Charts

struct AnalyticsBreakdownView: View {
    let categories: [CategoryTotal]
    let currencyCode: String

    @State private var selectedCategory: CategoryTotal?

    struct CategoryTotal: Identifiable, Hashable {
        let id: UUID
        let name: String
        let symbol: String
        let cents: Int
    }

    private var sortedCategories: [CategoryTotal] {
        categories.sorted { $0.cents > $1.cents }
    }

    private var total: Int {
        categories.reduce(0) { $0 + $1.cents }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                donutChart
                legend
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var donutChart: some View {
        Chart(sortedCategories) { cat in
            SectorMark(
                angle: .value("analytics.axis.amount", cat.cents),
                innerRadius: .ratio(0.62),
                angularInset: 2.5
            )
            .cornerRadius(6)
            // Hierarchical Mint — opacity varies by rank, not hue.
            .foregroundStyle(colorForRank(cat))
            .opacity(selectedCategory == nil || selectedCategory == cat ? 1.0 : 0.35)
        }
        .frame(height: 280)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    centerLabel
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .accessibilityChartDescriptor(self)
    }

    @ViewBuilder
    private var centerLabel: some View {
        VStack(spacing: 4) {
            if let selected = selectedCategory {
                Image(systemName: selected.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(selected.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(Money.format(cents: selected.cents, currencyCode: currencyCode))
                    .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                    .privacySensitive(true)
            } else {
                Text("analytics.total")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(Money.format(cents: total, currencyCode: currencyCode))
                    .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                    .privacySensitive(true)
            }
        }
    }

    private func colorForRank(_ cat: CategoryTotal) -> Color {
        guard let rank = sortedCategories.firstIndex(of: cat) else {
            return Color.accentColor.opacity(0.3)
        }
        // Most spent = full color, each lower rank a little more transparent.
        let factor = max(0.35, 1.0 - (Double(rank) * 0.12))
        return Color.accentColor.opacity(factor)
    }

    private var legend: some View {
        VStack(spacing: 8) {
            ForEach(sortedCategories) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: cat.symbol)
                            .font(.body)
                            .foregroundStyle(colorForRank(cat))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name).font(.body)
                            Text(percentLabel(cat))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(cents: cat.cents, currencyCode: currencyCode))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .privacySensitive(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        selectedCategory == cat ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func percentLabel(_ cat: CategoryTotal) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(cat.cents) / Double(total) * 100).rounded()))%"
    }
}

// MARK: - VoiceOver chart description

extension AnalyticsBreakdownView: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Category",
            categoryOrder: sortedCategories.map { $0.name }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Amount",
            range: 0...Double(max(total, 1)),
            gridlinePositions: []
        ) { value in
            Money.format(cents: Int(value), currencyCode: currencyCode)
        }
        let series = AXDataSeriesDescriptor(
            name: "Spending by Category",
            isContinuous: false,
            dataPoints: sortedCategories.map {
                AXDataPoint(x: $0.name, y: Double($0.cents))
            }
        )
        return AXChartDescriptor(
            title: "Spending Breakdown",
            summary: "Shows distribution of spending across categories",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
