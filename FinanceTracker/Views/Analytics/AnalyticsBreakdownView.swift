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

    // Bug 4 ext: Swift Charts captures Locale at first render and ignores later
    // environment(\.locale) updates, so labels stay stale until restart. Key the
    // chart on the active language to discard + rebuild it on a live switch.
    // Bug 3's fix covered Pulse + Horizon; Breakdown was missed.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    struct CategoryTotal: Identifiable, Hashable {
        let id: UUID
        let name: String
        let symbol: String
        let cents: Int          // positive magnitude
        let isIncome: Bool
        let color: Color        // distinct per-category hue (P1 theme map)

        // Identity is the category UUID; Color isn't reliably Hashable, so equate
        // and hash on id alone (every field is derived from the same category).
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

    /// Stable identity for the synthesized "Other" bucket. A fixed sentinel UUID so
    /// the aggregate slice equates/hashes consistently and never collides with a
    /// real category UUID.
    static let otherBucketID = UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!

    /// Cap the donut at a handful of named slices + a single aggregated "Other"
    /// bucket so a long tail of tiny categories can't shatter the ring into
    /// unreadable slivers (Item 4). Pure + locale-free: the caller supplies the
    /// localized label + a neutral color. Input is assumed sorted descending.
    ///
    /// - `maxNamed` categories keep their own slice; the remainder collapses into
    ///   "Other". A single leftover category is shown directly rather than hidden
    ///   behind a vague "Other" (so ≤ `maxNamed`+1 passes through untouched).
    static func displaySlices(
        from sorted: [CategoryTotal],
        maxNamed: Int = 5,
        otherName: String,
        otherColor: Color
    ) -> [CategoryTotal] {
        guard sorted.count > maxNamed + 1 else { return sorted }
        let named = Array(sorted.prefix(maxNamed))
        let otherCents = sorted.dropFirst(maxNamed).reduce(0) { $0 + $1.cents }
        guard otherCents > 0 else { return named }
        let other = CategoryTotal(
            id: otherBucketID,
            name: otherName,
            symbol: "ellipsis",
            cents: otherCents,
            isIncome: named.first?.isIncome ?? false,
            color: otherColor
        )
        return named + [other]
    }

    /// The slices actually shown — top categories + an "Other" aggregate. Drives
    /// both the donut and the legend so the two never disagree.
    private var displayCategories: [CategoryTotal] {
        Self.displaySlices(
            from: sortedCategories,
            otherName: String(localized: "analytics.breakdown.other"),
            otherColor: .bcTextMuted
        )
    }

    /// Categories safe to plot as a donut: non-positive magnitudes dropped, and a
    /// zero-total set collapsed to empty so the `SectorMark` angular domain is
    /// never degenerate (0/0 sweep angle → EXC_BREAKPOINT inside Charts).
    private var renderableCategories: [CategoryTotal] {
        ChartGuards.renderableSlices(displayCategories, magnitude: \.cents)
    }

    private var total: Int {
        filteredCategories.reduce(0) { $0 + $1.cents }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                typePicker

                if renderableCategories.isEmpty {
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
        Chart(renderableCategories) { cat in
            SectorMark(
                angle: .value("analytics.axis.amount", cat.cents),
                innerRadius: .ratio(0.62),
                angularInset: 2.5
            )
            .cornerRadius(6)
            // Multi-color: one distinct category hue per slice (P1 theme map),
            // replacing the old monochrome red/green-by-rank.
            .foregroundStyle(cat.color)
            .opacity(selectedCategory == nil || selectedCategory == cat ? 1.0 : 0.35)
        }
        .frame(height: 280)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    // Bound the label to the donut's inner hole so the amount
                    // scales down to fit instead of bleeding under the ring at
                    // large Dynamic Type sizes (innerRadius ratio is 0.62).
                    let holeDiameter = min(frame.width, frame.height) * 0.62
                    centerLabel
                        .frame(maxWidth: holeDiameter * 0.9)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .accessibilityChartDescriptor(self)
        .id(localizedBundle.languageCode ?? "system")
    }

    @ViewBuilder
    private var centerLabel: some View {
        VStack(spacing: 4) {
            if let selected = selectedCategory {
                Image(systemName: selected.symbol)
                    .font(.title2)
                    .foregroundStyle(selected.color)
                Text(selected.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcTextSecondary)
                // Compact so a large magnitude never clips inside the donut hole
                // (device QA Item 4: "1 003 893,9…" truncated). The full amount is
                // shown untruncated in the legend row for this category.
                Text(Money.formatCompact(cents: selected.cents, currencyCode: currencyCode))
                    .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                    .foregroundStyle(Color.bcTextPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .privacySensitive(true)
            } else {
                Text("analytics.total")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcTextSecondary)
                    .textCase(.uppercase)
                Text(Money.formatCompact(cents: total, currencyCode: currencyCode))
                    .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                    .foregroundStyle(Color.bcTextPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .privacySensitive(true)
            }
        }
    }

    /// Largest category magnitude — the progress bars are drawn relative to this so
    /// the top category fills its bar and the rest read as proportions of it.
    private var maxCents: Int { sortedCategories.first?.cents ?? 0 }

    private var legend: some View {
        VStack(spacing: 8) {
            ForEach(displayCategories) { cat in
                if cat.id == Self.otherBucketID {
                    // The "Other" aggregate has no single category to drill into, so
                    // it's a plain focusable row (tap dims the ring to its slice) —
                    // no chevron, no navigation.
                    legendRow(cat)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { selectedCategory = cat }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                } else {
                    NavigationLink {
                        CategoryDetailView(
                            categoryUUID: cat.id,
                            categoryName: cat.name,
                            currencyCode: currencyCode
                        )
                    } label: {
                        legendRow(cat)
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
    }

    /// A category tile row: colored icon tile + name + % + amount, over a thin
    /// category-colored progress bar. Solid surface + 1px border, no gradients.
    private func legendRow(_ cat: CategoryTotal) -> some View {
        let fraction = maxCents > 0 ? min(max(Double(cat.cents) / Double(maxCents), 0), 1) : 0
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(cat.color.opacity(0.16))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: cat.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(cat.color)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcTextPrimary)
                        .lineLimit(1)
                    Text(percentLabel(cat))
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(Color.bcTextSecondary)
                }

                Spacer(minLength: 8)

                Text(Money.format(cents: cat.cents, currencyCode: currencyCode))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.bcTextPrimary)
                    .privacySensitive(true)

                if cat.id != Self.otherBucketID {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.bcTextMuted)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bcSurface2)
                    Capsule()
                        .fill(cat.color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.bcSurface1)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.bcDivider, lineWidth: 1)
        )
    }

    private func percentLabel(_ cat: CategoryTotal) -> String {
        Self.percentString(cents: cat.cents, total: total)
    }

    /// A category's share of the total as a whole-percent label. A real (non-zero)
    /// share that rounds below 1% reads "<1%", never a misleading "0%" — the device
    /// bug where a single 1M outlier flattened every other row to "0%" (Item 4).
    static func percentString(cents: Int, total: Int) -> String {
        guard total > 0, cents > 0 else { return "0%" }
        let pct = (Double(cents) / Double(total) * 100).rounded()
        return pct < 1 ? "<1%" : "\(Int(pct))%"
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
