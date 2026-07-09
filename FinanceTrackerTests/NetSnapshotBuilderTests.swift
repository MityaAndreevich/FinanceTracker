//
//  NetSnapshotBuilderTests.swift
//  FinanceTrackerTests
//
//  The redesigned widget snapshot: gain-framed safe-to-spend hero, guarded
//  spent-vs-budget ring, top-3 categories with fractions. Ring/fraction math is
//  pure and tested directly; the full build is exercised over an in-memory store.
//

import Testing
import Foundation
import SwiftData
@testable import FinanceTracker

@Suite("NetSnapshotBuilder")
struct NetSnapshotBuilderTests {

    // MARK: - Ring fraction guards (pure)

    @Test func ring_budgetPath_isSpentOverBudget() {
        let r = NetSnapshotBuilder.ringComponents(spentCents: 5_000, budgetCents: 20_000, incomeCents: 0)
        #expect(!r.isNeutral)
        #expect(abs(r.fraction - 0.25) < 0.0001)
    }

    @Test func ring_overBudget_clampsToOne() {
        let r = NetSnapshotBuilder.ringComponents(spentCents: 50_000, budgetCents: 20_000, incomeCents: 0)
        #expect(r.fraction == 1.0)          // never oversized
        #expect(!r.isNeutral)
    }

    @Test func ring_noBudget_fallsBackToSpentOverIncome() {
        let r = NetSnapshotBuilder.ringComponents(spentCents: 4_000, budgetCents: 0, incomeCents: 8_000)
        #expect(!r.isNeutral)
        #expect(abs(r.fraction - 0.5) < 0.0001)
    }

    @Test func ring_noBudget_noIncome_isNeutralNotCrash() {
        let r = NetSnapshotBuilder.ringComponents(spentCents: 4_000, budgetCents: 0, incomeCents: 0)
        #expect(r.isNeutral)                // no NaN, no divide-by-zero
        #expect(r.fraction == 0)
    }

    @Test func ring_zeroBudget_zeroSpend_isSafe() {
        let r = NetSnapshotBuilder.ringComponents(spentCents: 0, budgetCents: 0, incomeCents: 0)
        #expect(r.isNeutral)
        #expect(r.fraction.isFinite)
    }

    // MARK: - Hero precedence (pure)

    /// Identity "compact" so assertions read in whole cents, no locale noise.
    private let cents: (Int) -> String = { "\($0)" }
    /// Identity "localize" so precedence assertions read against the raw keys,
    /// independent of any locale (localization itself is covered by build tests).
    private let key: (String) -> String = { $0 }

    @Test func hero_budgetSet_winsOverIncome_gainFramed() {
        let h = NetSnapshotBuilder.heroComponents(spentCents: 3_000, budgetCents: 10_000, incomeCents: 8_000, localize: key, compact: cents)
        #expect(h.label == "widget.safe_to_spend")
        #expect(h.amount == "7000")          // budget − spent, budget wins over income
        #expect(!h.isAlert)
        #expect(!h.subtitle.isEmpty)
    }

    @Test func hero_noBudget_incomeKnown_gainFramed() {
        let h = NetSnapshotBuilder.heroComponents(spentCents: 194, budgetCents: 0, incomeCents: 2_800, localize: key, compact: cents)
        #expect(h.label == "widget.safe_to_spend")
        #expect(h.amount == "2606")          // the device-QA case: income − spent
        #expect(!h.isAlert)
    }

    @Test func hero_neither_lastResortSpent_noSubtitle() {
        let h = NetSnapshotBuilder.heroComponents(spentCents: 500, budgetCents: 0, incomeCents: 0, localize: key, compact: cents)
        #expect(h.label == "widget.hero.spent")
        #expect(h.amount == "500")
        #expect(h.subtitle.isEmpty)
        #expect(!h.isAlert)
    }

    @Test func hero_overBudget_alert_magnitudeIsOverage() {
        let h = NetSnapshotBuilder.heroComponents(spentCents: 12_000, budgetCents: 10_000, incomeCents: 0, localize: key, compact: cents)
        #expect(h.label == "widget.over_budget")
        #expect(h.amount == "2000")          // abs(remaining)
        #expect(h.isAlert)
    }

    @Test func hero_overIncome_overspentLabel_alert() {
        let h = NetSnapshotBuilder.heroComponents(spentCents: 12_000, budgetCents: 0, incomeCents: 8_000, localize: key, compact: cents)
        #expect(h.label == "widget.overspent")
        #expect(h.amount == "4000")
        #expect(h.isAlert)
    }

    // MARK: - Category fraction guards (pure)

    @Test func categoryFraction_normal() {
        #expect(abs(NetSnapshotBuilder.categoryFraction(cents: 3_000, totalSpentCents: 12_000) - 0.25) < 0.0001)
    }

    @Test func categoryFraction_zeroTotal_isZeroNotNaN() {
        let f = NetSnapshotBuilder.categoryFraction(cents: 3_000, totalSpentCents: 0)
        #expect(f == 0)
        #expect(f.isFinite)
    }

    // MARK: - Content signature (Item 3: edits must invalidate the widget)

    @Test func signature_stableForIdenticalContent() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Toys", 5_000)
        addIncome(ctx, 20_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let a = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 0)
        let b = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 0)
        #expect(a == b)
    }

    @Test func signature_changesWhenAmountEdited_countUnchanged() throws {
        // The exact device bug: an edit that leaves transactions.count invariant.
        let ctx = try makeContext()
        let tx = addExpense(ctx, "Quad bike", 5_000)
        try ctx.save()
        let before = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        tx.amountCents = 100_000_000        // 1,000,000.00 — count does NOT change
        try ctx.save()
        let after = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        #expect(before != after)            // a count-only trigger would miss this
    }

    // Item 3 verification: the trigger must fire on ALL THREE mutation paths.
    // Edit is covered above (the exact device bug). Add + delete already changed
    // transactions.count, so the OLD count trigger caught them — these confirm the
    // new content signature still does, so the fix didn't regress add/delete.

    @Test func signature_changesWhenTransactionAdded() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Food", 5_000)
        try ctx.save()
        let before = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        addExpense(ctx, "Toys", 3_000)      // plain add
        try ctx.save()
        let after = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        #expect(before != after)
    }

    @Test func signature_changesWhenTransactionDeleted() throws {
        let ctx = try makeContext()
        let victim = addExpense(ctx, "Food", 5_000)
        addExpense(ctx, "Toys", 3_000)
        try ctx.save()
        let before = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        ctx.delete(victim)
        try ctx.save()
        let after = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        #expect(before != after)
    }

    @Test func signature_changesWhenCategoryReassigned() throws {
        let ctx = try makeContext()
        let tx = addExpense(ctx, "Food", 5_000)
        let other = FinanceTracker.Category(name: "Uncategorized", kindRaw: "expense", order: 9)
        ctx.insert(other)
        try ctx.save()
        let before = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        tx.category = other                 // recategorize — count unchanged
        try ctx.save()
        let after = NetSnapshotBuilder.contentSignature(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()), currencyCode: "USD", monthlyBudgetCents: 0)

        #expect(before != after)
    }

    @Test func signature_changesWhenBudgetChanges() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Food", 5_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let a = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 0)
        let b = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 200_000)
        #expect(a != b)
    }

    @Test func signature_changesWhenLanguageChanges() throws {
        // Item 5: switching in-app language must rebuild the baked snapshot even
        // though no transaction changed — so language is part of the fingerprint.
        let ctx = try makeContext()
        addExpense(ctx, "Food", 5_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let en = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 0, languageCode: "en")
        let ru = NetSnapshotBuilder.contentSignature(transactions: all, currencyCode: "USD", monthlyBudgetCents: 0, languageCode: "ru")
        #expect(en != ru)
    }

    // MARK: - Full build over an in-memory store

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @discardableResult
    private func addExpense(_ ctx: ModelContext, _ name: String, _ cents: Int) -> Transaction {
        let cat = FinanceTracker.Category(name: name, kindRaw: "expense", order: 0)
        ctx.insert(cat)
        let tx = Transaction(typeRaw: "expense", amountCents: cents, currency: "USD", date: Date(), category: cat)
        ctx.insert(tx)
        return tx
    }

    @discardableResult
    private func addIncome(_ ctx: ModelContext, _ cents: Int) -> Transaction {
        let cat = FinanceTracker.Category(name: "Salary", kindRaw: "income", order: 0)
        ctx.insert(cat)
        let tx = Transaction(typeRaw: "income", amountCents: cents, currency: "USD", date: Date(), category: cat)
        ctx.insert(tx)
        return tx
    }

    @Test func build_topCategories_cappedAtThree_andSorted() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Food", 30_000)
        addExpense(ctx, "Transport", 20_000)
        addExpense(ctx, "Shopping", 10_000)
        addExpense(ctx, "Coffee", 5_000)   // 4th — must be dropped
        addIncome(ctx, 100_000)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 200_000,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.topCategories.count == 3)
        #expect(snap.topCategories.map(\.name) == ["Food", "Transport", "Shopping"])
        // Sorted descending by fraction/amount.
        #expect(snap.topCategories[0].fraction >= snap.topCategories[1].fraction)
        #expect(snap.topCategories[1].fraction >= snap.topCategories[2].fraction)
        // Fraction is a share of total spend (65_000 total → Food 30_000).
        #expect(abs(snap.topCategories[0].fraction - (30_000.0 / 65_000.0)) < 0.001)
        #expect(snap.hasData)
    }

    @Test func build_withBudget_heroIsGainFramedSafeToSpend() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Food", 65_000)
        addIncome(ctx, 100_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 200_000,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.heroLabel == String(localized: "widget.safe_to_spend"))
        #expect(!snap.heroIsAlert)
        #expect(!snap.heroSubtitle.isEmpty)                     // "of $2,000"
        #expect(abs(snap.ringFraction - (65_000.0 / 200_000.0)) < 0.0001)
        #expect(!snap.spentText.isEmpty)
        #expect(!snap.earnedText.isEmpty)
    }

    @Test func build_overBudget_flipsToAlert_ringFull() throws {
        let ctx = try makeContext()
        addExpense(ctx, "Rent", 250_000)     // over the 200_000 budget
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 200_000,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.heroIsAlert)
        #expect(snap.heroLabel == String(localized: "widget.over_budget"))
        #expect(snap.ringFraction == 1.0)
    }

    @Test func build_noBudget_incomeKnown_isGainFramedSafeToSpend() throws {
        // Item 0: no budget but income is known → remaining IS computable
        // (income − spent), so lead with the GAIN frame, not "Spent". The observed
        // device bug was "194 ₽ / Расходы" when 2 800 ₽ income made 2 606 ₽ safe.
        let ctx = try makeContext()
        addExpense(ctx, "Food", 4_000)
        addIncome(ctx, 8_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 0,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.heroLabel == String(localized: "widget.safe_to_spend"))
        #expect(!snap.heroIsAlert)
        #expect(!snap.heroSubtitle.isEmpty)                     // "of $80 earned"
        #expect(!snap.ringIsNeutral)                            // income present → spent/income
        #expect(abs(snap.ringFraction - 0.5) < 0.0001)
    }

    @Test func build_noBudget_spentExceedsIncome_isAlert() throws {
        // Overspent relative to income → danger signal, ring clamps to full.
        let ctx = try makeContext()
        addExpense(ctx, "Rent", 12_000)
        addIncome(ctx, 8_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 0,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.heroIsAlert)
        #expect(snap.heroLabel == String(localized: "widget.overspent"))
        #expect(snap.ringFraction == 1.0)
    }

    @Test func build_noBudget_noIncome_showsSpentLastResort() throws {
        // Neither budget nor income → the only honest hero is "Spent {amount}".
        let ctx = try makeContext()
        addExpense(ctx, "Food", 4_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 0,
                                            locale: Locale(identifier: "en_US"))

        #expect(snap.heroLabel == String(localized: "widget.hero.spent"))
        #expect(!snap.heroIsAlert)
        #expect(snap.heroSubtitle.isEmpty)
        #expect(snap.ringIsNeutral)                             // no denominator to fill
    }

    @Test func build_resolvesChromeInPassedLanguage_notHostLocale() throws {
        // Item 5: the baked snapshot must be in the app's chosen language. Building
        // with a ru locale must resolve chrome against ru.lproj regardless of the
        // test host's system language.
        let ctx = try makeContext()
        addExpense(ctx, "Food", 65_000)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 200_000,
                                            locale: Locale(identifier: "ru"))

        let ruPath = try #require(Bundle.main.path(forResource: "ru", ofType: "lproj"))
        let ruBundle = try #require(Bundle(path: ruPath))
        let expected = ruBundle.localizedString(forKey: "widget.safe_to_spend", value: "", table: nil)
        #expect(snap.heroLabel == expected)                 // "Можно потратить"
    }

    @Test func build_emptyPeriod_noBudget_hasNoData() throws {
        let ctx = try makeContext()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())   // empty
        let snap = NetSnapshotBuilder.build(transactions: all,
                                            currencyCode: "USD",
                                            monthlyBudgetCents: 0,
                                            locale: Locale(identifier: "en_US"))
        #expect(!snap.hasData)
        #expect(snap.topCategories.isEmpty)
        #expect(snap.ringIsNeutral)
        #expect(snap.spendSeries == nil)                        // no spend → no ambient chart
    }

    // MARK: - Ambient spend curve (Direction B, pure + date-injected)

    private func utc() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    private func expenseTx(_ cents: Int, on date: Date) -> Transaction {
        Transaction(typeRaw: "expense", amountCents: cents, currency: "USD", date: date,
                    category: FinanceTracker.Category(name: "X", kindRaw: "expense", order: 0))
    }
    private func incomeTx(_ cents: Int, on date: Date) -> Transaction {
        Transaction(typeRaw: "income", amountCents: cents, currency: "USD", date: date,
                    category: FinanceTracker.Category(name: "S", kindRaw: "income", order: 0))
    }

    @Test func spendCurve_isMonotonic_normalized_endsAtOne() {
        let cal = utc(); let now = day(cal, 2026, 6, 15)   // day 15
        let txns = [expenseTx(1_000, on: day(cal, 2026, 6, 2)),
                    expenseTx(2_000, on: day(cal, 2026, 6, 5)),
                    expenseTx(3_000, on: day(cal, 2026, 6, 10))]
        let series = try! #require(NetSnapshotBuilder.cumulativeDailySpend(txns, now: now, calendar: cal))
        #expect(series.count == 15)                        // one point per elapsed day
        #expect(series.first == 0)                         // nothing spent on day 1
        #expect(abs(series.last! - 1.0) < 1e-9)            // ends at total
        #expect(zip(series, series.dropFirst()).allSatisfy { $0 <= $1 })   // non-decreasing
        #expect(series.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
    }

    @Test func spendCurve_noExpenses_isNil() {
        let cal = utc()
        #expect(NetSnapshotBuilder.cumulativeDailySpend([], now: day(cal, 2026, 6, 15), calendar: cal) == nil)
    }

    @Test func spendCurve_onlyIncome_isNil() {
        let cal = utc(); let now = day(cal, 2026, 6, 15)
        let txns = [incomeTx(50_000, on: day(cal, 2026, 6, 3))]
        #expect(NetSnapshotBuilder.cumulativeDailySpend(txns, now: now, calendar: cal) == nil)  // total 0
    }

    @Test func spendCurve_firstDayOfMonth_isNil_tooFewPoints() {
        let cal = utc(); let now = day(cal, 2026, 6, 1)    // only 1 elapsed day
        let txns = [expenseTx(5_000, on: now)]
        #expect(NetSnapshotBuilder.cumulativeDailySpend(txns, now: now, calendar: cal) == nil)
    }

    @Test func spendCurve_shapeReflectsPace_frontVsBackLoaded() {
        let cal = utc(); let now = day(cal, 2026, 6, 15)
        let front = [expenseTx(5_000, on: day(cal, 2026, 6, 2)),
                     expenseTx(1_000, on: day(cal, 2026, 6, 14))]
        let back  = [expenseTx(1_000, on: day(cal, 2026, 6, 2)),
                     expenseTx(5_000, on: day(cal, 2026, 6, 14))]
        let fs = try! #require(NetSnapshotBuilder.cumulativeDailySpend(front, now: now, calendar: cal))
        let bs = try! #require(NetSnapshotBuilder.cumulativeDailySpend(back,  now: now, calendar: cal))
        #expect(fs[4] > bs[4])                             // mid-month, front-loaded is higher
    }

    @Test func spendCurve_ignoresFutureDatedAndOtherMonths() {
        let cal = utc(); let now = day(cal, 2026, 6, 15)
        let txns = [expenseTx(1_000, on: day(cal, 2026, 6, 2)),    // counts
                    expenseTx(9_999, on: day(cal, 2026, 6, 20)),   // future → ignored
                    expenseTx(8_888, on: day(cal, 2026, 5, 10))]   // other month → ignored
        let series = try! #require(NetSnapshotBuilder.cumulativeDailySpend(txns, now: now, calendar: cal))
        #expect(series[0] == 0)
        #expect(abs(series[1] - 1.0) < 1e-9)               // only the day-2 expense exists → 1.0 from day 2 on
        #expect(abs(series.last! - 1.0) < 1e-9)
    }

    // MARK: - Ambient curve read guards (on NetSnapshot, shared with the widget)

    @Test func safeSpendSeries_coercesCorruptValuesFiniteAndClamped() {
        var s = NetSnapshot.placeholder()
        s.spendSeries = [.nan, -0.5, 2.0, 0.5, .infinity]
        #expect(s.safeSpendSeries == [0, 0, 1, 0.5, 1])
        #expect(s.canRenderSpendChart)                     // 5 points
    }

    @Test func canRenderSpendChart_falseForNilOrSinglePoint() {
        var s = NetSnapshot.placeholder()
        #expect(s.spendSeries == nil)
        #expect(!s.canRenderSpendChart)
        #expect(s.safeSpendSeries.isEmpty)
        s.spendSeries = [0.7]                               // single point → zero-width domain
        #expect(!s.canRenderSpendChart)
    }
}
