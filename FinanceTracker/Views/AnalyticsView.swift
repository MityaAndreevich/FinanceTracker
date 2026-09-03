//
//  AnalyticsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//
//  Brief 28H redesign: three premium Swift Charts screens behind a segmented
//  switcher — Pulse (this-month cash flow), Breakdown (category donut), and
//  Horizon (12-month trend with haptic scrubbing). All money is read from the
//  app-wide defaultCurrencyCode; balances redact in the App Switcher.
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.locale) private var locale

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    // Monthly budget (cents) — same key the Dashboard hero reads. When set it
    // anchors the spending-pace baseline; 0 means "no budget" (pace falls back to
    // prior spend history). Item 3.
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents: Int = 0

    /// MONTH-SCOPED, not unscoped (2026-07-25 freeze fix). Only Pulse and
    /// Breakdown read live rows, and both are current-month surfaces. The two
    /// figures that need more history are computed off-main instead:
    ///
    ///   • Pace's all-time prior-spend baseline  → `LedgerAggregator.safeToSpendAggregate`
    ///   • Horizon's 12 monthly aggregates       → `LedgerAggregator.horizonSeries`
    ///
    /// Both return small Sendable value types, so a year of rows never has to
    /// sit in a live `@Query` to produce twelve pairs of Ints.
    ///
    /// MEASURED (8k rows, ~1.1k split purchases, iPhone 17 Pro sim): a QuickAdd
    /// save cost +926ms while this screen was merely ALIVE in the TabView —
    /// off-screen, on the Dashboard. Only ~110ms of that was `recompute()`; the
    /// rest was SwiftData re-running the unscoped 8k-row fetch + sort on the
    /// main actor on every write, a cost no probe inside `recompute()` can see.
    /// Scoping to 12 months took the per-save delta to 433ms; scoping to the
    /// month took it the rest of the way.
    @Query private var transactions: [Transaction]

    init() {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart) ?? .distantFuture
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.date >= monthStart && $0.date < nextMonthStart },
            sort: \Transaction.date,
            order: .reverse
        )
    }

    @State private var screen: Screen = .pulse

    // Cached derived data — recomputed on appear and when inputs change, not on
    // every body redraw.
    @State private var pulseDaily: [AnalyticsPulseView.DailyTotal] = []
    @State private var pulseNetCents: Int = 0
    // Gross month totals for the Pulse summary rows. Kept separate from the net-per-day
    // series so same-day income + expense don't cancel out and hide the income (Item 3).
    @State private var pulseEarnedCents: Int = 0
    @State private var pulseSpentCents: Int = 0
    @State private var breakdownCategories: [AnalyticsBreakdownView.CategoryTotal] = []
    @State private var horizonMonths: [AnalyticsHorizonView.MonthlyTotal] = []
    // Spending-velocity verdict for the Pulse screen (Item 3).
    @State private var pace: PaceMetric.State = .unavailable

    /// All-time prior-spend baseline for Pace, computed OFF the main actor.
    /// nil until the first pass lands — which `PaceMetric` already models
    /// correctly as `.unavailable` ("not enough history to judge", cue hidden),
    /// so a not-yet-loaded baseline shows nothing rather than a wrong number.
    @State private var priorAggregate: SafeToSpend.Aggregate?
    @State private var aggregator: LedgerAggregator?
    @State private var aggregateTask: Task<Void, Never>?

    enum Screen: String, CaseIterable, Identifiable {
        case pulse, breakdown, horizon
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .pulse: return "analytics.pulse.title"
            case .breakdown: return "analytics.breakdown.title"
            case .horizon: return "analytics.horizon.title"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("analytics.screen.picker", selection: $screen) {
                ForEach(Screen.allCases) { s in
                    Text(s.titleKey).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if transactions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(Color.bcPage.ignoresSafeArea())
        // Swipe cycles the three sub-screens (wrap-around). Chart scrubbing inside
        // Pulse/Horizon is a descendant gesture and wins over this paging, so a
        // horizontal drag on a chart scrubs; a drag on inert area pages.
        .horizontalSwipeNavigation(
            onNext: { cycleScreen(forward: true) },
            onPrevious: { cycleScreen(forward: false) }
        )
        .sensoryFeedback(.selection, trigger: screen)
        .navigationTitle("title.analytics")
        .onAppear {
            #if DEBUG
            // Screenshot frame #4 is the category breakdown — open it directly.
            if ScreenshotMode.requestedScreen == .analytics { screen = .breakdown }
            #endif
            clearPendingIntentPeriod()
            recompute()
            refreshPriorAggregate()
        }
        .onDisappear { aggregateTask?.cancel() }
        .onChange(of: transactions) { _, _ in
            recompute()
            refreshPriorAggregate()
        }
        .onChange(of: defaultCurrencyCode) { _, _ in recompute() }
        .onChange(of: monthlyBudgetCents) { _, _ in recompute() }
        .onChange(of: locale) { _, _ in recompute() }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .pulse:
            AnalyticsPulseView(
                dailyTotals: pulseDaily,
                netCents: pulseNetCents,
                earnedCents: pulseEarnedCents,
                spentCents: pulseSpentCents,
                currencyCode: defaultCurrencyCode,
                pace: pace
            )
        case .breakdown:
            if breakdownCategories.isEmpty {
                centeredHint("analytics.empty.no_expenses")
            } else {
                AnalyticsBreakdownView(
                    categories: breakdownCategories,
                    currencyCode: defaultCurrencyCode
                )
            }
        case .horizon:
            AnalyticsHorizonView(
                monthlyTotals: horizonMonths,
                currencyCode: defaultCurrencyCode
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 40)
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.bcAccent)
            Text("analytics.empty.title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)
            Text("analytics.empty.caption")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centeredHint(_ key: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Color.bcTextMuted)
            Text(key)
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Swipe navigation

    /// Cycles to the adjacent sub-screen, wrapping around at the ends.
    private func cycleScreen(forward: Bool) {
        let all = Screen.allCases
        guard let index = all.firstIndex(of: screen) else { return }
        let count = all.count
        let target = forward ? (index + 1) % count : (index - 1 + count) % count
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            screen = all[target]
        }
    }

    // MARK: - Deep link

    /// The old period-scoped analytics honored a pending period from the Siri
    /// "show spending" intent. The redesigned screens use fixed windows, so we
    /// just consume the key to keep it from going stale.
    private func clearPendingIntentPeriod() {
        UserDefaults.appGroup.removeObject(forKey: "pendingAnalyticsPeriod")
    }

    // MARK: - Off-main prior-spend baseline

    /// Coalesced, off-main refresh of Pace's all-time baseline. Same shape as
    /// `ProactiveAlertRefreshScheduler`: a burst of saves collapses to one pass,
    /// the full-table read happens on `LedgerAggregator`'s executor, and only a
    /// three-Int value type crosses back to the main actor.
    ///
    /// Deliberately NOT folded into `recompute()`: that runs synchronously for
    /// the three scoped series, and making it async would put a hop between a
    /// keystroke-speed input change and the chart redraw for no benefit.
    private func refreshPriorAggregate() {
        aggregateTask?.cancel()
        aggregateTask = Task { @MainActor in
            // Short window: this only feeds a pace cue, and a save burst during
            // rapid entry should cost ONE full-table pass, not one per save.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            // Pre-migration launches reach here while the store is still gated;
            // never let this be the first container touch.
            guard let container = SharedModelContainer.readyContainer() else { return }
            if aggregator == nil { aggregator = LedgerAggregator(modelContainer: container) }
            guard let aggregator else { return }

            let now = Date()
            // nil = unsummable ledger; `priorAggregate` is already optional and
            // Pace simply does not render without it.
            let aggregate = await aggregator.safeToSpendAggregate(now: now)
            let horizon = await aggregator.horizonSeries(now: now)
            guard !Task.isCancelled else { return }

            priorAggregate = aggregate
            horizonMonths = horizon.map {
                .init(date: $0.monthStart, incomeCents: $0.incomeCents, expenseCents: $0.expenseCents)
            }
            // Only Pace depends on the aggregate; Pulse and Breakdown are driven
            // by the month-scoped @Query and are unaffected by this pass.
            let cal = Calendar.current
            let today = cal.startOfDay(for: now)
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? today
            recomputePace(cal: cal, monthStart: monthStart, today: today)
        }
    }

    // MARK: - Recompute

    private func recompute() {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))
            ?? today

        // Probe (2026-07-25 freeze report, candidate A). This whole block runs
        // on the main actor over an UNSCOPED @Query, fired by
        // `.onChange(of: transactions)` — i.e. once per save. Sub-spans are
        // measured individually so a capture says WHICH quarter is expensive,
        // not just that the screen is slow.
        hangProbe("Analytics.recompute", rows: transactions.count) {
            hangProbe("Analytics.pulse", rows: transactions.count) {
                recomputePulse(cal: cal, monthStart: monthStart, today: today)
            }
            hangProbe("Analytics.breakdown", rows: transactions.count) {
                recomputeBreakdown(cal: cal, monthStart: monthStart, today: today)
            }
            // Horizon is NOT here any more: it needs 12 months of rows, which is
            // exactly what forced the query to be wide. It is now produced by
            // `LedgerAggregator.horizonSeries` on the actor's executor and
            // arrives as 12 Sendable value types.
            hangProbe("Analytics.pace", rows: transactions.count) {
                recomputePace(cal: cal, monthStart: monthStart, today: today)
            }
        }
    }

    /// Spending-velocity for the current month. The baseline is the user's budget
    /// prorated per day when a budget is set, otherwise their prior daily spend
    /// (all expense before this month ÷ the day-span it covers) — see
    /// `PaceMetric.baselineDailyCents`. `recomputePulse` runs first, so
    /// `pulseSpentCents` (this month's gross spend) is current.
    private func recomputePace(cal: Calendar, monthStart: Date, today: Date) {
        // Days elapsed this month, today inclusive (the day-to-date window).
        let elapsedDays = (cal.dateComponents([.day], from: monthStart, to: today).day ?? 0) + 1

        // Prior-history baseline. This is the ONE figure on this screen that is
        // genuinely all-time, and it used to be derived by walking the whole
        // `transactions` array on the main actor — which is why the @Query had
        // to be unscoped in the first place. It now arrives from
        // `LedgerAggregator` (off-main), whose `SafeToSpend.aggregate` computes
        // priorExpense / earliestPriorDay / priorSpanDays with byte-identical
        // semantics to the loop this replaced — same single source of the
        // arithmetic the Dashboard hero already uses.
        //
        // nil (first pass not landed) → 0/0 → `baselineDailyCents` returns 0 →
        // `.unavailable` → the cue hides. Correct: no baseline is not a pace.
        let priorExpense = priorAggregate?.priorExpenseCents ?? 0
        let priorSpanDays = priorAggregate?.priorSpanDays ?? 0
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        // Budget-prorated baseline when a budget is set, else the prior daily rate.
        let baselineDaily = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: monthlyBudgetCents,
            daysInMonth: daysInMonth,
            priorExpenseCents: priorExpense,
            priorSpanDays: priorSpanDays
        )

        pace = PaceMetric.evaluate(
            spentThisPeriodCents: pulseSpentCents,
            elapsedDays: elapsedDays,
            baselineDailyCents: baselineDaily
        )
    }

    private func recomputePulse(cal: Calendar, monthStart: Date, today: Date) {
        // Accumulation extracted to AnalyticsSeries (design doc §8.1) so the
        // SplitCanary suite pins the production formula. Category-blind.
        let pulse = AnalyticsSeries.pulse(
            transactions: transactions, calendar: cal, monthStart: monthStart, today: today
        )
        pulseEarnedCents = pulse.earnedCents
        pulseSpentCents = pulse.spentCents
        pulseDaily = pulse.daily.map { .init(date: $0.date, cents: $0.cents) }
        pulseNetCents = pulse.netCents
    }

    private func recomputeBreakdown(cal: Calendar, monthStart: Date, today: Date) {
        struct Acc { var name: String; var symbol: String; var color: Color; var cents: Int; var isIncome: Bool }
        // Income and expense categories carry distinct UUIDs in this app's taxonomy,
        // so a single uuid-keyed dictionary never merges directions. The Breakdown
        // view filters by `isIncome` for its segmented Expenses/Income control.
        var sums: [UUID: Acc] = [:]

        // A-path (design doc §2.4 A1): a split purchase's money lands in the
        // splits' categories via CategoryAttribution; nil categories fold into
        // the reserved uncategorized bucket.
        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            for share in CategoryAttribution.shares(for: tx) {
                let key = share.category.bucketID
                var cur = sums[key]
                    ?? Acc(name: share.category.displayNameOrFallback(locale: locale),
                           symbol: share.category.symbolNameOrFallback,
                           color: share.category.themeColorOrFallback,
                           cents: 0, isIncome: tx.isIncome)
                cur.cents += share.amountCents
                sums[key] = cur
            }
        }

        breakdownCategories = sums.map { id, acc in
            .init(id: id, name: acc.name, symbol: acc.symbol, cents: acc.cents, isIncome: acc.isIncome, color: acc.color)
        }
    }

    // `recomputeHorizon` intentionally no longer exists. It fed `horizonMonths`
    // from the live `@Query`, which is precisely why that query had to hold a
    // year of rows. The series is now produced by `LedgerAggregator.horizonSeries`
    // in `refreshPriorAggregate()`; leaving a main-actor twin behind would be an
    // invitation to reintroduce the wide query.
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
