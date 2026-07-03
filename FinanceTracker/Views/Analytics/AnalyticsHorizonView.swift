//
//  AnalyticsHorizonView.swift
//  FinanceTracker
//
//  Analytics screen 3 of 3 — "The Horizon". 12-month trend with Apple
//  Stocks-style haptic scrubbing: drag across the line to read any month.
//  A mode toggle (Net / Expenses / Income / Combined) lets users read the
//  net flow or isolate the absolute income / expense trends. Balances are
//  .privacySensitive(). Brief 28H addendum (research-validated).
//

import SwiftUI
import Charts

struct AnalyticsHorizonView: View {
    let monthlyTotals: [MonthlyTotal]   // 12 months
    let currencyCode: String

    // Which trend to draw. Persisted so the user's last choice survives tab
    // switches and relaunches.
    @AppStorage("horizon_mode") private var mode: HorizonMode = .net

    // `chartXSelection` resets its binding to nil the instant the finger lifts,
    // which made the selection (and the tappable tooltip/Show-details affordance)
    // vanish on touch-end. We treat `rawSelectedDate` as the *transient* scrub
    // position and commit it into `stickySelectedDate`, which persists until the
    // user scrubs elsewhere or explicitly clears. (Apple Health-style sticky.)
    // The selection is keyed by *date*, so switching mode keeps it — every mode
    // shares the same month axis.
    @State private var rawSelectedDate: Date?
    @State private var stickySelectedDate: Date?
    @State private var detailMonth: MonthlyTotal?

    // Bug 3 (P2): observe in-app language to force a chart rebuild on language
    // switch — Swift Charts caches `.dateTime.month(.abbreviated)` locale at
    // first render and ignores `environment(\.locale)` updates.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    struct MonthlyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let incomeCents: Int    // absolute income magnitude for the month
        let expenseCents: Int   // absolute expense magnitude for the month
        var netCents: Int { incomeCents - expenseCents }
    }

    enum HorizonMode: String, CaseIterable, Identifiable {
        case net, expenses, income, combined
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .net: return "analytics.horizon.mode.net"
            case .expenses: return "analytics.horizon.mode.expenses"
            case .income: return "analytics.horizon.mode.income"
            case .combined: return "analytics.horizon.mode.combined"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            tooltipBar
            trendChart
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
        .sheet(item: $detailMonth) { month in
            MonthDetailSheet(month: month, currencyCode: currencyCode)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Mode toggle

    private var modePicker: some View {
        // Label key is reused (hidden) so no new localization key is introduced.
        Picker("analytics.horizon.title", selection: $mode) {
            ForEach(HorizonMode.allCases) { m in
                Text(m.titleKey).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Tooltip / drill-down affordance

    @ViewBuilder
    private var tooltipBar: some View {
        if let selected = selectedTotal {
            let headline = headlineValue(for: selected)
            Button {
                detailMonth = selected
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Text(selected.date.formatted(.dateTime.month(.wide).year()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(headline.text)
                            .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(headline.color)
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

    /// The big headline number + color for the selected month, per mode.
    private func headlineValue(for total: MonthlyTotal) -> (text: String, color: Color) {
        switch mode {
        case .net, .combined:
            return (Money.formatSigned(cents: total.netCents,
                                       isPositive: total.netCents >= 0,
                                       currencyCode: currencyCode),
                    Color.moneyDirectional(isPositive: total.netCents >= 0))
        case .expenses:
            return (Money.formatSigned(cents: total.expenseCents,
                                       isPositive: false,
                                       currencyCode: currencyCode),
                    .bcDanger)
        case .income:
            return (Money.formatSigned(cents: total.incomeCents,
                                       isPositive: true,
                                       currencyCode: currencyCode),
                    .bcPositive)
        }
    }

    // MARK: - Chart

    private var trendChart: some View {
        Chart {
            chartMarks
            selectionMarks
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
        // Bug 3: rebuild on language switch so month axis re-formats.
        .id(localizedBundle.languageCode ?? "system")
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

    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        switch mode {
        case .net:
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

        case .expenses:
            ForEach(monthlyTotals) { item in
                LineMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.expenseCents)
                )
                .foregroundStyle(Color.bcDanger)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.expenseCents)
                )
                .foregroundStyle(solidAreaGradient(.bcDanger))
                .interpolationMethod(.catmullRom)
            }

        case .income:
            ForEach(monthlyTotals) { item in
                LineMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.incomeCents)
                )
                .foregroundStyle(Color.bcPositive)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.incomeCents)
                )
                .foregroundStyle(solidAreaGradient(.bcPositive))
                .interpolationMethod(.catmullRom)
            }

        case .combined:
            // Two overlaid lines, no area fill. `series:` keeps them as distinct
            // lines rather than one zig-zag.
            ForEach(monthlyTotals) { item in
                LineMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.incomeCents),
                    series: .value("series", "income")
                )
                .foregroundStyle(Color.bcPositive)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }
            ForEach(monthlyTotals) { item in
                LineMark(
                    x: .value("analytics.axis.month", item.date),
                    y: .value("analytics.axis.amount", item.expenseCents),
                    series: .value("series", "expense")
                )
                .foregroundStyle(Color.bcDanger)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    @ChartContentBuilder
    private var selectionMarks: some ChartContent {
        if let selectedTotal {
            RuleMark(x: .value("analytics.axis.month", selectedTotal.date))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

            switch mode {
            case .net:
                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.netCents)
                )
                .foregroundStyle(Color.moneyDirectional(isPositive: selectedTotal.netCents >= 0))
                .symbolSize(120)
            case .expenses:
                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.expenseCents)
                )
                .foregroundStyle(Color.bcDanger)
                .symbolSize(120)
            case .income:
                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.incomeCents)
                )
                .foregroundStyle(Color.bcPositive)
                .symbolSize(120)
            case .combined:
                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.incomeCents)
                )
                .foregroundStyle(Color.bcPositive)
                .symbolSize(110)
                PointMark(
                    x: .value("analytics.axis.month", selectedTotal.date),
                    y: .value("analytics.axis.amount", selectedTotal.expenseCents)
                )
                .foregroundStyle(Color.bcDanger)
                .symbolSize(110)
            }
        }
    }

    // MARK: - Sign-aware coloring (Net mode)
    //
    // The Net trend is a single *net* line (income − expense). It used to be
    // drawn entirely in `Color.accentColor`, so a month with net spending looked
    // identical to a month with net income. We split the line/area at the zero
    // line: mint-green (`.bcPositive`) above zero, calm coral (`.bcDanger`) below
    // — the directional red/green language (DESIGN_DIRECTION_v2 §2). Expenses /
    // Income modes plot a single absolute series in one semantic color.

    /// Position of the zero line within the value range, as a fraction from the
    /// top (0) to the bottom (1) of the chart's plotted bounding box.
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
                .init(color: .bcPositive, location: 0),
                .init(color: .bcPositive, location: zeroFraction),
                .init(color: .bcDanger, location: zeroFraction),
                .init(color: .bcDanger, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var netAreaGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .bcPositive.opacity(0.28), location: 0),
                .init(color: .bcPositive.opacity(0.04), location: zeroFraction),
                .init(color: .bcDanger.opacity(0.04), location: zeroFraction),
                .init(color: .bcDanger.opacity(0.28), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Top-down fade for a single-color area fill (Expenses / Income modes).
    private func solidAreaGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.28), color.opacity(0.02)],
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
