//
//  SplitCanaryTests.swift
//  FinanceTrackerTests
//
//  THE B-PATH DOUBLE-COUNT DETECTORS (design doc §8, token-discipline §12).
//
//  Splitting a transaction across categories must move money BETWEEN categories
//  and never change any category-blind number. Every test here compares a
//  baseline store (A) against a mirror store (B) that is identical except that
//  several transactions carry splits — with no parent field changed. If any of
//  the seven "must NOT change" paths (§2.4-B) is ever routed through split rows,
//  a canary in this file fails loudly with exact Int-cents inequality.
//
//  BUILD ORDER (§13): this suite lands BEFORE the TransactionSplit schema. Until
//  the schema exists, `SplitMirrorFixture.applySplits` is the documented no-op
//  and every mirror comparison is the identity — the canaries pass trivially and
//  become live tripwires the moment the schema + fixture splits land (same
//  commit). The pure-core conservation tests below exercise real splits TODAY
//  via CategoryAttribution.SplitInput, no model needed.
//

import Foundation
import Testing
import SwiftData
import UserNotifications
@testable import FinanceTracker

// MARK: - Fixture

/// Two on-disk-shaped (in-memory) stores with byte-identical deterministic
/// ledgers; `applySplits` decorates store B's transactions with splits WITHOUT
/// touching any parent field. All expected literals are computed by the fixture
/// itself (never via production code) so the canaries compare production output
/// against independent arithmetic.
@MainActor
struct SplitMirrorFixture {

    let container: ModelContainer
    let now: Date
    /// Independent hand-summed literals (not derived from production code).
    let expectedMonthExpenseCents: Int
    let expectedMonthIncomeCents: Int
    let expectedPriorExpenseCents: Int
    let seededTransactionCount: Int
    /// True once `applySplits` actually created splits (step 5 flips this on).
    let hasSplits: Bool

    /// Seeds one ledger. Same inputs → same ledger, so two calls make a mirror.
    static func make(applySplitsToStore: Bool) throws -> SplitMirrorFixture {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
            configurations: config
        )
        let ctx = container.mainContext
        let now = Date()

        let food = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        let home = FinanceTracker.Category(name: "Home", kindRaw: "expense", order: 1)
        let health = FinanceTracker.Category(name: "Health", kindRaw: "expense", order: 2)
        let salary = FinanceTracker.Category(name: "Salary", kindRaw: "income", order: 3)
        [food, home, health, salary].forEach { ctx.insert($0) }

        // This month (all timestamped `now` — today by construction, so every
        // month-window in the app includes them regardless of the test date).
        let amazonOrder = Transaction(typeRaw: "expense", amountCents: 12_000, currency: "USD",
                                      date: now, category: food, merchant: "Amazon")
        let hardware = Transaction(typeRaw: "expense", amountCents: 5_000, currency: "USD",
                                   date: now, category: home, merchant: "Hardware")
        let clinic = Transaction(typeRaw: "expense", amountCents: 3_000, currency: "USD",
                                 date: now, category: health, merchant: "Clinic")
        let coffee = Transaction(typeRaw: "expense", amountCents: 700, currency: "USD",
                                 date: now, category: food, merchant: "Cafe")
        let pay = Transaction(typeRaw: "income", amountCents: 250_000, currency: "USD",
                              date: now, category: salary)

        // Prior month (safely out of any current-month window).
        let daySeconds: TimeInterval = 24 * 60 * 60
        let past = now.addingTimeInterval(-45 * daySeconds)
        let oldRent = Transaction(typeRaw: "expense", amountCents: 20_000, currency: "USD",
                                  date: past, category: home)
        let oldPay = Transaction(typeRaw: "income", amountCents: 100_000, currency: "USD",
                                 date: past, category: salary)

        let all = [amazonOrder, hardware, clinic, coffee, pay, oldRent, oldPay]
        all.forEach { ctx.insert($0) }
        try ctx.save()

        var hasSplits = false
        if applySplitsToStore {
            hasSplits = try applySplits(amazonOrder: amazonOrder, hardware: hardware,
                                        home: home, health: health, food: food, in: ctx)
        }

        return SplitMirrorFixture(
            container: container,
            now: now,
            expectedMonthExpenseCents: 12_000 + 5_000 + 3_000 + 700,   // 20 700
            expectedMonthIncomeCents: 250_000,
            expectedPriorExpenseCents: 20_000,
            seededTransactionCount: all.count,
            hasSplits: hasSplits
        )
    }

    /// Decorate store B with splits — NO parent field changes.
    ///
    /// `amazonOrder` (12 000, Food): 4 000 → Home, 1 800 → Health, remainder
    /// 6 200 stays Food. `hardware` (5 000, Home): 2 500 → Food, remainder
    /// 2 500 stays Home. The deliberate over-sum case lives in its own
    /// targeted test, never in this mirror — its category totals would
    /// legitimately differ and poison the equality assertions.
    private static func applySplits(
        amazonOrder: Transaction, hardware: Transaction,
        home: FinanceTracker.Category, health: FinanceTracker.Category,
        food: FinanceTracker.Category, in ctx: ModelContext
    ) throws -> Bool {
        let s1 = TransactionSplit(amountCents: 4_000, category: home, note: "cable", order: 0)
        let s2 = TransactionSplit(amountCents: 1_800, category: health, note: "vitamins", order: 1)
        let s3 = TransactionSplit(amountCents: 2_500, category: food, note: "snacks", order: 0)
        [s1, s2, s3].forEach { ctx.insert($0) }
        s1.parent = amazonOrder
        s2.parent = amazonOrder
        s3.parent = hardware
        try ctx.save()
        return true
    }

    /// The current-month subset, the way month-scoped consumers see it.
    func monthTransactions() throws -> [Transaction] {
        let cal = Calendar.current
        let all = try container.mainContext.fetch(FetchDescriptor<Transaction>())
        return all.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    func allTransactions() throws -> [Transaction] {
        try container.mainContext.fetch(FetchDescriptor<Transaction>())
    }
}

// MARK: - Pure-core conservation (real splits today, no model needed)

@Suite("CategoryAttribution pure core — conservation invariant")
struct CategoryAttributionConservationTests {

    private let catA = UUID()
    private let catB = UUID()
    private let parent = UUID()
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func total(_ rows: [CategoryAttribution.Row]) -> Int {
        rows.reduce(0) { $0 + $1.amountCents }
    }

    @Test func noSplitsIsTheIdentityDecomposition() {
        let rows = CategoryAttribution.rows(
            totalCents: 12_000, parentCategoryUUID: parent, date: day, isIncome: false, splits: []
        )
        #expect(rows == [CategoryAttribution.Row(
            amountCents: 12_000, categoryUUID: parent, date: day, isIncome: false)])
    }

    @Test func partialSplitCarriesRemainderInParentCategory() {
        let rows = CategoryAttribution.rows(
            totalCents: 12_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 4_000, categoryUUID: catA),
                     .init(amountCents: 1_800, categoryUUID: catB)]
        )
        #expect(total(rows) == 12_000, "conservation: Σ rows == parent total")
        #expect(rows.last == CategoryAttribution.Row(
            amountCents: 6_200, categoryUUID: parent, date: day, isIncome: false),
            "the unassigned remainder stays in the purchase's own category")
    }

    @Test func exactSplitHasNoRemainderRow() {
        let rows = CategoryAttribution.rows(
            totalCents: 6_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 4_000, categoryUUID: catA),
                     .init(amountCents: 2_000, categoryUUID: catB)]
        )
        #expect(rows.count == 2)
        #expect(total(rows) == 6_000)
    }

    @Test func overSumIsTruncatedSoAttributionStillConservesTheTotal() {
        // Σ splits > total can only come from a bug (or a future sync merge) —
        // the editor forbids saving it. The read side must STILL conserve:
        // splits consume the total in order with a running cap, truncated at
        // the boundary, never scaled, never over-counting the grand total.
        let rows = CategoryAttribution.rows(
            totalCents: 5_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 4_000, categoryUUID: catA),
                     .init(amountCents: 3_000, categoryUUID: catB)]
        )
        #expect(total(rows) == 5_000, "over-sum input must still sum to EXACTLY the parent total")
        #expect(rows == [
            CategoryAttribution.Row(amountCents: 4_000, categoryUUID: catA, date: day, isIncome: false),
            CategoryAttribution.Row(amountCents: 1_000, categoryUUID: catB, date: day, isIncome: false),
        ])

        // A split entirely past the boundary contributes nothing.
        let past = CategoryAttribution.rows(
            totalCents: 3_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 3_000, categoryUUID: catA),
                     .init(amountCents: 500, categoryUUID: catB)]
        )
        #expect(total(past) == 3_000)
        #expect(past.count == 1)
    }

    @Test func nilSplitCategoryFallsBackToParentCategory() {
        // A split whose category was deleted (or hasn't synced yet) must keep
        // its money visible in the purchase's own category.
        let rows = CategoryAttribution.rows(
            totalCents: 5_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 2_000, categoryUUID: nil)]
        )
        #expect(rows == [
            CategoryAttribution.Row(amountCents: 2_000, categoryUUID: parent, date: day, isIncome: false),
            CategoryAttribution.Row(amountCents: 3_000, categoryUUID: parent, date: day, isIncome: false),
        ])
    }

    @Test func nonPositiveSplitAmountsAreIgnored() {
        let rows = CategoryAttribution.rows(
            totalCents: 5_000, parentCategoryUUID: parent, date: day, isIncome: false,
            splits: [.init(amountCents: 0, categoryUUID: catA),
                     .init(amountCents: -100, categoryUUID: catB)]
        )
        #expect(rows == [CategoryAttribution.Row(
            amountCents: 5_000, categoryUUID: parent, date: day, isIncome: false)])
    }
}

// MARK: - The seven canaries (mirror-store equality)

@Suite("Split canaries — B-paths must be unchanged by splitting", .serialized)
@MainActor
struct SplitCanaryTests {

    private final class SpyCenter: NotificationScheduling, @unchecked Sendable {
        var removed: [[String]] = []
        var requests: [UNNotificationRequest] = []
        func removePending(identifiers: [String]) { removed.append(identifiers) }
        func schedule(_ request: UNNotificationRequest) { requests.append(request) }
    }

    // C1 — SafeToSpend + LedgerAggregator ------------------------------------

    @Test func safeToSpendAggregateIsIdenticalOnSplitMirror() async throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        let aggA = SafeToSpend.aggregate(entries: SafeToSpend.entries(from: try a.allTransactions()), now: a.now)
        let aggB = SafeToSpend.aggregate(entries: SafeToSpend.entries(from: try b.allTransactions()), now: b.now)

        #expect(aggA.spentThisMonthCents == aggB.spentThisMonthCents)
        #expect(aggA.priorExpenseCents == aggB.priorExpenseCents)
        #expect(aggA.priorSpanDays == aggB.priorSpanDays)
        // Against independent arithmetic, not just each other:
        #expect(aggB.spentThisMonthCents == b.expectedMonthExpenseCents)
        #expect(aggB.priorExpenseCents == b.expectedPriorExpenseCents)

        // The actor path must agree with the pure path on the split store —
        // catches a split-join sneaking into the actor's fetch specifically.
        let actor = LedgerAggregator(modelContainer: b.container)
        let offMain = await actor.safeToSpendAggregate(now: b.now)
        #expect(offMain.spentThisMonthCents == aggB.spentThisMonthCents)
        #expect(offMain.priorExpenseCents == aggB.priorExpenseCents)
        #expect(offMain.priorSpanDays == aggB.priorSpanDays)
    }

    @Test func entriesCountEqualsTransactionCountNeverRowCount() throws {
        // The most likely "helpful fix": expanding SafeToSpend.entries per split.
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        let txs = try b.allTransactions()
        #expect(SafeToSpend.entries(from: txs).count == txs.count)
        #expect(txs.count == b.seededTransactionCount)
    }

    // C2 — Dashboard month totals + the cross-check ---------------------------

    @Test func monthTotalsAreUnchangedBySplitting() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        #expect(try MonthTotals.expenseCents(a.monthTransactions())
             == MonthTotals.expenseCents(try b.monthTransactions()))
        #expect(try MonthTotals.incomeCents(a.monthTransactions())
             == MonthTotals.incomeCents(try b.monthTransactions()))
        #expect(try MonthTotals.expenseCents(b.monthTransactions()) == b.expectedMonthExpenseCents)
        #expect(try MonthTotals.incomeCents(b.monthTransactions()) == b.expectedMonthIncomeCents)
    }

    /// The strongest single assertion in the plan (§8.2 C2): the split-aware
    /// A-side (attribution shares — what both donuts sum) must equal the
    /// parent-summed B-side (month expense total). Fails if the A-side
    /// under/over-attributes OR the B-side double-counts.
    @Test func donutAttributionSumEqualsMonthExpenseTotal() throws {
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        let month = try b.monthTransactions()

        let attributionSum = month
            .filter { !$0.isIncome }
            .flatMap { CategoryAttribution.shares(for: $0) }
            .reduce(0) { $0 + $1.amountCents }

        #expect(attributionSum == MonthTotals.expenseCents(month))
        #expect(attributionSum == b.expectedMonthExpenseCents)
    }

    /// Store-level conservation: every transaction's attribution rows sum back
    /// to its own amount (no-over-sum fixture ⇒ exact equality).
    @Test func attributionConservationHoldsPerTransaction() throws {
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        for tx in try b.allTransactions() {
            let sum = CategoryAttribution.rows(for: tx).reduce(0) { $0 + $1.amountCents }
            #expect(sum == tx.amountCents, "attribution must conserve \(tx.merchant ?? "tx")")
        }
    }

    // C3 — Proactive alerts end-to-end + pace ---------------------------------

    @Test func alertPlanIsIdenticalOnSplitMirror() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        func plan(_ fixture: SplitMirrorFixture, suite: String) throws -> SpyCenter {
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set(true, forKey: "alertsEnabled")
            defaults.set(500_000, forKey: "monthlyBudgetCents")   // remaining > 0
            defaults.set("USD", forKey: "defaultCurrencyCode")
            let center = SpyCenter()
            ProactiveAlertRefresher.refresh(
                modelContext: fixture.container.mainContext,
                isAllowed: true,
                defaults: defaults,
                now: fixture.now,
                center: center
            )
            return center
        }

        let centerA = try plan(a, suite: "split-canary-a-\(UUID().uuidString)")
        let centerB = try plan(b, suite: "split-canary-b-\(UUID().uuidString)")

        #expect(centerA.requests.count == centerB.requests.count)
        // Body equality is A-vs-B, never vs. an English literal (locale rule).
        #expect(centerA.requests.map(\.content.body) == centerB.requests.map(\.content.body))
        #expect(
            centerA.requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
         == centerB.requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
        )
    }

    @Test func paceStateIsIdenticalOnSplitMirror() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        func pace(_ fixture: SplitMirrorFixture) throws -> PaceMetric.State {
            let agg = SafeToSpend.aggregate(
                entries: SafeToSpend.entries(from: try fixture.allTransactions()), now: fixture.now
            )
            let snapshot = SafeToSpend.snapshot(
                monthlyBudgetCents: 500_000,
                spentThisMonthCents: agg.spentThisMonthCents,
                priorExpenseCents: agg.priorExpenseCents,
                priorSpanDays: agg.priorSpanDays,
                now: fixture.now
            )
            let baseline = PaceMetric.baselineDailyCents(
                monthlyBudgetCents: snapshot.monthlyBudgetCents,
                daysInMonth: snapshot.daysInMonth,
                priorExpenseCents: snapshot.priorExpenseCents,
                priorSpanDays: snapshot.priorSpanDays
            )
            return PaceMetric.evaluate(
                spentThisPeriodCents: snapshot.spentCents,
                elapsedDays: snapshot.elapsedDays,
                baselineDailyCents: baseline
            )
        }

        #expect(try pace(a) == pace(b))
    }

    // C4 — Analytics time series ----------------------------------------------

    @Test func timeSeriesAreUnchangedBySplitting() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        let cal = Calendar.current
        let today = cal.startOfDay(for: a.now)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: a.now)) ?? today

        let pulseA = AnalyticsSeries.pulse(transactions: try a.allTransactions(),
                                           calendar: cal, monthStart: monthStart, today: today)
        let pulseB = AnalyticsSeries.pulse(transactions: try b.allTransactions(),
                                           calendar: cal, monthStart: monthStart, today: today)
        #expect(pulseA == pulseB)
        #expect(pulseB.spentCents == b.expectedMonthExpenseCents)
        #expect(pulseB.earnedCents == b.expectedMonthIncomeCents)

        let horizonA = AnalyticsSeries.horizon(transactions: try a.allTransactions(),
                                               calendar: cal, monthStart: monthStart)
        let horizonB = AnalyticsSeries.horizon(transactions: try b.allTransactions(),
                                               calendar: cal, monthStart: monthStart)
        #expect(horizonA == horizonB)
    }

    // C5 — Widget snapshot totals / ring / hero -------------------------------

    @Test func netSnapshotTotalsRingHeroAreIdenticalOnSplitMirror() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        let locale = Locale(identifier: "en_US")

        let snapA = NetSnapshotBuilder.build(transactions: try a.allTransactions(),
                                             currencyCode: "USD",
                                             monthlyBudgetCents: 500_000,
                                             locale: locale)
        let snapB = NetSnapshotBuilder.build(transactions: try b.allTransactions(),
                                             currencyCode: "USD",
                                             monthlyBudgetCents: 500_000,
                                             locale: locale)

        #expect(snapA.spentText == snapB.spentText)
        #expect(snapA.earnedText == snapB.earnedText)
        #expect(snapA.heroLabel == snapB.heroLabel)
        #expect(snapA.heroAmount == snapB.heroAmount)
        #expect(snapA.heroSubtitle == snapB.heroSubtitle)
        #expect(snapA.heroIsAlert == snapB.heroIsAlert)
        #expect(snapA.ringFraction == snapB.ringFraction)
        #expect(snapA.ringIsNeutral == snapB.ringIsNeutral)
        #expect(snapA.spendSeries == snapB.spendSeries)
    }

    // Vacuity guard — the mirror must actually split, or every green canary
    // above is meaningless. The A-path top-categories list is EXPECTED to
    // differ between the stores; if a fixture refactor ever stops creating
    // splits, this fails first.
    @Test func fixtureIsNotVacuous_topCategoriesDiffer() throws {
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)
        #expect(b.hasSplits, "the mirror fixture must create real splits")

        let locale = Locale(identifier: "en_US")
        let snapA = NetSnapshotBuilder.build(transactions: try a.allTransactions(),
                                             currencyCode: "USD", monthlyBudgetCents: 0, locale: locale)
        let snapB = NetSnapshotBuilder.build(transactions: try b.allTransactions(),
                                             currencyCode: "USD", monthlyBudgetCents: 0, locale: locale)
        #expect(snapA.topCategories != snapB.topCategories,
                "splitting moves money between categories — the A-path must see it")
    }

    /// Over-sum, store-level (user hardening request): even a transaction whose
    /// splits EXCEED its total must attribute exactly its own amount — the
    /// running-cap truncation, verified against the real model. The editor
    /// forbids saving this state; the read side must conserve regardless.
    @Test func overSumSplitsStillConserveTheParentTotalAtStoreLevel() throws {
        let fixture = try SplitMirrorFixture.make(applySplitsToStore: false)
        let ctx = fixture.container.mainContext
        let categories = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        let food = try #require(categories.first { $0.name == "Food" })
        let home = try #require(categories.first { $0.name == "Home" })

        let tx = Transaction(typeRaw: "expense", amountCents: 5_000, currency: "USD",
                             date: fixture.now, category: food, merchant: "OverSum")
        ctx.insert(tx)
        let s1 = TransactionSplit(amountCents: 4_000, category: home, order: 0)
        let s2 = TransactionSplit(amountCents: 3_000, category: food, order: 1)
        [s1, s2].forEach { ctx.insert($0) }
        s1.parent = tx
        s2.parent = tx
        try ctx.save()

        let shares = CategoryAttribution.shares(for: tx)
        #expect(shares.reduce(0) { $0 + $1.amountCents } == 5_000,
                "attribution must sum to EXACTLY the transaction total, even on over-sum input")
        #expect(shares.map(\.amountCents) == [4_000, 1_000])
    }

    // C6 — Counts -------------------------------------------------------------

    @Test func transactionCountIsUnchangedBySplitting() throws {
        // Pins everything that counts the Transaction entity (review-prompt
        // counter, free-tier caps, dashboard count) transitively: splits are
        // NOT transactions and must never inflate a fetchCount.
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        let countA = try a.container.mainContext.fetchCount(FetchDescriptor<Transaction>())
        let countB = try b.container.mainContext.fetchCount(FetchDescriptor<Transaction>())
        #expect(countA == countB)
        #expect(countB == b.seededTransactionCount)
    }

    // C7 — Import content-dedup -----------------------------------------------

    @Test func importContentDedupIsIdenticalOnSplitMirror() throws {
        // A foreign CSV imported twice content-matches itself on the second
        // pass; the matcher sees parent content only, so a split transaction
        // in the store must not change what gets flagged.
        let a = try SplitMirrorFixture.make(applySplitsToStore: false)
        let b = try SplitMirrorFixture.make(applySplitsToStore: true)

        let foreign = Data("""
        date,type,amount,currency,category,source,tax,note,merchant
        2023-11-14,expense,12.34,USD,Food,,0.00,,Cafe
        """.utf8)

        func flaggedCountAfterDoubleImport(_ fixture: SplitMirrorFixture) throws -> (imported: Int, flagged: Int) {
            let ctx = fixture.container.mainContext
            _ = try CSVImportService.importCSV(modelContext: ctx, data: foreign)
            let second = try CSVImportService.importCSV(modelContext: ctx, data: foreign)
            let flagged = try ctx.fetch(FetchDescriptor<Transaction>())
                .filter { $0.isPossibleDuplicate }.count
            return (second.imported, flagged)
        }

        let resultA = try flaggedCountAfterDoubleImport(a)
        let resultB = try flaggedCountAfterDoubleImport(b)
        #expect(resultA.imported == resultB.imported)
        #expect(resultA.flagged == resultB.flagged)
    }
}
