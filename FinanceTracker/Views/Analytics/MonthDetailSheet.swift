//
//  MonthDetailSheet.swift
//  FinanceTracker
//
//  Tap-to-expand from the Horizon trend: a bottom sheet listing the
//  transactions that make up one month's net. Filters by month range and
//  reads the app-wide currency (never a hardcoded code). Brief 28I Section M4.
//

import SwiftUI
import SwiftData

struct MonthDetailSheet: View {
    let month: AnalyticsHorizonView.MonthlyTotal
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    private var monthRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month.date)
        let start = cal.date(from: comps) ?? month.date
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    private var filtered: [Transaction] {
        let range = monthRange
        return allTransactions.filter { $0.date >= range.start && $0.date < range.end }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text(month.date.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                        Text(Money.formatSigned(
                            cents: month.netCents,
                            isPositive: month.netCents >= 0,
                            currencyCode: currencyCode
                        ))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(month.netCents >= 0 ? .green : .red)
                        .privacySensitive(true)
                        Text(String(format: NSLocalizedString("analytics.transactions_count", comment: ""), filtered.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                ForEach(filtered) { tx in
                    TransactionRow(tx: tx)
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
}
