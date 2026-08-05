//
//  RecurrenceWatermarkOrderingTests.swift
//  FinanceTrackerTests
//
//  The period watermark lives in UserDefaults, OUTSIDE the store. That is what
//  makes its ordering relative to `save()` a correctness question rather than a
//  style one: `rollback()` reaches pending store state and nothing else, so a
//  watermark written before a failed save is a side effect no recovery path can
//  undo.
//
//  Written first, the failure mode is a silently MISSING charge — the period is
//  marked handled, no transaction exists, and the user is never re-prompted.
//  That is strictly worse than the double charge the rest of RecurrenceService
//  exists to prevent: a double charge is visible in the ledger and deletable, a
//  missing one never appears at all.
//
//  The failure is induced the same way SaveFailureReachabilityProbe induces it —
//  a real read-only store (NSCocoaErrorDomain 513) — not a mocked throw, so the
//  assertions are about the real save path.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Recurrence watermark is written only after the save succeeded", .serialized)
@MainActor
struct RecurrenceWatermarkOrderingTests {

    private static let models: [any PersistentModel.Type] = [
        Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
    ]

    /// Seeds a monthly template dated far enough back to be due, then REOPENS
    /// the store read-only so every subsequent `save()` throws for real.
    private func makeUnwritableStoreWithDueTemplate() throws -> (ModelContainer, ModelContext, URL, UUID) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("recur-ro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let schema = Schema(Self.models)
        let seriesID = UUID()

        try autoreleasepool {
            let c = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
            let ctx = ModelContext(c)
            let cat = FinanceTracker.Category(name: "Subscriptions", kindRaw: "expense", order: 0)
            ctx.insert(cat)
            let template = Transaction(
                uuid: seriesID,
                typeRaw: "expense",
                amountCents: 999,
                date: Date().addingTimeInterval(-60 * 86_400),
                category: cat,
                merchant: "Streaming",
                recurrenceRaw: RecurrenceType.monthly.rawValue
            )
            ctx.insert(template)
            try ctx.save()
        }

        let ro = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(url: url, allowsSave: false)
        )
        let ctx = ModelContext(ro)
        ctx.autosaveEnabled = false
        return (ro, ctx, dir, seriesID)
    }

    // MARK: - confirm

    /// The regression. Before the fix this test's third expectation failed: the
    /// watermark was advanced, so the user's next launch showed no prompt for a
    /// charge that was never written.
    @Test("a failed confirm leaves no charge, no watermark, and no pending state")
    func failedConfirmDoesNotAdvanceTheWatermark() throws {
        let (container, ctx, dir, seriesID) = try makeUnwritableStoreWithDueTemplate()
        defer { try? FileManager.default.removeItem(at: dir) }
        RecurrenceService.clearHandled(for: seriesID)
        defer { RecurrenceService.clearHandled(for: seriesID) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        #expect(prompt.id == seriesID)

        let ok = RecurrenceService.confirm(prompt, modelContext: ctx)

        #expect(ok == false, "the caller must be able to tell that nothing was written")
        #expect(
            RecurrenceService.handledDate(for: seriesID) == nil,
            "THE DEFECT: a period marked handled with no charge behind it is a charge that never comes back"
        )
        #expect(
            ctx.hasChanges == false,
            "rolled back — the abandoned insert cannot ride along on a later unrelated save"
        )

        let onDisk = try ModelContext(container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.recurrenceRaw == nil })
        )
        #expect(onDisk == 0, "no instance was created")
        withExtendedLifetime(container) {}
    }

    /// The other half: the ordering fix must not stop the happy path from
    /// advancing the boundary, or every confirm would re-prompt forever.
    @Test("a successful confirm posts the charge and advances the watermark")
    func successfulConfirmAdvancesTheWatermark() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let anchor = Date().addingTimeInterval(-60 * 86_400)
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor, olderAmountCents: 5200, newerAmountCents: 7300
        )
        RecurrenceService.clearHandled(for: twins.uuid)
        defer { RecurrenceService.clearHandled(for: twins.uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        #expect(RecurrenceService.confirm(prompt, modelContext: ctx))

        // NOT `==`. The watermark round-trips Date → Double(epoch seconds) →
        // Date through UserDefaults, which loses sub-microsecond precision, so
        // two dates that print identically compare unequal. Harmless in
        // production (the value only ever seeds `nextDate(after:)`), but it
        // makes an equality assertion here flake.
        let advanced = try #require(RecurrenceService.handledDate(for: twins.uuid))
        #expect(abs(advanced.timeIntervalSince(prompt.dueDate)) < 0.001)
        let posted = try ctx.fetch(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.recurrenceRaw == nil })
        )
        #expect(posted.count == 1)
        #expect(RecurrenceService.dueRecurring(modelContext: ctx).isEmpty, "not due again this period")
    }

    // MARK: - stopRecurrence

    /// The mirror defect, arrived at from the stop path: clearing the watermark
    /// before the save leaves a series that is still recurring ON DISK but has
    /// lost its boundary, and `nextDueDate` then falls back to `tx.date` — so the
    /// next launch re-prompts for periods the user already handled. That is the
    /// double charge.
    @Test("a failed stop keeps the series intact, watermark included")
    func failedStopKeepsTheSeriesAndItsWatermark() throws {
        let (container, ctx, dir, seriesID) = try makeUnwritableStoreWithDueTemplate()
        defer { try? FileManager.default.removeItem(at: dir) }

        let handled = Date().addingTimeInterval(-15 * 86_400)
        RecurrenceService.setHandledDate(handled, for: seriesID)
        defer { RecurrenceService.clearHandled(for: seriesID) }

        let template = try #require(
            try ctx.fetch(FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.recurrenceRaw != nil })).first
        )

        let ok = RecurrenceService.stopRecurrence(for: template, modelContext: ctx)

        #expect(ok == false)
        #expect(
            RecurrenceService.handledDate(for: seriesID) != nil,
            "THE DEFECT: a live series that lost its boundary re-prompts from tx.date"
        )
        #expect(
            template.recurrence == .monthly,
            "rollback() does not revert a mutated attribute — the field restore is what keeps memory honest"
        )
        #expect(ctx.hasChanges == false)

        let stillRecurring = try ModelContext(container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.recurrenceRaw != nil })
        )
        #expect(stillRecurring == 1, "the store never lost the series either")
        withExtendedLifetime(container) {}
    }

    @Test("a successful stop clears the series and its watermark")
    func successfulStopClearsBoth() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let anchor = Date().addingTimeInterval(-60 * 86_400)
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor, olderAmountCents: 5200, newerAmountCents: 7300
        )
        RecurrenceService.setHandledDate(anchor, for: twins.uuid)
        defer { RecurrenceService.clearHandled(for: twins.uuid) }

        #expect(RecurrenceService.stopRecurrence(for: twins.newer, modelContext: ctx))
        #expect(twins.newer.recurrence == nil)
        #expect(RecurrenceService.handledDate(for: twins.uuid) == nil)
    }
}
