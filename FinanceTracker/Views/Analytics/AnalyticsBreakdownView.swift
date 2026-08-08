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
    // Whether the "Other" aggregate row is unfolded into its tail categories
    // (device QA 2026-07-23 #1/#2: a small — often freshly split — category was
    // unreachable because the fold had no way in).
    @State private var otherExpanded = false

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

    /// The categories folded into the "Other" aggregate, in rank order — empty
    /// when no fold happened. Mirrors `displaySlices`' fold condition exactly so
    /// the expanded legend and the donut can never disagree about what "Other"
    /// contains. Pure + static for the same reason `displaySlices` is.
    static func foldedTail(
        from sorted: [CategoryTotal],
        maxNamed: Int = 5
    ) -> [CategoryTotal] {
        guard sorted.count > maxNamed + 1 else { return [] }
        return Array(sorted.dropFirst(maxNamed))
    }

    /// Tail rows revealed when the "Other" legend row is expanded.
    private var foldedTailCategories: [CategoryTotal] {
        Self.foldedTail(from: sortedCategories)
    }

    /// The slices actually shown — top categories + an "Other" aggregate. Drives
    /// both the donut and the legend so the two never disagree.
    private var displayCategories: [CategoryTotal] {
        Self.displaySlices(
            from: sortedCategories,
            otherName: String(localized: "analytics.breakdown.other", bundle: localizedBundle.bundle),
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

                // ChartBisection is a no-op in RELEASE; in DEBUG it switches this
                // chart off on device to attribute the Charts EXC_BREAKPOINT.
                let _ = ChartBisection.probe(.breakdownDonut, cents: renderableCategories.map(\.cents))
                if renderableCategories.isEmpty || !ChartBisection.isEnabled(.breakdownDonut) {
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
            // A focused slice or an unfolded "Other" from one direction makes no
            // sense after switching.
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = nil
                otherExpanded = false
            }
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
        .chartBackground { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    // Bound the label to the donut's inner hole so the amount
                    // scales down to fit instead of bleeding under the ring at
                    // large Dynamic Type sizes (innerRadius ratio is 0.62).
                    // Clamped: the plot frame is derived from a proposed size, so
                    // a collapsed parent would otherwise put a NaN/negative width
                    // straight into a frame.
                    let holeDiameter = ChartGuards.dimension(min(frame.width, frame.height) * 0.62)
                    centerLabel
                        .frame(maxWidth: ChartGuards.dimension(holeDiameter * 0.9))
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .accessibilityChartDescriptor(self)
        // Never hand Charts a degenerate box — see ChartGuards.canRenderInBox.
        .guardedChartFrame()
        .frame(height: 280)
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
                    // The "Other" aggregate has no single category to drill into.
                    // Tapping unfolds it in place: the tail categories appear as
                    // ordinary navigable rows (and the ring focuses the slice) —
                    // a small/split category is never sealed inside the fold.
                    legendRow(cat)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                otherExpanded.toggle()
                                selectedCategory = otherExpanded ? cat : nil
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        // NOTE: no accessibility modifiers here — adding a trait to
                        // the row wraps it into ONE combined element and strips the
                        // inner texts from the hierarchy (VoiceOver + XCUI).

                    if otherExpanded {
                        ForEach(foldedTailCategories) { tail in
                            NavigationLink {
                                CategoryDetailView(
                                    categoryUUID: tail.id,
                                    categoryName: tail.name,
                                    currencyCode: currencyCode
                                )
                            } label: {
                                legendRow(tail)
                                    // Slight inset: these rows belong to the fold above.
                                    .padding(.leading, 10)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
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
                    Text(subtitleLabel(cat))
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

                if cat.id == Self.otherBucketID {
                    // Disclosure, not navigation: points down, flips when unfolded.
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.bcTextMuted)
                        .rotationEffect(.degrees(otherExpanded ? 180 : 0))
                } else {
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
                        // See DashboardView.budgetProgressBar: the proposed width
                        // is the untrusted input here, not `fraction`.
                        .frame(width: ChartGuards.dimension(geo.size.width * fraction))
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

    /// Row subtitle: percent share for a real category; for the "Other" fold,
    /// how many categories it hides ("+4 more") ahead of the percent — the cue
    /// that the row opens.
    private func subtitleLabel(_ cat: CategoryTotal) -> String {
        guard cat.id == Self.otherBucketID else { return percentLabel(cat) }
        let more = String(
            format: NSLocalizedString("analytics.breakdown.other.more.format", comment: ""),
            foldedTailCategories.count
        )
        return "\(more) · \(percentLabel(cat))"
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
