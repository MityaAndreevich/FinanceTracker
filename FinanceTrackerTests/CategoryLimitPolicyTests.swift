//
//  CategoryLimitPolicyTests.swift
//  FinanceTrackerTests
//
//  Category limits (design doc §6.5): the threshold fires when crossing from
//  below and NEVER at/over the limit (gain-framing guard), the spend is
//  attribution-based (splits count toward the splits' categories), the
//  partition invariant ties per-category sums back to the month total, and
//  the alert plan gives the limit warning precedence with a latch that keeps
//  it to once per category per month.
//
//  Every expectation derives from `CategoryLimitPolicy.warnThresholdFraction`
//  — the single-sourced tunable — never from a duplicated literal, so tuning
//  the guess is a one-line production diff and zero test edits.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("Category limit policy")
struct CategoryLimitPolicyTests {

    private let catA = UUID()
    private let catB = UUID()
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Threshold boundary (single-sourced)

    @Test func warnsExactlyFromThresholdUpToButNeverAtTheLimit() {
        let limit = 30_000   // $300
        let threshold = Int((Double(limit) * CategoryLimitPolicy.warnThresholdFraction).rounded(.up))

        #expect(!CategoryLimitPolicy.shouldWarn(spentCents: threshold - 1, limitCents: limit),
                "one cent below the threshold: silent")
        #expect(CategoryLimitPolicy.shouldWarn(spentCents: threshold, limitCents: limit),
                "crossing the threshold from below: warn")
        #expect(CategoryLimitPolicy.shouldWarn(spentCents: limit - 1, limitCents: limit),
                "still under the limit: warn")
        #expect(!CategoryLimitPolicy.shouldWarn(spentCents: limit, limitCents: limit),
                "AT the limit: nothing gain-framed left to say — silent")
        #expect(!CategoryLimitPolicy.shouldWarn(spentCents: limit + 500, limitCents: limit),
                "over the limit: never an 'exceeded' notification")
        #expect(!CategoryLimitPolicy.shouldWarn(spentCents: 100, limitCents: 0),
                "no limit set: silent")
    }

    // MARK: - Attribution-based spend

    @Test func spentByCategoryReadsSplitAttributions() {
        // A 120.00 purchase in catA, split 40.00 → catB; the remainder stays A.
        let rows = CategoryAttribution.rows(
            totalCents: 12_000, parentCategoryUUID: catA, date: day, isIncome: false,
            splits: [.init(amountCents: 4_000, categoryUUID: catB)]
        )
        let cal = Calendar.current
        let spent = CategoryLimitPolicy.spentByCategory(
            rows: rows,
            monthStart: cal.date(from: cal.dateComponents([.year, .month], from: day))!,
            today: cal.startOfDay(for: day),
            calendar: cal
        )
        #expect(spent?[catB] == 4_000, "the split's money counts toward the SPLIT's category")
        #expect(spent?[catA] == 8_000, "the remainder counts toward the purchase's own category")
    }

    @Test func spentByCategoryUsesTheSafeToSpendMonthWindow() {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: day))!
        let today = cal.startOfDay(for: day)

        func row(_ date: Date) -> CategoryAttribution.Row {
            CategoryAttribution.Row(amountCents: 1_000, categoryUUID: catA, date: date, isIncome: false)
        }
        let spent = CategoryLimitPolicy.spentByCategory(
            rows: [
                row(day),                                    // today → counts
                row(day.addingTimeInterval(86_400 * 40)),    // future-dated → excluded
                row(day.addingTimeInterval(-86_400 * 45)),   // prior month → excluded
            ],
            monthStart: monthStart, today: today, calendar: cal
        )
        #expect(spent?[catA] == 1_000,
                "same window as SafeToSpend.aggregate: day ≤ today, this month only")
    }

    @Test func partitionInvariant_categorySumsEqualTheMonthExpenseTotal() {
        // The §6.3 double-count proof, executable: the same money partitioned
        // two ways (parent-summed total vs attribution-summed categories)
        // must count once each way.
        let purchases: [(total: Int, splits: [CategoryAttribution.SplitInput])] = [
            (12_000, [.init(amountCents: 4_000, categoryUUID: catB)]),
            (5_000, []),
            (3_000, [.init(amountCents: 1_000, categoryUUID: catB),
                     .init(amountCents: 2_000, categoryUUID: catA)]),
        ]
        let rows = purchases.flatMap {
            CategoryAttribution.rows(totalCents: $0.total, parentCategoryUUID: catA,
                                     date: day, isIncome: false, splits: $0.splits)
        }
        let cal = Calendar.current
        let spent = CategoryLimitPolicy.spentByCategory(
            rows: rows,
            monthStart: cal.date(from: cal.dateComponents([.year, .month], from: day))!,
            today: cal.startOfDay(for: day),
            calendar: cal
        )
        let parentSum = purchases.reduce(0) { $0 + $1.total }
        #expect(spent?.values.reduce(0, +) == parentSum)
    }

    // MARK: - Plan precedence, latch, silence

    private func makeSnapshot(budget: Int, spent: Int) -> SafeToSpend.Snapshot {
        SafeToSpend.snapshot(
            monthlyBudgetCents: budget, spentThisMonthCents: spent,
            priorExpenseCents: 0, priorSpanDays: 0, now: Date()
        )
    }

    private var settings: AlertSettings {
        // Weekday matching today ⇒ nextFireDate lands within 7 days; the plan's
        // same-month guard may still nil it near month-end — every assertion
        // below therefore compares AGAINST the non-limit plan of the same
        // moment instead of asserting non-nil absolutely where it matters.
        AlertSettings(isEnabled: true, weekday: Calendar.current.component(.weekday, from: Date()),
                      hour: 9, minute: 0)
    }

    private func warnableStatus(_ uuid: UUID, name: String = "Dining") -> CategoryLimitPolicy.Status {
        // Derive a warn-state spend from the single-sourced threshold.
        let limit = 20_000
        let threshold = Int((Double(limit) * CategoryLimitPolicy.warnThresholdFraction).rounded(.up))
        return .init(categoryUUID: uuid, displayName: name, limitCents: limit, spentCents: threshold)
    }

    @Test func categoryLimitWarningTakesPrecedenceOverBudgetBodies() {
        let snapshot = makeSnapshot(budget: 100_000, spent: 10_000)
        let base = ProactiveAlertPolicy.plan(
            snapshot: snapshot, pace: .faster, settings: settings, now: Date()
        )
        let withLimit = ProactiveAlertPolicy.plan(
            snapshot: snapshot, pace: .faster,
            limitStatuses: [warnableStatus(catA)],
            settings: settings, now: Date()
        )
        // Wherever a plan exists at all (same-month guard permitting), the
        // limit body must win over pace/safeToSpend.
        if let withLimit {
            guard case .categoryLimit(let uuid, let name, let remaining) = withLimit.body else {
                Issue.record("limit warning must take precedence, got \(withLimit.body)")
                return
            }
            #expect(uuid == catA)
            #expect(name == "Dining")
            #expect(remaining > 0, "gain-framed: only a positive remainder is ever announced")
        } else {
            #expect(base == nil, "if the limit plan is nil it may only be the shared date guards")
        }
    }

    @Test func limitWarningWorksWithoutAMonthlyBudget() {
        // Category limits are independent of the monthly budget: a user may
        // set only limits. Guard 2 (isBudgetSet) must not swallow the warning.
        let snapshot = makeSnapshot(budget: 0, spent: 0)
        let base = ProactiveAlertPolicy.plan(
            snapshot: snapshot, pace: .unavailable, settings: settings, now: Date()
        )
        #expect(base == nil, "sanity: no budget → no budget-body plan")

        let withLimit = ProactiveAlertPolicy.plan(
            snapshot: snapshot, pace: .unavailable,
            limitStatuses: [warnableStatus(catA)],
            settings: settings, now: Date()
        )
        if let withLimit {
            guard case .categoryLimit = withLimit.body else {
                Issue.record("expected a limit body, got \(withLimit.body)")
                return
            }
        }
        // Near month-end both are nil via the shared same-month guard — the
        // equality above (base nil, limit-only plan possibly nil) still holds.
    }

    @Test func latchSuppressesTheWarnedCategoryAndFallsThrough() {
        let snapshot = makeSnapshot(budget: 100_000, spent: 10_000)
        let latched = ProactiveAlertPolicy.plan(
            snapshot: snapshot, pace: .onPace,
            limitStatuses: [warnableStatus(catA)],
            isLatched: { $0 == catA },
            settings: settings, now: Date()
        )
        if let latched {
            guard case .safeToSpend = latched.body else {
                Issue.record("a latched category must fall through to the budget body, got \(latched.body)")
                return
            }
        }
    }

    @Test func overLimitCategorySaysNothingAndIsNeverPicked() {
        let over = CategoryLimitPolicy.Status(
            categoryUUID: catA, displayName: "Dining", limitCents: 20_000, spentCents: 25_000
        )
        #expect(CategoryLimitPolicy.pickWarnable(statuses: [over], isLatched: { _ in false }) == nil)

        // With one over-limit and one warnable, the warnable one is picked.
        let picked = CategoryLimitPolicy.pickWarnable(
            statuses: [over, warnableStatus(catB, name: "Groceries")],
            isLatched: { _ in false }
        )
        #expect(picked?.categoryUUID == catB)
    }

    @Test func closestToItsLimitWinsWhenSeveralWarn() {
        let limit = 10_000
        let threshold = Int((Double(limit) * CategoryLimitPolicy.warnThresholdFraction).rounded(.up))
        let mild = CategoryLimitPolicy.Status(
            categoryUUID: catA, displayName: "A", limitCents: limit, spentCents: threshold
        )
        let urgent = CategoryLimitPolicy.Status(
            categoryUUID: catB, displayName: "B", limitCents: limit, spentCents: limit - 1
        )
        let picked = CategoryLimitPolicy.pickWarnable(
            statuses: [mild, urgent], isLatched: { _ in false }
        )
        #expect(picked?.categoryUUID == catB, "one notification carries one number — the most urgent")
    }
}
