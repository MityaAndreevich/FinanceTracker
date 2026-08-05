//
//  TransactionDeleteServiceTests.swift
//  FinanceTrackerTests
//
//  The two user-facing single-row delete paths (swipe-to-delete, shake-to-undo)
//  now share one guarded choke-point. The property that matters is not "the
//  delete works" — it always did — but what happens when the save throws:
//
//    before: the delete stayed PENDING in the long-lived mainContext, the UI
//            proceeded as if it had succeeded, and the user's next ordinary save
//            committed the row's deletion at a moment they never asked for.
//
//  Failure is induced with a real read-only store (NSCocoaErrorDomain 513), the
//  same mechanism SaveFailureReachabilityProbe uses — not a mocked throw — so
//  these assertions are about the real save path.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Guarded single-row delete", .serialized)
@MainActor
struct TransactionDeleteServiceTests {

    private static let models: [any PersistentModel.Type] = [
        Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
    ]

    /// Seeds `rows` transactions (the first carrying `splitCount` child splits),
    /// then reopens the store read-only so every later save() throws for real.
    private func makeUnwritableStore(rows: Int, splitCount: Int = 0)
        throws -> (ModelContainer, ModelContext, URL)
    {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("delete-ro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let schema = Schema(Self.models)

        try autoreleasepool {
            let c = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
            let ctx = ModelContext(c)
            let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
            ctx.insert(cat)
            for i in 0..<rows {
                let tx = Transaction(typeRaw: "expense", amountCents: 100 + i,
                                     date: Date(), category: cat)
                ctx.insert(tx)
                if i == 0 {
                    for s in 0..<splitCount {
                        let split = TransactionSplit(amountCents: 10, category: cat, order: s)
                        ctx.insert(split)
                        split.parent = tx
                    }
                }
            }
            try ctx.save()
        }

        let ro = try ModelContainer(for: schema,
                                    configurations: ModelConfiguration(url: url, allowsSave: false))
        let ctx = ModelContext(ro)
        ctx.autosaveEnabled = false
        return (ro, ctx, dir)
    }

    private func makeWritableStore() throws -> (ModelContainer, ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("delete-rw-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let c = try ModelContainer(for: Schema(Self.models),
                                   configurations: ModelConfiguration(url: url))
        let ctx = ModelContext(c)
        ctx.autosaveEnabled = false
        return (c, ctx, dir)
    }

    // MARK: - Failure

    @Test("a failed delete rethrows, rolls back, and leaves the row on disk")
    func failedDeleteRollsBackAndRethrows() throws {
        let (container, ctx, dir) = try makeUnwritableStore(rows: 3)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tx = try #require(try ctx.fetch(FetchDescriptor<Transaction>()).first)

        var reachedCaller = false
        do { try TransactionDeleteService.delete(tx, in: ctx) }
        catch { reachedCaller = true }

        #expect(reachedCaller, "the UI cannot report a failure it is never told about")
        #expect(ctx.hasChanges == false, "rolled back — nothing pending to commit later")

        let onDisk = try ModelContext(container).fetchCount(FetchDescriptor<Transaction>())
        #expect(onDisk == 3, "the row the user thought was deleted is still there")
        withExtendedLifetime(container) {}
    }

    /// THE DEFECT this service exists to prevent, stated as a property of pending
    /// state rather than of the failure — so it is shown on a HEALTHY store, the
    /// inverse of SaveFailureReachabilityProbe.pendingDeletesRideAlongOnTheNextSave.
    @Test("after a rolled-back delete the row does NOT ride along on a later unrelated save")
    func rolledBackDeleteDoesNotRideAlong() throws {
        let (container, ctx, dir) = try makeWritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        for i in 0..<5 {
            ctx.insert(Transaction(typeRaw: "expense", amountCents: 100 + i,
                                   date: Date(), category: cat))
        }
        try ctx.save()

        // Simulate exactly what the service does on failure: delete, then roll back.
        let victim = try #require(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        ctx.delete(victim)
        ctx.rollback()
        #expect(ctx.hasChanges == false)

        // An ordinary later write — the user entering a transaction.
        ctx.insert(Transaction(typeRaw: "expense", amountCents: 999, date: Date(), category: cat))
        try ctx.save()

        let onDisk = try ModelContext(container).fetchCount(FetchDescriptor<Transaction>())
        #expect(onDisk == 6, "5 survivors + 1 new; the abandoned delete stayed abandoned")
    }

    // MARK: - Success

    @Test("a successful delete removes the row and its cascaded splits")
    func successfulDeleteCascades() throws {
        let (container, ctx, dir) = try makeWritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        let tx = Transaction(typeRaw: "expense", amountCents: 500, date: Date(), category: cat)
        ctx.insert(tx)
        for s in 0..<3 {
            let split = TransactionSplit(amountCents: 100, category: cat, order: s)
            ctx.insert(split)
            split.parent = tx
        }
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<TransactionSplit>()) == 3)

        try TransactionDeleteService.delete(tx, in: ctx)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<TransactionSplit>()) == 0,
                "cascade rode the same save")
    }

    /// The rollback has to reach the cascaded children too, or a failed delete
    /// would leave orphaned splits pending — invisible to aggregation, which
    /// derives attribution from the parent.
    @Test("a failed delete leaves the cascaded splits on disk as well")
    func failedDeleteKeepsSplits() throws {
        let (container, ctx, dir) = try makeUnwritableStore(rows: 1, splitCount: 3)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tx = try #require(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        #expect(throws: (any Error).self) {
            try TransactionDeleteService.delete(tx, in: ctx)
        }
        #expect(ctx.hasChanges == false)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(try fresh.fetchCount(FetchDescriptor<TransactionSplit>()) == 3)
        withExtendedLifetime(container) {}
    }
}
