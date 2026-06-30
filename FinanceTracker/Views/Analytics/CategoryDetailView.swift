//
//  CategoryDetailView.swift
//  FinanceTracker
//
//  Drill-down from the Breakdown donut: the this-month transactions that make
//  up a single category's slice. Scoped to the same window the donut uses
//  (current month up to today) so the header total matches the tapped slice.
//  Filters by the category's stable UUID, not its localized display name.
//  Brief 28I Section M3.
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let categoryUUID: UUID
    let categoryName: String     // localized display name, for the title + header
    let currencyCode: String

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    /// Same window as AnalyticsView.recomputeBreakdown: current month start … today.
    private var monthWindow: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? today
        return (start, today)
    }

    private var filtered: [Transaction] {
        let window = monthWindow
        let cal = Calendar.current
        return allTransactions.filter { tx in
            guard tx.category.uuid == categoryUUID else { return false }
            let day = cal.startOfDay(for: tx.date)
            return day >= window.start && day <= window.end
        }
    }

    /// Sum of the magnitudes — matches the donut slice value (Money.format unsigned).
    private var totalCents: Int {
        filtered.reduce(0) { $0 + $1.amountCents }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text("analytics.category_total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Money.format(cents: totalCents, currencyCode: currencyCode))
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .privacySensitive(true)
                    Text(String(format: NSLocalizedString("analytics.transactions_count", comment: ""), filtered.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            // Stable uuid identity, not the default persistentModelID (temporary
            // until save) — avoids transient ghost rows at scale (Round 9).
            ForEach(filtered, id: \.uuid) { tx in
                TransactionRow(tx: tx)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
