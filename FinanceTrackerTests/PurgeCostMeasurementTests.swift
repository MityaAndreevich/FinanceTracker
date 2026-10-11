//
//  PurgeCostMeasurementTests.swift
//  FinanceTrackerTests
//
//  Guards what `LargeDatasetDebugSeed.purgeIfLeftOver` costs at the size the
//  seam seeds (DEFECT_REGISTER D33).
//
//  HISTORY
//    2026-08-14: written as a MEASUREMENT. `wipeLedger` was private, so the test
//    timed a verbatim COPY of its body, and its 120 s ceiling only caught a cost
//    that would obviously break any launch. It measured 45 764 ms. That is the
//    attributed cause of the three intermittent UI tests (STATE §9.2): the first
//    non-scale launch after a scale-seeding class spends ~46 s on the main thread
//    deleting rows, while every waiting assertion in the suite times out at 8–20 s.
//
//    2026-10-11: turned into a GUARD. It now calls the REAL `wipeLedger` (made
//    internal for this; a copy stops measuring the moment the original changes)
//    on a store shaped like the seed, splits included, because the cost is the
//    maintenance of the `Category.transactions` / `Category.splits` inverses, not
//    the row count alone.
//
//  THE BUDGET — set at 5 s on 2026-10-11, BEFORE the fix was run against it.
//    The shortest UI-test wait is 8 s, and the purge must leave the launch room
//    inside that wait. The same technique measured 0.72 s on the structurally
//    identical bulk-delete path (BRIEF_BULK_DELETE_P1_P2_P3), so 5 s leaves ~7×
//    headroom for a loaded full-suite machine (16 GB, swap-bound). Under 5 s does
//    NOT prove the UI tests are cured. Only a full run can show that.
//

import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class PurgeCostMeasurementTests: XCTestCase {

    /// What `LargeDatasetDebugSeed` seeds.
    private static let seedCount = LargeDatasetDebugSeed.targetCount

    /// Pre-registered 2026-10-11. See the header. Do not raise it to make a run pass.
    private static let budgetSeconds: TimeInterval = 5.0

    func test_wipeLedgerCost_at8kRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("purge-cost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appendingPathComponent("Vela.sqlite")
        let local = directory.appendingPathComponent("VelaLocal.sqlite")

        let container = try SharedModelContainer.openContainer(storeURL: store, localStoreURL: local)
        let context = container.mainContext

        // Shape it like the real seed: rows across the standard category set, a
        // source, and a 2-part split on every 7th row (the seed's own ratio).
        var categories: [FinanceTracker.Category] = []
        for i in 0..<13 {
            let category = FinanceTracker.Category(name: "Cat\(i)", kindRaw: "expense", order: i)
            context.insert(category)
            categories.append(category)
        }
        let source = FinanceTracker.Source(name: "Cash")
        context.insert(source)
        var splitCount = 0
        for i in 0..<Self.seedCount {
            let tx = FinanceTracker.Transaction(
                typeRaw: "expense",
                amountCents: 1_000 + i,
                currency: "USD",
                date: Date(timeIntervalSince1970: 1_750_000_000 - Double(i) * 3_600),
                category: categories[i % categories.count],
                source: source
            )
            context.insert(tx)
            if i % 7 == 0 {
                for part in 0..<2 {
                    let split = FinanceTracker.TransactionSplit(
                        amountCents: 100,
                        category: categories[(i + part + 1) % categories.count],
                        order: part
                    )
                    context.insert(split)
                    split.parent = tx
                    splitCount += 1
                }
            }
        }
        try context.save()

        // Assert the store we are about to time is the store we meant to build.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.Transaction>()), Self.seedCount,
                       "seeding failed — a cost measured over the wrong store is worthless")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.TransactionSplit>()), splitCount)
        XCTAssertGreaterThan(splitCount, 2_000)

        let start = Date()
        try LargeDatasetDebugSeed.wipeLedger(modelContext: context)
        let elapsed = Date().timeIntervalSince(start)

        // Presence of the outcome, not only the timing: the ledger is empty and
        // the categories survive (the purge deletes rows, never the taxonomy).
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.Transaction>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.TransactionSplit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.Category>()), 13)

        let ms = Int(elapsed * 1000)
        print("PURGECOST wipeLedger over \(Self.seedCount) rows + \(splitCount) splits took \(ms) ms")
        XCTAssertLessThan(elapsed, Self.budgetSeconds,
                          "wipeLedger took \(ms) ms at \(Self.seedCount) rows; budget \(Int(Self.budgetSeconds * 1000)) ms")
    }
}
