//
//  SearchAttributionCanaryTests.swift
//  FinanceTrackerTests
//
//  THE SEARCH-VS-ANALYTICS AGREEMENT CANARY (2026-07-23 hands-on report).
//
//  The defect this pins: searching a category name and opening that category in
//  Analytics disagreed for the same category. A 3,500 "Кошачий корм" filed under
//  Питомцы and split 1500/2000 into two other categories contributes NOTHING to
//  Питомцы — Analytics excluded it (`CategoryDetailView` requires attributed
//  cents > 0), search still matched it because the parent's own `category` field
//  said Питомцы. Both numbers were individually defensible; the pair was not.
//
//  The contract, in one line: a purchase is findable by a category name if and
//  only if that category receives money from it — the SAME rule Analytics
//  aggregates by. `TransactionSearch.searchableFields` and
//  `CategoryAttribution.shares` must therefore never drift apart.
//
//  This is deliberately a MEMBERSHIP comparison, not a total comparison. Row
//  amounts stay whole (a 3,500 purchase is 3,500 on its row) and day subtotals
//  stay parent-summed — routing either through attribution is the double-count
//  the SplitCanary suite exists to catch. What must agree is WHICH purchases
//  belong to a category, which is exactly what disagreed.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@MainActor
struct SearchAttributionCanaryTests {

    /// The founder's exact reported shape, with the real names.
    private struct PetsFixture {
        let container: ModelContainer
        let pets: FinanceTracker.Category
        let dryFood: FinanceTracker.Category
        let wetFood: FinanceTracker.Category
        /// 3,500 under Пwith a FULL 1500+2000 split → Питомцы gets 0.
        let fullySplit: Transaction
        /// 2,856 under Питомцы, unsplit → Питомцы gets all of it.
        let unsplit: Transaction
        /// 1,000 under Питомцы, split 400 to Сухой корм → Питомцы keeps 600.
        let partiallySplit: Transaction
    }

    private static func makeFixture() throws -> PetsFixture {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
            configurations: config
        )
        let ctx = container.mainContext

        let pets = FinanceTracker.Category(name: "Питомцы", kindRaw: "expense", order: 0)
        let dryFood = FinanceTracker.Category(name: "Сухой корм", kindRaw: "expense", order: 1)
        let wetFood = FinanceTracker.Category(name: "Влажный корм", kindRaw: "expense", order: 2)
        [pets, dryFood, wetFood].forEach(ctx.insert)

        func tx(_ cents: Int, _ merchant: String, _ category: FinanceTracker.Category) -> Transaction {
            let t = Transaction(
                typeRaw: "expense", amountCents: cents, currency: "RUB", date: Date(),
                category: category, source: nil, taxCents: nil, note: nil,
                merchant: merchant, recurrenceRaw: nil
            )
            ctx.insert(t)
            return t
        }
        func split(_ cents: Int, _ category: FinanceTracker.Category, on parent: Transaction, order: Int) {
            let s = TransactionSplit(amountCents: cents, category: category, order: order)
            ctx.insert(s)
            s.parent = parent
        }

        let fullySplit = tx(350_000, "Кошачий корм", pets)
        split(150_000, dryFood, on: fullySplit, order: 0)
        split(200_000, wetFood, on: fullySplit, order: 1)

        let unsplit = tx(285_600, "Ветеринар", pets)

        let partiallySplit = tx(100_000, "Зоомагазин", pets)
        split(40_000, dryFood, on: partiallySplit, order: 0)

        try ctx.save()
        return PetsFixture(container: container, pets: pets, dryFood: dryFood, wetFood: wetFood,
                           fullySplit: fullySplit, unsplit: unsplit, partiallySplit: partiallySplit)
    }

    // MARK: - The two production rules, side by side

    /// Search membership, exactly as `TransactionsView.filteredPass` computes it.
    private static func searchMatches(_ tx: Transaction, query: String) -> Bool {
        TransactionSearch.matches(
            query: query,
            fields: TransactionSearch.searchableFields(for: tx),
            amountCents: tx.amountCents
        )
    }

    /// Analytics membership, exactly as `CategoryDetailView.filtered` computes it.
    private static func analyticsAttributedCents(_ tx: Transaction, to uuid: UUID) -> Int {
        CategoryAttribution.shares(for: tx)
            .filter { $0.category.bucketID == uuid }
            .reduce(0) { $0 + $1.amountCents }
    }

    // MARK: - Canaries

    @Test("A fully-split purchase is absent from BOTH surfaces for its zero-remainder category")
    func fullySplitIsAbsentFromBoth() throws {
        let f = try Self.makeFixture()

        #expect(Self.analyticsAttributedCents(f.fullySplit, to: f.pets.uuid) == 0)
        #expect(Self.searchMatches(f.fullySplit, query: "Питомцы") == false)

        // ...and present in both for the categories that DID receive the money.
        #expect(Self.analyticsAttributedCents(f.fullySplit, to: f.dryFood.uuid) == 150_000)
        #expect(Self.searchMatches(f.fullySplit, query: "Сухой корм"))
        #expect(Self.searchMatches(f.fullySplit, query: "Влажный корм"))
    }

    @Test("Membership agrees for every purchase × every category")
    func membershipAgreesAcrossTheMatrix() throws {
        let f = try Self.makeFixture()
        let all = [f.fullySplit, f.unsplit, f.partiallySplit]

        for category in [f.pets, f.dryFood, f.wetFood] {
            for tx in all {
                let inAnalytics = Self.analyticsAttributedCents(tx, to: category.uuid) > 0
                let inSearch = Self.searchMatches(tx, query: category.name)
                #expect(
                    inAnalytics == inSearch,
                    """
                    "\(tx.merchant ?? "?")" disagrees for "\(category.name)": \
                    analytics=\(inAnalytics) search=\(inSearch). Search membership and \
                    CategoryAttribution.shares have drifted apart.
                    """
                )
            }
        }
    }

    @Test("The founder's reported totals now match")
    func reportedTotalsMatch() throws {
        let f = try Self.makeFixture()
        let all = [f.fullySplit, f.unsplit, f.partiallySplit]

        // Analytics: Питомцы keeps only what it is attributed — 2,856 + 600.
        let analyticsTotal = all.reduce(0) { $0 + Self.analyticsAttributedCents($1, to: f.pets.uuid) }
        #expect(analyticsTotal == 285_600 + 60_000)

        // Search: the same purchases, and only those. Rows keep their FULL
        // amounts (2,856 and 1,000) — a row shows what the purchase cost, which
        // is why this sum is larger than the attributed one and must not be
        // "fixed" to match it. What agrees is the SET, not the arithmetic.
        let searched = all.filter { Self.searchMatches($0, query: "Питомцы") }
        #expect(searched.count == 2)
        #expect(searched.contains { $0.uuid == f.unsplit.uuid })
        #expect(searched.contains { $0.uuid == f.partiallySplit.uuid })
        #expect(searched.reduce(0) { $0 + $1.amountCents } == 285_600 + 100_000)
    }

    @Test("Unsplit purchases behave exactly as before splits existed")
    func unsplitIsUnchanged() throws {
        let f = try Self.makeFixture()
        #expect(Self.searchMatches(f.unsplit, query: "Питомцы"))
        #expect(Self.searchMatches(f.unsplit, query: "Ветеринар"))
        #expect(Self.searchMatches(f.unsplit, query: "2856"))
        #expect(Self.searchMatches(f.unsplit, query: "Сухой корм") == false)
    }

    @Test("A split's descriptive note stays searchable regardless of attribution")
    func splitNotesRemainSearchable() throws {
        let f = try Self.makeFixture()
        let parts = CategoryAttribution.orderedSplits(of: f.fullySplit)
        parts.first?.note = "HDMI cable"

        // A label the user typed on this purchase is not a claim about where the
        // money went, so it is findable even though Питомцы is not.
        #expect(Self.searchMatches(f.fullySplit, query: "HDMI"))
        #expect(Self.searchMatches(f.fullySplit, query: "Питомцы") == false)
    }
}
