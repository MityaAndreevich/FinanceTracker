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

    /// A-path (design doc §2.4 A4): a purchase belongs here if ANY of its
    /// attribution shares lands in this category — so a split Amazon order
    /// shows up under Health when its vitamins do.
    private var filtered: [Transaction] {
        let window = monthWindow
        let cal = Calendar.current
        return allTransactions.filter { tx in
            let day = cal.startOfDay(for: tx.date)
            guard day >= window.start && day <= window.end else { return false }
            return attributedCents(of: tx) > 0
        }
    }

    /// This category's PORTION of one purchase (the whole amount for an
    /// unsplit transaction; only the matching shares for a split one).
    private func attributedCents(of tx: Transaction) -> Int {
        CategoryAttribution.shares(for: tx)
            .filter { $0.category.bucketID == categoryUUID }
            .reduce(0) { $0 + $1.amountCents }
    }

    /// Sum of the ATTRIBUTED magnitudes — matches the donut slice value, and
    /// now also matches Σ(rows), because every row below prints its own share.
    ///
    /// It used to be only the first of those. A $120 order with $18 attributed
    /// here added $18 to the header while its row showed the full $120, and a
    /// footnote under the list excused the difference. The first real user to
    /// meet it (1.0.3 device QA: a 1000₽ Perekrestok split 500 Pets / 500 Food)
    /// read the 1000 against a 500 header as a double-count and never scrolled
    /// far enough to find the footnote. In a list already narrowed to ONE
    /// category, every number on screen is now that category's.
    private var totalCents: Int {
        filtered.reduce(0) { $0 + attributedCents(of: $1) }
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
            // No footer any more: it existed only to excuse header ≠ Σ(rows),
            // which passing the share below makes impossible.
            Section {
                ForEach(filtered, id: \.uuid) { tx in
                    // The row still opens the WHOLE purchase for edit, which is
                    // why it keeps the full amount visible in its split context
                    // line rather than just swapping the number out.
                    CategoryTileRow(tx: tx, attributedCents: attributedCents(of: tx))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
