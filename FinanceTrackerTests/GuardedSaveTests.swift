//
//  GuardedSaveTests.swift
//  FinanceTrackerTests
//
//  Covers `GuardedSave` and the one site whose defect it was written for that is
//  reachable without a UI harness: `DemoDataController`'s UserDefaults flag.
//
//  The shape under test is not "the error was swallowed". It is:
//
//      mutate → save → do the side effect ANYWAY
//
//  where the side effect lives OUTSIDE the store and is therefore beyond
//  `rollback()`'s reach. For DemoDataController that side effect is
//  `hasDemoDataActive`, and desynchronising it from the ledger is not cosmetic:
//  clearing the flag while the rows survive makes `seedDemoData` re-seed, putting
//  a SECOND set of sample transactions into the user's real ledger.
//
//  Failure is induced with a real read-only store (NSCocoaErrorDomain 513), the
//  same mechanism as SaveFailureReachabilityProbe — never a mocked throw.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Guarded save, and side effects that must follow it", .serialized)
@MainActor
struct GuardedSaveTests {

    private static let models: [any PersistentModel.Type] = [
        Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
    ]

    private func makeStore(demoRows: Int, readOnly: Bool)
        throws -> (ModelContainer, ModelContext, URL)
    {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("guarded-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let schema = Schema(Self.models)

        try autoreleasepool {
            let c = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
            let ctx = ModelContext(c)
            let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
            ctx.insert(cat)
            for i in 0..<demoRows {
                let tx = Transaction(typeRaw: "expense", amountCents: 100 + i,
                                     date: Date(), category: cat)
                tx.isDemo = true
                ctx.insert(tx)
            }
            try ctx.save()
        }

        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(url: url, allowsSave: !readOnly)
        )
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return (container, ctx, dir)
    }

    // MARK: - GuardedSave itself

    @Test("commit returns true and persists on a healthy store")
    func commitSucceeds() throws {
        let (container, ctx, dir) = try makeStore(demoRows: 0, readOnly: false)
        defer { try? FileManager.default.removeItem(at: dir) }

        ctx.insert(Transaction(typeRaw: "expense", amountCents: 500, date: Date(), category: nil))
        #expect(GuardedSave.commit(ctx, "test.ok"))
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Transaction>()) == 1)
    }

    @Test("commit returns false, rolls back, and runs revert on a failed save")
    func commitFailsAndReverts() throws {
        let (container, ctx, dir) = try makeStore(demoRows: 1, readOnly: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tx = try #require(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        let prior = tx.amountCents
        tx.amountCents = 99_999

        var revertRan = false
        let ok = GuardedSave.commit(ctx, "test.fail", revert: {
            revertRan = true
            tx.amountCents = prior
        })

        #expect(ok == false)
        #expect(revertRan, "an attribute mutation needs the revert — rollback() does not restore it")
        #expect(tx.amountCents == prior, "the object is back to its clean value in memory")
        #expect(ctx.hasChanges == false)

        let onDisk = try #require(try ModelContext(container).fetch(FetchDescriptor<Transaction>()).first)
        #expect(onDisk.amountCents == prior)
        withExtendedLifetime(container) {}
    }

    /// Why `revert` is not optional decoration: without it, `rollback()` leaves the
    /// mutated value sitting in memory to be flushed by the next save. Recorded as
    /// the inverse of the test above rather than asserted blind.
    @Test("without revert, rollback alone does not restore a mutated attribute")
    func rollbackAloneDoesNotRestoreAnAttribute() throws {
        let (_, ctx, dir) = try makeStore(demoRows: 1, readOnly: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tx = try #require(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        tx.amountCents = 99_999
        _ = GuardedSave.commit(ctx, "test.norevert")   // no revert closure

        print("[guarded] amountCents after a bare rollback: \(tx.amountCents) (was set to 99999)")
        #expect(ctx.hasChanges == false)
    }

    // MARK: - The side effect that must follow the save

    @Test("a failed clearDemoData leaves BOTH the rows and the flag alone")
    func failedClearKeepsFlagAndRows() throws {
        let (container, ctx, dir) = try makeStore(demoRows: 5, readOnly: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let priorFlag = DemoDataController.isDemoDataActive
        defer { DemoDataController.isDemoDataActive = priorFlag }
        DemoDataController.isDemoDataActive = true

        #expect(DemoDataController.clearDemoData(modelContext: ctx) == false)
        #expect(
            DemoDataController.isDemoDataActive,
            "THE DEFECT: clearing the flag while the rows survive makes seedDemoData re-seed, putting a second set of sample transactions into the real ledger"
        )
        #expect(ctx.hasChanges == false)

        let onDisk = try ModelContext(container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo })
        )
        #expect(onDisk == 5)
        withExtendedLifetime(container) {}
    }

    @Test("a successful clearDemoData removes the rows and clears the flag")
    func successfulClearDoesBoth() throws {
        let (container, ctx, dir) = try makeStore(demoRows: 5, readOnly: false)
        defer { try? FileManager.default.removeItem(at: dir) }

        let priorFlag = DemoDataController.isDemoDataActive
        defer { DemoDataController.isDemoDataActive = priorFlag }
        DemoDataController.isDemoDataActive = true

        #expect(DemoDataController.clearDemoData(modelContext: ctx))
        #expect(DemoDataController.isDemoDataActive == false)

        let onDisk = try ModelContext(container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo })
        )
        #expect(onDisk == 0)
    }
}
