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
                currencyCode: defaultCurrencyCode
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
    }

    private func recomputePulse(cal: Calendar, monthStart: Date, today: Date) {
        var dayNet: [Date: Int] = [:]
        // Gross totals accumulated per-transaction (not from the netted day buckets),
        // so an income logged on the same day as larger expenses still counts toward
        // Earned instead of being cancelled out (Item 3).
        var earned = 0
        var spent = 0
        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            dayNet[day, default: 0] += tx.signedAmountCents
            if tx.isIncome {
                earned += tx.amountCents
            } else {
                spent += tx.amountCents
            }
        }
        pulseEarnedCents = earned
        pulseSpentCents = spent

        var out: [AnalyticsPulseView.DailyTotal] = []
        var cursor = monthStart
        while cursor <= today {
            out.append(.init(date: cursor, cents: dayNet[cursor] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        pulseDaily = out
        pulseNetCents = out.reduce(0) { $0 + $1.cents }
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
        guard let horizonStart = cal.date(byAdding: .month, value: -11, to: monthStart) else {
            horizonMonths = []
            return
        }

        // Track income and expense magnitudes separately so the Horizon mode
        // toggle (Net / Expenses / Income / Combined) can plot each absolute
        // series; net is derived as income − expense.
        struct MonthAcc { var income = 0; var expense = 0 }
        var monthAcc: [Date: MonthAcc] = [:]
        for tx in transactions {
            guard let mStart = cal.date(from: cal.dateComponents([.year, .month], from: tx.date)) else { continue }
            guard mStart >= horizonStart && mStart <= monthStart else { continue }
            if tx.isIncome {
                monthAcc[mStart, default: MonthAcc()].income += tx.amountCents
            } else {
                monthAcc[mStart, default: MonthAcc()].expense += tx.amountCents
            }
        }

        var out: [AnalyticsHorizonView.MonthlyTotal] = []
        var cursor = horizonStart
        while cursor <= monthStart {
            let acc = monthAcc[cursor] ?? MonthAcc()
            out.append(.init(date: cursor, incomeCents: acc.income, expenseCents: acc.expense))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        horizonMonths = out
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
