//
//  ProactiveAlertRefresherTests.swift
//  FinanceTrackerTests
//
//  The refresher is the join between the pure policy and the live ledger — the one place
//  a wiring slip (feeding the policy the wrong field) would produce a confidently-wrong
//  number in a notification. So it is tested end to end, through the real SwiftData store
//  and the real policy, against a fake notification centre.
//
//  These cover the silences the device cannot easily be made to prove: no budget, over
//  budget, and a lapsed subscription all leave nothing pending.
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import FinanceTracker

@MainActor
struct ProactiveAlertRefresherTests {

    /// The container must be held for the lifetime of the test — returning only the
    /// context lets it deallocate and takes the store with it.
    private func makeStore() throws -> (ModelContainer, ModelContext, FinanceTracker.Category) {
        let container = try ModelContainer(
            for: SharedModelContainer.fullSchema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let category = FinanceTracker.Category(name: "Food", kindRaw: "expense")
        context.insert(category)
        return (container, context, category)
    }

    /// A private defaults domain, so a test can never poison the simulator (or another
    /// test) the way a stray `defaults write` once poisoned TutorialFlowTests.
    private func makeDefaults(
        enabled: Bool = true,
        budgetCents: Int = 100_000
    ) -> UserDefaults {
        let suite = "ProactiveAlertRefresherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(enabled, forKey: "alertsEnabled")
        defaults.set(6, forKey: "alertWeekday")     // Friday
        defaults.set(18, forKey: "alertHour")
        defaults.set(0, forKey: "alertMinute")
        defaults.set(budgetCents, forKey: "monthlyBudgetCents")
        defaults.set("USD", forKey: "defaultCurrencyCode")
        return defaults
    }

    private func spend(_ cents: Int, in context: ModelContext, category: FinanceTracker.Category, on date: Date) {
        context.insert(
            Transaction(
                typeRaw: "expense",
                amountCents: cents,
                currency: "USD",
                date: date,
                category: category
            )
        )
    }

    /// Tuesday 14 July 2026 — comfortably mid-month, so the Friday fire date stays in it.
    private let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 14, hour: 9)
    )!

    // MARK: - The happy path

    @Test func schedulesOneAlertCarryingTheRealRemainder() throws {
        let (container, context, category) = try makeStore()
        _ = container
        spend(40_000, in: context, category: category, on: now)

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: true,
            defaults: makeDefaults(budgetCents: 100_000),
            now: now,
            center: center
        )

        #expect(center.added.count == 1)
        // Budget 1000.00 − spend 400.00 = 600.00. If the wiring fed the policy the wrong
        // field, this is where it would show up as a plausible-but-wrong number.
        let body = center.added.first?.content.body ?? ""
        #expect(body.contains(Money.format(cents: 60_000, currencyCode: "USD")))
    }

    // MARK: - The silences

    @Test func noBudgetSchedulesNothing() throws {
        let (container, context, category) = try makeStore()
        _ = container
        spend(40_000, in: context, category: category, on: now)

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: true,
            defaults: makeDefaults(budgetCents: 0),
            now: now,
            center: center
        )

        #expect(center.added.isEmpty)
        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
    }

    @Test func overBudgetSchedulesNothing() throws {
        // The silence that matters most: no honest sentence about a negative balance is
        // gain-framed, so we push nothing at all.
        let (container, context, category) = try makeStore()
        _ = container
        spend(130_000, in: context, category: category, on: now)

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: true,
            defaults: makeDefaults(budgetCents: 100_000),
            now: now,
            center: center
        )

        #expect(center.added.isEmpty)
    }

    @Test func alertsDisabledSchedulesNothing() throws {
        let (container, context, category) = try makeStore()
        _ = container
        spend(40_000, in: context, category: category, on: now)

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: true,
            defaults: makeDefaults(enabled: false),
            now: now,
            center: center
        )

        #expect(center.added.isEmpty)
    }

    @Test func aLapsedUserHasNothingPending() throws {
        // An expired trial must not leave a premium notification in flight, even though
        // the user's toggle is still switched on from when they had access.
        let (container, context, category) = try makeStore()
        _ = container
        spend(40_000, in: context, category: category, on: now)

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: false,          // lapsed
            defaults: makeDefaults(enabled: true),
            now: now,
            center: center
        )

        #expect(center.added.isEmpty)
        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
    }

    @Test func anEmptyLedgerWithABudgetStillReportsTheFullBudget() throws {
        // Nothing spent yet is not "sparse" — the budget alone is a truthful answer.
        let (container, context, _) = try makeStore()
        _ = container

        let center = FakeNotificationCenter()
        ProactiveAlertRefresher.refresh(
            modelContext: context,
            isAllowed: true,
            defaults: makeDefaults(budgetCents: 100_000),
            now: now,
            center: center
        )

        #expect(center.added.count == 1)
        let body = center.added.first?.content.body ?? ""
        #expect(body.contains(Money.format(cents: 100_000, currencyCode: "USD")))
    }
}
