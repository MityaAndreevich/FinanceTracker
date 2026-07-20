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

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

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
        }
        .onChange(of: transactions) { _, _ in recompute() }
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

    // MARK: - Recompute

    private func recompute() {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))
            ?? today

        recomputePulse(cal: cal, monthStart: monthStart, today: today)
        recomputeBreakdown(cal: cal, monthStart: monthStart, today: today)
        recomputeHorizon(cal: cal, monthStart: monthStart)
        recomputePace(cal: cal, monthStart: monthStart, today: today)
    }

    /// Spending-velocity for the current month. The baseline is the user's budget
    /// prorated per day when a budget is set, otherwise their prior daily spend
    /// (all expense before this month ÷ the day-span it covers) — see
    /// `PaceMetric.baselineDailyCents`. `recomputePulse` runs first, so
    /// `pulseSpentCents` (this month's gross spend) is current.
    private func recomputePace(cal: Calendar, monthStart: Date, today: Date) {
        // Days elapsed this month, today inclusive (the day-to-date window).
        let elapsedDays = (cal.dateComponents([.day], from: monthStart, to: today).day ?? 0) + 1

        // Prior-history baseline: sum expense before this month + earliest such day.
        var priorExpense = 0
        var earliestPriorDay: Date?
        for tx in transactions where tx.isExpense {
            let day = cal.startOfDay(for: tx.date)
            guard day < monthStart else { continue }
            priorExpense += tx.amountCents
            if let e = earliestPriorDay { earliestPriorDay = min(e, day) } else { earliestPriorDay = day }
        }

        let priorSpanDays = earliestPriorDay
            .flatMap { cal.dateComponents([.day], from: $0, to: monthStart).day } ?? 0
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

        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            let cat = tx.category
            var cur = sums[cat.uuid]
                ?? Acc(name: cat.displayName(locale: locale), symbol: cat.symbolName, color: cat.themeColor, cents: 0, isIncome: tx.isIncome)
            cur.cents += tx.amountCents
            sums[cat.uuid] = cur
        }

        breakdownCategories = sums.map { id, acc in
            .init(id: id, name: acc.name, symbol: acc.symbol, cents: acc.cents, isIncome: acc.isIncome, color: acc.color)
        }
    }

    private func recomputeHorizon(cal: Calendar, monthStart: Date) {
        // Accumulation extracted to AnalyticsSeries (design doc §8.1) so the
        // SplitCanary suite pins the production formula. Category-blind.
        horizonMonths = AnalyticsSeries.horizon(
            transactions: transactions, calendar: cal, monthStart: monthStart
        ).map { .init(date: $0.monthStart, incomeCents: $0.incomeCents, expenseCents: $0.expenseCents) }
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
