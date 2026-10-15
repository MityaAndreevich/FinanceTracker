//
//  BulkDeleteCorrectnessTests.swift
//  FinanceTrackerTests
//
//  The CORRECTNESS half of the bulk-delete paths, at a size the default gate can
//  afford (2026-10-14, D33 scale split).
//
//  `BulkDeleteFixMeasurementTests` checks two things: that the fix is fast (>5×,
//  needs 16k rows) and that it is correct (the `.cascade` on Transaction.splits
//  still fired, no orphaned splits). Speed needs scale; correctness does not. The
//  speed half moved behind RUN_SCALE_TESTS; this file keeps the correctness half
//  in every run, for all three bulk paths, each of which runs
//  `TransactionDeleteService.detachForBulkDelete` before deleting:
//
//    DuplicateReviewService.deleteAll   — some rows survive (the review banner)
//    TransactionResetService.reset      — nothing survives (Settings → Reset)
//    LargeDatasetDebugSeed.wipeLedger   — the DEBUG launch seam (deletes splits
//                                         explicitly, then their parents)
//
//  Orphaned splits are INVISIBLE to aggregation, so nothing user-facing would
//  ever surface them. That is why each test counts them directly, from a FRESH
//  context on the same on-disk store, so the answer is what was saved, not what
//  the deleting context believes.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Bulk delete cascades to splits and leaves no orphans (small N)", .serialized)
@MainActor
struct BulkDeleteCorrectnessTests {

    private static let rows = 50
    /// Every third row carries two splits: 17 parents, 34 splits.
    private static let splitEvery = 3

    private struct Store {
        let container: ModelContainer
        let context: ModelContext
        let directory: URL
        let splitParents: Int
        let splitCount: Int
    }

    /// Every row has a category AND a source; every third row has two splits in
    /// OTHER categories; every second row is flagged as a possible duplicate.
    private func makeStore() throws -> Store {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bulk-correct-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
            configurations: ModelConfiguration(url: directory.appendingPathComponent("correct.sqlite"))
        )
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let cats = (0..<4).map { FinanceTracker.Category(name: "Cat \($0)", kindRaw: "expense", order: $0) }
        cats.forEach(ctx.insert)
        let source = Source(name: "Account")
        ctx.insert(source)

        var parents = 0, splits = 0
        for i in 0..<Self.rows {
            let tx = Transaction(
                typeRaw: "expense", amountCents: 1_000 + i, currency: "USD",
                date: Date(timeIntervalSince1970: 1_750_000_000 - Double(i) * 3_600),
                category: cats[i % cats.count], source: source,
                taxCents: nil, note: nil, merchant: "M\(i % 5)", recurrenceRaw: nil,
                isPossibleDuplicate: i % 2 == 0
            )
            ctx.insert(tx)
            if i % Self.splitEvery == 0 {
                parents += 1
                for part in 0..<2 {
                    let split = TransactionSplit(amountCents: 100, category: cats[(i + 1 + part) % cats.count], order: part)
                    ctx.insert(split)
                    split.parent = tx
                    splits += 1
                }
            }
        }
        try ctx.save()
        return Store(container: container, context: ctx, directory: directory,
                     splitParents: parents, splitCount: splits)
    }

    /// What is ON DISK after the delete, read through a context that never saw it.
    private func onDisk(_ store: Store) throws -> (rows: Int, splits: Int, orphans: Int) {
        let fresh = ModelContext(store.container)
        let splits = try fresh.fetch(FetchDescriptor<TransactionSplit>())
        return (try fresh.fetchCount(FetchDescriptor<Transaction>()),
                splits.count,
                splits.filter { $0.parent == nil }.count)
    }

    @Test("DuplicateReviewService.deleteAll cascades to the deleted rows' splits only")
    func deleteAllCascades() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        // Splits on surviving (unflagged) rows must survive; splits on deleted
        // (flagged) rows must go with them.
        let survivingSplits = try store.context.fetch(FetchDescriptor<TransactionSplit>())
            .filter { $0.parent?.isPossibleDuplicate == false }.count
        #expect(survivingSplits > 0 && survivingSplits < store.splitCount,
                "the store must put splits on BOTH sides of the delete, or this proves nothing")

        try DuplicateReviewService.deleteAll(in: store.context)

        let after = try onDisk(store)
        #expect(after.rows == Self.rows / 2)
        #expect(after.splits == survivingSplits,
                "\(store.splitCount - survivingSplits) splits belonged to deleted rows; \(store.splitCount - after.splits) were removed")
        #expect(after.orphans == 0, "\(after.orphans) orphaned splits survived deleteAll")
    }

    @Test("TransactionResetService.reset leaves no transactions and no splits")
    func resetCascades() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(store.splitCount == store.splitParents * 2)

        let outcome = TransactionResetService.reset(in: store.context)

        let after = try onDisk(store)
        #expect(outcome == .success)
        #expect(after.rows == 0)
        #expect(after.splits == 0, "\(after.splits) of \(store.splitCount) splits survived reset")
        #expect(after.orphans == 0, "\(after.orphans) orphaned splits survived reset")
    }

    @Test("LargeDatasetDebugSeed.wipeLedger leaves no transactions and no splits")
    func wipeLedgerCascades() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        try LargeDatasetDebugSeed.wipeLedger(modelContext: store.context)

        let after = try onDisk(store)
        #expect(after.rows == 0)
        #expect(after.splits == 0, "\(after.splits) of \(store.splitCount) splits survived wipeLedger")
        #expect(after.orphans == 0, "\(after.orphans) orphaned splits survived wipeLedger")
    }
}
