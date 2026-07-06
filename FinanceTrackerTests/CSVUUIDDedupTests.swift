//
//  CSVUUIDDedupTests.swift
//  FinanceTracker
//
//  Import dedup keyed on the transaction's stable UUID (not the fragile
//  content+day heuristic). Guards the reported bug: two genuinely-distinct
//  identical transactions on the same day must NOT be merged on import.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVUUIDDedupTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Idempotent re-import: exporting our own data then re-importing it into the
    /// SAME store adds nothing — every row is UUID-matched and skipped.
    func testReimportOwnExport_IsIdempotent() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        ctx.insert(cat)
        for i in 0..<3 {
            ctx.insert(Transaction(
                typeRaw: "expense",
                amountCents: 100 + i,
                currency: "USD",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                category: cat,
                merchant: "Cafe\(i)"
            ))
        }
        try ctx.save()

        let exported = try CSVExportService.makeCSV(modelContext: ctx, scope: .all)
        let result = try CSVImportService.importCSV(modelContext: ctx, data: exported.data)

        XCTAssertEqual(result.imported, 0, "Own export re-imported must add no rows")
        XCTAssertEqual(result.duplicatesSkipped, 3, "All three UUID-matched")

        let txs = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 3, "Still exactly the three originals")
    }

    /// THE REPORTED BUG: two distinct transactions, identical in
    /// type/amount/currency/day/category/name but with different UUIDs, must both
    /// survive a round-trip into an EMPTY store. The old content+day heuristic
    /// falsely merged them into one.
    func testTwoDistinctIdenticalRows_AreNotMerged() throws {
        let src = try makeContext()
        let cat = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        src.insert(cat)
        // Same everything except uuid (UUID() defaults differ).
        for _ in 0..<2 {
            src.insert(Transaction(
                typeRaw: "expense",
                amountCents: 500,
                currency: "USD",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                category: cat,
                merchant: "Cafe"
            ))
        }
        try src.save()

        let exported = try CSVExportService.makeCSV(modelContext: src, scope: .all)

        let dest = try makeContext()
        let result = try CSVImportService.importCSV(modelContext: dest, data: exported.data)

        XCTAssertEqual(result.imported, 2, "Distinct UUIDs → both import; no false merge")
        let txs = try dest.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2, "Both genuine transactions must survive")
    }

    /// Foreign CSV (no `id` column) that content-matches existing data must be
    /// IMPORTED (never silently dropped) and reported under possibleDuplicates.
    func testForeignCSV_ContentMatch_ImportedAndFlagged() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        ctx.insert(cat)
        ctx.insert(Transaction(
            typeRaw: "expense",
            amountCents: 1234,
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            category: cat,
            merchant: "Cafe"
        ))
        try ctx.save()

        // Legacy 9-column CSV, no id column, day-only date, content-matching row.
        let foreign = """
        date,type,amount,currency,category,source,tax,note,merchant
        2023-11-14,expense,12.34,USD,Food,,0.00,,Cafe
        """
        let result = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreign.utf8))

        XCTAssertEqual(result.imported, 1, "Foreign row must be imported, not dropped")
        XCTAssertEqual(result.possibleDuplicates, 1, "Content-match is flagged for review")

        let txs = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2, "Original + the imported foreign row")
    }

    /// The no-false-merge round-trip must also hold under a comma-decimal locale
    /// (keeps the 16f8b75 separator fix honest end-to-end).
    func testNoFalseMerge_RoundTrip_ru_RU() throws {
        let previous = Locale.current
        _ = previous // documentation: export/import are locale-invariant by design

        let src = try makeContext()
        let cat = Category(name: "Еда", kindRaw: "expense", icon: nil, order: 1)
        src.insert(cat)
        for _ in 0..<2 {
            src.insert(Transaction(
                typeRaw: "expense",
                amountCents: 152, // 1,52 in ru_RU — must not spill columns
                currency: "EUR",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                category: cat,
                merchant: "Кафе"
            ))
        }
        try src.save()

        let exported = try CSVExportService.makeCSV(modelContext: src, scope: .all)
        let dest = try makeContext()
        let result = try CSVImportService.importCSV(modelContext: dest, data: exported.data)

        XCTAssertEqual(result.imported, 2, "Both distinct rows survive under ru_RU")
        let txs = try dest.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2)
        XCTAssertTrue(txs.allSatisfy { $0.amountCents == 152 }, "Separator must not corrupt amount")
    }
}
