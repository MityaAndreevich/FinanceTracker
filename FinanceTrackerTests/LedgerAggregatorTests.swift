//
//  LedgerAggregatorTests.swift
//  FinanceTrackerTests
//
//  The off-main aggregation path (hang-brief Item 1). Two contracts:
//
//  1. CORRECTNESS: the actor's aggregate equals the synchronous computation on
//     the same store — moving the read off the main thread must not move the
//     number. A notification that disagrees with the dashboard would be worse
//     than the hang it replaces.
//
//  2. COALESCING: a burst of scheduleRefresh calls (one QuickAdd fires didSave
//     twice; a rapid session fires dozens) collapses to EXACTLY ONE pass. This
//     is the "no synchronous fetch on the main path in the hot loop" guarantee
//     in testable form — the hot loop only ever cancels-and-reschedules a task;
//     the single surviving pass does its full-table read on the actor.
//
//  A hang itself is not unit-testable (348 green tests proved that); the scale
//  measurement lives in MainThreadHangScaleTests / MainThreadHotPathMeasurementTests.
//

import Foundation
import Testing
import SwiftData
import UserNotifications
@testable import FinanceTracker

@Suite("Off-main ledger aggregation", .serialized)
@MainActor
struct LedgerAggregatorTests {

    private final class SpyCenter: NotificationScheduling, @unchecked Sendable {
        var removePendingCalls = 0
        var scheduleCalls = 0
        func removePending(identifiers: [String]) { removePendingCalls += 1 }
        func schedule(_ request: UNNotificationRequest) { scheduleCalls += 1 }
    }

    private func makeSeededContainer(count: Int) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        let ctx = container.mainContext
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        let daySeconds: TimeInterval = 24 * 60 * 60
        let start = Date().addingTimeInterval(-400 * daySeconds)
        for i in 0..<count {
            ctx.insert(Transaction(
                typeRaw: i % 10 == 0 ? "income" : "expense",
                amountCents: 100 + i,
                currency: "USD",
                date: start.addingTimeInterval(Double(i % 400) * daySeconds),
                category: cat
            ))
        }
        try ctx.save()
        return container
    }

    @Test func actorAggregateMatchesTheSynchronousComputation() async throws {
        let container = try makeSeededContainer(count: 800)
        let now = Date()

        // The number the dashboard/alerts arithmetic produces on the main context.
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>())
        let sync = SafeToSpend.aggregate(
            entries: SafeToSpend.entries(from: transactions), now: now
        )

        // The same number, computed on the actor's executor.
        let actor = LedgerAggregator(modelContainer: container)
        let offMain = await actor.safeToSpendAggregate(now: now)

        #expect(offMain.spentThisMonthCents == sync.spentThisMonthCents)
        #expect(offMain.priorExpenseCents == sync.priorExpenseCents)
        #expect(offMain.priorSpanDays == sync.priorSpanDays)
    }

    @Test func burstOfScheduleRefreshCallsCoalescesToExactlyOnePass() async throws {
        let container = try makeSeededContainer(count: 50)
        let center = SpyCenter()
        let defaults = UserDefaults(suiteName: "coalesce-test-\(UUID().uuidString)")!
        defaults.set(false, forKey: "alertsEnabled")   // plan = cancel ⇒ 1 removePending per pass

        // A scheduler of our OWN: the test host is the real app, whose didSave
        // observer drives ITS shared scheduler — an instance isolates us from it.
        let scheduler = ProactiveAlertRefreshScheduler()

        // The QuickAdd reality: many didSaves land inside one coalescing window.
        for _ in 0..<6 {
            scheduler.schedule(
                container: container,
                coalesceWindow: .milliseconds(80),
                defaults: defaults,
                center: center,
                isAllowed: { true }
            )
        }
        await scheduler.drain()

        #expect(center.removePendingCalls == 1,
                "six didSaves in one burst must collapse to ONE aggregation pass, saw \(center.removePendingCalls)")
        #expect(center.scheduleCalls == 0)
    }

    @Test func passesSeparatedInTimeEachRun() async throws {
        let container = try makeSeededContainer(count: 50)
        let center = SpyCenter()
        let defaults = UserDefaults(suiteName: "coalesce-test-\(UUID().uuidString)")!
        defaults.set(false, forKey: "alertsEnabled")

        let scheduler = ProactiveAlertRefreshScheduler()

        for _ in 0..<2 {
            scheduler.schedule(
                container: container,
                coalesceWindow: .milliseconds(40),
                defaults: defaults,
                center: center,
                isAllowed: { true }
            )
            await scheduler.drain()
        }

        #expect(center.removePendingCalls == 2,
                "two separated writes are two passes — coalescing must not eat real updates")
    }
}
