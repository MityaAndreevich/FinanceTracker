//
//  CSVMappedImportTests.swift
//  FinanceTrackerTests
//
//  Tier-2 integration: importMappedCSV drives the pure mapper into SwiftData,
//  reusing the existing foreign-row dedup (flag, never drop) and category/source
//  creation. Covers a real Mint file, a two-column bank file, the uncategorized
//  fallback, currency-assumed flagging, malformed-row reporting, and re-import
//  dedup.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVMappedImportTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // Pin the assumed currency so tests are deterministic regardless of the
        // simulator's ambient `defaultCurrencyCode` (the mapper reads it live).
        UserDefaults.standard.set("USD", forKey: "defaultCurrencyCode")

        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Mint

    private let mintCSV = """
    Date,Description,Original Description,Amount,Transaction Type,Category,Account Name,Labels,Notes
    1/20/2026,Starbucks,STARBUCKS #1,5.50,debit,Food,Chase,,coffee
    2/1/2026,Payroll,ACME CORP,"1,234.56",credit,Income,Chase,,
    """

    private func mintMapping() throws -> ColumnMapping {
        let header = ["Date", "Description", "Original Description", "Amount",
                      "Transaction Type", "Category", "Account Name", "Labels", "Notes"]
        return try XCTUnwrap(SourcePreset.mint.defaultMapping(header: header))
    }

    func testMintImportSignsAmountsAndCurrencyFlag() throws {
        let r = try CSVImportService.importMappedCSV(
            modelContext: context, data: Data(mintCSV.utf8), mapping: mintMapping())
        XCTAssertEqual(r.imported, 2)
        XCTAssertEqual(r.failedRows, 0)
        XCTAssertEqual(r.currencyAssumed, 2, "Mint files carry no currency → both assumed")

        let txs = try context.fetch(FetchDescriptor<Transaction>()).sorted { $0.amountCents < $1.amountCents }
        XCTAssertEqual(txs[0].amountCents, 550)
        XCTAssertEqual(txs[0].typeRaw, "expense")
        XCTAssertEqual(txs[0].merchant, "Starbucks")
        XCTAssertEqual(txs[0].note, "coffee")
        XCTAssertEqual(txs[1].amountCents, 123456, "'1,234.56' grouped amount imported intact")
        XCTAssertEqual(txs[1].typeRaw, "income")
        XCTAssertEqual(txs[0].currency, "USD")
    }

    func testMintReimportFlagsNotDrops() throws {
        _ = try CSVImportService.importMappedCSV(modelContext: context, data: Data(mintCSV.utf8), mapping: mintMapping())
        let second = try CSVImportService.importMappedCSV(modelContext: context, data: Data(mintCSV.utf8), mapping: mintMapping())
        XCTAssertEqual(second.imported, 2, "Foreign rows are never silently dropped")
        XCTAssertEqual(second.possibleDuplicates, 2, "Both content-match existing data")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 4)
    }

    // MARK: - Two-column bank CSV

    func testTwoColumnDebitCredit() throws {
        let csv = """
        Date,Description,Debit,Credit,Balance
        2026-01-20,ATM Withdrawal,40.00,,100.00
        2026-01-21,Refund,,15.00,115.00
        """
        let header = ["Date", "Description", "Debit", "Credit", "Balance"]
        let mapping = try XCTUnwrap(SourcePreset.genericBank.defaultMapping(header: header))
        let r = try CSVImportService.importMappedCSV(modelContext: context, data: Data(csv.utf8), mapping: mapping)
        XCTAssertEqual(r.imported, 2)

        let txs = try context.fetch(FetchDescriptor<Transaction>()).sorted { $0.amountCents < $1.amountCents }
        XCTAssertEqual(txs[0].amountCents, 1500)
        XCTAssertEqual(txs[0].typeRaw, "income")   // credit
        XCTAssertEqual(txs[1].amountCents, 4000)
        XCTAssertEqual(txs[1].typeRaw, "expense")  // debit
    }

    // MARK: - Uncategorized fallback

    func testEmptyCategoryLandsInUncategorized() throws {
        let csv = """
        Date,Description,Original Description,Amount,Transaction Type,Category,Account Name,Labels,Notes
        1/20/2026,Corner Shop,,9.99,debit,,Cash,,
        """
        let r = try CSVImportService.importMappedCSV(modelContext: context, data: Data(csv.utf8), mapping: mintMapping())
        XCTAssertEqual(r.imported, 1, "Empty category must NOT block import")
        let tx = try XCTUnwrap(try context.fetch(FetchDescriptor<Transaction>()).first)
        XCTAssertEqual(tx.category.nameKey, "category.other", "Falls back to the seeded uncategorized bucket")
    }

    // MARK: - Malformed rows are reported, not dropped

    // MARK: - Preview parsing (drives the mapping sheet)

    func testParsePreviewSplitsHeaderAndRows() throws {
        let csv = "A,B,C\n1,2,3\n\"x,y\",5,6"
        let p = try XCTUnwrap(CSVImportService.parsePreview(data: Data(csv.utf8)))
        XCTAssertEqual(p.header, ["A", "B", "C"])
        XCTAssertEqual(p.rows.count, 2)
        XCTAssertEqual(p.rows[0], ["1", "2", "3"])
        XCTAssertEqual(p.rows[1], ["x,y", "5", "6"], "quoted comma preserved")
    }

    func testParsePreviewCapsRows() throws {
        let body = (1...50).map { "\($0),x" }.joined(separator: "\n")
        let p = try XCTUnwrap(CSVImportService.parsePreview(data: Data("H1,H2\n\(body)".utf8), maxRows: 10))
        XCTAssertEqual(p.rows.count, 10)
    }

    func testSeparatorInconsistentAmountRoutedToFailedRows() throws {
        // "1,2345" is malformed for a period-decimal file (comma grouping needs 3
        // digits). It must be reported, not silently coerced to $1.23.
        let csv = """
        Date,Description,Original Description,Amount,Transaction Type,Category,Account Name,Labels,Notes
        1/20/2026,Bad,,"1,2345",debit,Food,Cash,,
        1/21/2026,Good,,3.00,debit,Food,Cash,,
        """
        let r = try CSVImportService.importMappedCSV(modelContext: context, data: Data(csv.utf8), mapping: mintMapping())
        XCTAssertEqual(r.imported, 1)
        XCTAssertEqual(r.failedRows, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 1)
    }

    func testMalformedRowReportedOthersImported() throws {
        let csv = """
        Date,Description,Original Description,Amount,Transaction Type,Category,Account Name,Labels,Notes
        1/20/2026,Bad,,N/A,debit,Food,Cash,,
        1/21/2026,Good,,3.00,debit,Food,Cash,,
        """
        let r = try CSVImportService.importMappedCSV(modelContext: context, data: Data(csv.utf8), mapping: mintMapping())
        XCTAssertEqual(r.imported, 1)
        XCTAssertEqual(r.failedRows, 1)
        XCTAssertNotNil(r.firstError)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 1)
    }
}
