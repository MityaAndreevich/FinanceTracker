//
//  CSVImportDedupTests.swift
//  FinanceTracker
//
//  Re-importing a file whose rows already exist must NOT silently duplicate
//  them. Default is OS-copy-style "skip duplicates"; callers may opt into
//  "import all (keep both)".
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVImportDedupTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    func testReimport_SkipDuplicates_CreatesNoDuplicateRows() throws {
        let first = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)
        XCTAssertEqual(first.imported, 2)

        let second = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)
        XCTAssertEqual(second.imported, 0, "Rows already present must not be re-inserted")
        XCTAssertEqual(second.duplicatesSkipped, 2)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2, "Still exactly the two original rows")
    }

    func testReimport_ImportAll_KeepsBothCopies() throws {
        _ = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .skipDuplicates)

        let second = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8), mode: .importAll)
        XCTAssertEqual(second.imported, 2)
        XCTAssertEqual(second.duplicatesSkipped, 0)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 4, "Import-all intentionally keeps both copies")
    }

    /// Duplicates *within a single file* are also collapsed under skip.
    func testImport_SkipDuplicates_CollapsesInFileDuplicates() throws {
        let dupFile = csv + "\n2026-01-20,income,100.00,USD,Salary,Amazon Flex,10.00,Weekly payout,Amazon"
        let result = try CSVImportService.importCSV(modelContext: context, data: Data(dupFile.utf8), mode: .skipDuplicates)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.duplicatesSkipped, 1)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2)
    }
}
