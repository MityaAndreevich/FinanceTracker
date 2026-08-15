//
//  PurgeCostMeasurementTests.swift
//  FinanceTrackerTests
//
//  Measures what `LargeDatasetDebugSeed.purgeIfLeftOver` actually costs, because
//  it was the last UNMEASURED inference in the UI-suite investigation.
//
//  THE CLAIM UNDER TEST
//    `BUG…`/`BRIEF_UI_SHARED_CONTAINER_RESIDUE` argued two mechanisms behind the
//    flaky UI suite: (1) the purge deleted demo rows it should not have — FIXED
//    by moving it to the top of the launch task, and confirmed fixed by the
//    `editAfterQuickAddInsert` failure disappearing from both arms; and (2) the
//    purge's DELETE ITSELF is slow enough at 8 000 rows to blow the timeouts of
//    whichever test launches next. (2) was inferred from the shape of the code
//    and from a structurally similar path measured at 44.7 s
//    (`BRIEF_BULK_DELETE_P1_P2_P3`), never measured here.
//
//  This measures it. `wipeLedger` is private and DEBUG-only, so the body is
//  reproduced exactly: fetch every split, delete each; fetch every transaction,
//  delete each; one save.
//

import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class PurgeCostMeasurementTests: XCTestCase {

    /// What `LargeDatasetDebugSeed` seeds.
    private static let seedCount = 8_000

    func test_wipeLedgerCost_at8kRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("purge-cost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appendingPathComponent("Vela.sqlite")
        let local = directory.appendingPathComponent("VelaLocal.sqlite")

        let container = try SharedModelContainer.openContainer(storeURL: store, localStoreURL: local)
        let context = container.mainContext

        // Shape it like the real seed: rows spread across the standard category
        // set, because the cost being investigated is the maintenance of
        // `Category.transactions` — a to-many inverse — not the row count alone.
        var categories: [FinanceTracker.Category] = []
        for i in 0..<13 {
            let category = FinanceTracker.Category(name: "Cat\(i)", kindRaw: "expense", order: i)
            context.insert(category)
            categories.append(category)
        }
        let source = FinanceTracker.Source(name: "Cash")
        context.insert(source)
        for i in 0..<Self.seedCount {
            let tx = FinanceTracker.Transaction(
                typeRaw: "expense",
                amountCents: 100 + i,
                currency: "USD",
                date: Date(timeIntervalSince1970: 1_750_000_000 - Double(i) * 3_600),
                category: categories[i % categories.count],
                source: source
            )
            context.insert(tx)
        }
        try context.save()

        let seeded = try context.fetchCount(FetchDescriptor<FinanceTracker.Transaction>())
        XCTAssertEqual(seeded, Self.seedCount, "seeding failed — a cost measured over the wrong store is worthless")

        // ── wipeLedger, verbatim ────────────────────────────────────────────
        let start = Date()
        for split in try context.fetch(FetchDescriptor<FinanceTracker.TransactionSplit>()) {
            context.delete(split)
        }
        for tx in try context.fetch(FetchDescriptor<FinanceTracker.Transaction>()) {
            context.delete(tx)
        }
        try context.save()
        let elapsed = Date().timeIntervalSince(start)
        // ────────────────────────────────────────────────────────────────────

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTracker.Transaction>()), 0)

        let ms = Int(elapsed * 1000)
        print("PURGECOST wipeLedger over \(Self.seedCount) rows took \(ms) ms")

        // Deliberately generous: this is a MEASUREMENT, and its number belongs in
        // the report, not in a threshold nobody re-derives. It fails only if the
        // cost is so large that it would obviously break any launch that runs it,
        // which is the claim under test.
        XCTAssertLessThan(elapsed, 120.0,
                          "wipeLedger took \(ms) ms at \(Self.seedCount) rows")
    }
}
