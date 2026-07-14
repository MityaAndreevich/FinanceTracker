//
//  DaySpendingSheet.swift
//  FinanceTracker
//
//  Tap-to-expand from the Pulse cash-flow chart: a bottom sheet listing the
//  transactions that make up one day's net, with a per-category breakdown bar
//  chart. Analogous to MonthDetailSheet but scoped to a single day. Reads the
//  app-wide currency (never a hardcoded code). Brief 28H Overnight Polish P0.3.
//

import SwiftUI
import SwiftData
import Charts

struct DaySpendingSheet: View {
    let day: Date
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    // Bug 4 ext: rebuild the bar chart on a live language switch so the category
    // axis labels re-format under the new locale (Swift Charts otherwise caches
    // the Locale from first render).
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    private var dayRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private var filtered: [Transaction] {
        let range = dayRange
        return allTransactions.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var netCents: Int {
        filtered.reduce(0) { $0 + $1.signedAmountCents }
    }

    // Per-category magnitude for the breakdown bars (expenses + income shown
    // by absolute size; color encodes direction).
    private struct CategorySlice: Identifiable {
        let id: UUID
        let name: String
        let symbol: String
        let color: Color
        let cents: Int
        let isIncome: Bool
    }

    private var categorySlices: [CategorySlice] {
        struct Acc { var name: String; var symbol: String; var color: Color; var cents: Int; var isIncome: Bool }
        var sums: [UUID: Acc] = [:]
        for tx in filtered {
            let cat = tx.category
            var cur = sums[cat.uuid]
                ?? Acc(name: cat.displayName(locale: locale), symbol: cat.symbolName, color: cat.themeColor, cents: 0, isIncome: tx.isIncome)
            cur.cents += tx.amountCents
            sums[cat.uuid] = cur
        }
        return sums
            .map { CategorySlice(id: $0.key, name: $0.value.name, symbol: $0.value.symbol, color: $0.value.color, cents: $0.value.cents, isIncome: $0.value.isIncome) }
            .sorted { $0.cents > $1.cents }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .listRowBackground(Color.clear)
                }

                // ChartBisection is a no-op in RELEASE; in DEBUG it switches this
                // chart off on device to attribute the Charts EXC_BREAKPOINT.
                if categorySlices.count > 1, ChartBisection.isEnabled(.daySpending) {
                    Section("analytics.day.by_category") {
                        breakdownChart
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    // Stable uuid identity, not the default persistentModelID
                    // (temporary until save) — avoids transient ghost rows at scale.
                    ForEach(filtered, id: \.uuid) { tx in
                        NavigationLink {
                            TransactionDetailView(tx: tx)
                        } label: {
                            CategoryTileRow(tx: tx)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
            Text(Money.formatSigned(
                cents: netCents,
                isPositive: netCents >= 0,
                currencyCode: currencyCode
            ))
            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.moneyDirectional(isPositive: netCents >= 0))
            .privacySensitive(true)
            Text(String(format: NSLocalizedString("analytics.transactions_count", comment: ""), filtered.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var breakdownChart: some View {
        Chart(categorySlices) { slice in
            BarMark(
                x: .value("analytics.axis.amount", slice.cents),
                y: .value("analytics.axis.category", slice.name)
            )
            .cornerRadius(5)
            .foregroundStyle(slice.color)
            .annotation(position: .trailing, alignment: .leading) {
                Text(Money.format(cents: slice.cents, currencyCode: currencyCode))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .privacySensitive(true)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .guardedChartFrame()
        .frame(height: ChartGuards.dimension(CGFloat(max(1, categorySlices.count)) * 38 + 16))
        .padding(.vertical, Spacing.xs)
        .id(localizedBundle.languageCode ?? "system")
    }
}
