//
//  CSVImportDedupTests.swift
//  FinanceTracker
//
//  Dedup semantics for FOREIGN CSVs (no `id` column). Since a foreign file
//  gives us no stable identity, we cannot tell a re-import apart from two real
//  identical transactions — so we NEVER drop the row. We import it and, when it
//  content-matches existing data, surface it as a possible duplicate for review.
//  Idempotent re-import of OUR OWN export (which carries UUIDs) is covered in
//  CSVUUIDDedupTests.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVImportDedupTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    /// Legacy 9-column layout with no `id` column → treated as foreign.
    private let csv = """
    date,type,amount,currency,category,source,tax,note,merchant
    2026-01-20,income,100.00,USD,Salary,Amazon Flex,10.00,Weekly payout,Amazon
    2026-01-21,expense,12.34,USD,Food,,0.00,Lunch,Cafe
    """

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    /// Re-importing a foreign file whose rows content-match existing data imports
    /// them again (never dropped) and flags each as a possible duplicate.
    func testReimportForeign_SkipDuplicates_ImportsAndFlags() throws {
        let first = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)
        XCTAssertEqual(first.imported, 2)
        XCTAssertEqual(first.possibleDuplicates, 0, "Nothing to match against on a fresh store")

        let second = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)
        XCTAssertEqual(second.imported, 2, "Foreign rows are never silently dropped")
        XCTAssertEqual(second.possibleDuplicates, 2, "Both content-match existing data")
        XCTAssertEqual(second.duplicatesSkipped, 0, "No UUID to skip on")

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 4, "Every real transaction is kept")
    }

    func testReimportForeign_ImportAll_KeepsBothCopies() throws {
        _ = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)

        let second = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .importAll)
        XCTAssertEqual(second.imported, 2)
        XCTAssertEqual(second.duplicatesSkipped, 0)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 4, "Import-all intentionally keeps both copies")
    }

    /// A foreign duplicate *within a single file* is imported and flagged, not
    /// dropped — it could be two genuine identical transactions.
    func testImportForeign_InFileDuplicate_ImportedAndFlagged() throws {
        let dupFile = csv + "\n2026-01-20,income,100.00,USD,Salary,Amazon Flex,10.00,Weekly payout,Amazon"
        let result = try CSVImportService.importCSV(modelContext: context, data: Data(dupFile.utf8), mode: .skipDuplicates)
        XCTAssertEqual(result.imported, 3, "All three rows kept")
        XCTAssertEqual(result.possibleDuplicates, 1, "The repeated row is flagged")

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 3)
    }
}
