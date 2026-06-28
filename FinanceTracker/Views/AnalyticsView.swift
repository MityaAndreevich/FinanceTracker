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
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("analytics.empty.title")
                .font(.headline)
            Text("analytics.empty.caption")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func centeredHint(_ key: LocalizedStringKey) -> some View {
        VStack {
            Spacer(minLength: 48)
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            dayNet[day, default: 0] += tx.signedAmountCents
        }

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
        struct Acc { var name: String; var symbol: String; var cents: Int; var isIncome: Bool }
        // Income and expense categories carry distinct UUIDs in this app's taxonomy,
        // so a single uuid-keyed dictionary never merges directions. The Breakdown
        // view filters by `isIncome` for its segmented Expenses/Income control.
        var sums: [UUID: Acc] = [:]

        for tx in transactions {
            let day = cal.startOfDay(for: tx.date)
            guard day >= monthStart && day <= today else { continue }
            let cat = tx.category
            var cur = sums[cat.uuid]
                ?? Acc(name: cat.displayName(locale: locale), symbol: cat.icon ?? "tag.fill", cents: 0, isIncome: tx.isIncome)
            cur.cents += tx.amountCents
            sums[cat.uuid] = cur
        }

        breakdownCategories = sums.map { id, acc in
            .init(id: id, name: acc.name, symbol: acc.symbol, cents: acc.cents, isIncome: acc.isIncome)
        }
    }

    private func recomputeHorizon(cal: Calendar, monthStart: Date) {
        guard let horizonStart = cal.date(byAdding: .month, value: -11, to: monthStart) else {
            horizonMonths = []
            return
        }

        var monthNet: [Date: Int] = [:]
        for tx in transactions {
            guard let mStart = cal.date(from: cal.dateComponents([.year, .month], from: tx.date)) else { continue }
            guard mStart >= horizonStart && mStart <= monthStart else { continue }
            monthNet[mStart, default: 0] += tx.signedAmountCents
        }

        var out: [AnalyticsHorizonView.MonthlyTotal] = []
        var cursor = horizonStart
        while cursor <= monthStart {
            out.append(.init(date: cursor, netCents: monthNet[cursor] ?? 0))
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
