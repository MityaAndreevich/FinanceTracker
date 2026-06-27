//
//  AnalyticsBreakdownView.swift
//  FinanceTracker
//
//  Analytics screen 2 of 3 — "The Breakdown". This-month category totals as a
//  donut (SectorMark). A segmented control switches between Expenses and Income
//  so the two directions are never mixed: expense slices are hierarchical red,
//  income slices hierarchical green (opacity by rank, not hue). Tap a legend row
//  to focus a slice. VoiceOver-accessible via AXChartDescriptor. Brief 28J P2.
//

import SwiftUI
import Charts

struct AnalyticsBreakdownView: View {
    let categories: [CategoryTotal]
    let currencyCode: String

    @State private var typeFilter: TypeFilter = .expense
    @State private var selectedCategory: CategoryTotal?

    struct CategoryTotal: Identifiable, Hashable {
        let id: UUID
        let name: String
        let symbol: String
        let cents: Int          // positive magnitude
        let isIncome: Bool
    }

    enum TypeFilter: String, CaseIterable, Identifiable {
        case expense, income
        var id: String { rawValue }
        var labelKey: LocalizedStringKey {
            switch self {
            case .expense: return "analytics.filter.expense"
            case .income:  return "analytics.filter.income"
            }
        }
    }

    private var filteredCategories: [CategoryTotal] {
        categories.filter { typeFilter == .income ? $0.isIncome : !$0.isIncome }
    }

    private var sortedCategories: [CategoryTotal] {
        filteredCategories.sorted { $0.cents > $1.cents }
    }

    private var total: Int {
        filteredCategories.reduce(0) { $0 + $1.cents }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                typePicker

                if sortedCategories.isEmpty {
                    emptyHint
                } else {
                    donutChart
                    legend
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var typePicker: some View {
        Picker("analytics.filter.picker", selection: $typeFilter) {
            ForEach(TypeFilter.allCases) { filter in
                Text(filter.labelKey).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: typeFilter) { _, _ in
            // A focused slice from one direction makes no sense after switching.
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
        }
    }

    private var emptyHint: some View {
        Text(typeFilter == .income ? "analytics.empty.no_income" : "analytics.empty.no_expenses")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 48)
            .padding(.horizontal, 24)
    }

    private var donutChart: some View {
        Chart(sortedCategories) { cat in
            SectorMark(
                angle: .value("analytics.axis.amount", cat.cents),
                innerRadius: .ratio(0.62),
                angularInset: 2.5
            )
            .cornerRadius(6)
            // Hierarchical by rank — red for expenses, green for income.
            .foregroundStyle(color(for: cat))
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

    /// Expense = red, income = green; magnitude rank fades opacity so the biggest
    /// slice reads strongest. Mirrors the +/− color language used elsewhere.
    private func color(for cat: CategoryTotal) -> Color {
        let base: Color = cat.isIncome ? .bcIncome : .bcExpense
        return base.opacity(opacityForRank(cat))
    }

    private func opacityForRank(_ cat: CategoryTotal) -> Double {
        guard let rank = sortedCategories.firstIndex(of: cat) else { return 0.35 }
        // Most spent/earned = full color, each lower rank a little more transparent.
        return max(0.35, 1.0 - (Double(rank) * 0.12))
    }

    private var legend: some View {
        VStack(spacing: 8) {
            ForEach(sortedCategories) { cat in
                NavigationLink {
                    CategoryDetailView(
                        categoryUUID: cat.id,
                        categoryName: cat.name,
                        currencyCode: currencyCode
                    )
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: cat.symbol)
                            .font(.body)
                            .foregroundStyle(color(for: cat))
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
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    // Also focus the matching donut slice on tap.
                    withAnimation(.easeInOut(duration: 0.25)) { selectedCategory = cat }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
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
            summary: "Shows distribution across categories",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
