//
//  CSVImportServiceTests.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 20.01.2026.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVImportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    func testImportCSV_ImportsValidRowAndCreatesCategoryAndSource() throws {
        // Given: no categories/sources exist yet
        let csv = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,income,100.00,USD,Salary,Amazon Flex,10.00,Weekly payout,Amazon
        """

        // When
        let result = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8))

        // Then
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.createdCategories, 1)
        XCTAssertEqual(result.createdSources, 1)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)

        let tx = txs[0]
        XCTAssertEqual(tx.typeRaw, "income")
        XCTAssertEqual(tx.amountCents, 10_000)
        XCTAssertEqual(tx.currency, "USD")
        XCTAssertEqual(tx.category.name, "Salary")
        XCTAssertEqual(tx.source?.name, "Amazon Flex")
        XCTAssertEqual(tx.taxCents, 1_000)
        XCTAssertEqual(tx.note, "Weekly payout")
        XCTAssertEqual(tx.merchant, "Amazon")
    }

    func testImportCSV_SkipsInvalidRowButKeepsGoing() throws {
        let csv = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,income,100.00,USD,Salary,Amazon Flex,10.00,Weekly payout,Amazon
        2026-01-XX,expense,abc,USD,Food,, ,Bad row,Cafe
        2026-01-21,expense,12.34,USD,Food,,0.00,Lunch,Cafe
        """

        let result = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8))

        XCTAssertEqual(result.imported, 2)
        XCTAssertGreaterThanOrEqual(result.skipped, 1)
        XCTAssertNotNil(result.firstError)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 2)
    }

    // T-10: row limit
    func testImportCSV_ThrowsWhenRowLimitExceeded() throws {
        let header = "date,type,amount,currency,category,source,tax,note,merchant\n"
        let row = "2026-01-20,income,1.00,USD,Salary,,0.00,,\n"
        let csv = header + String(repeating: row, count: CSVImportService.MAX_ROWS + 1)

        XCTAssertThrowsError(try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8))) { error in
            XCTAssertTrue((error as NSError).domain == "CSVImport")
            XCTAssertTrue((error as NSError).code == 4)
        }
    }

    // T-10: field length limit
    func testImportCSV_SkipsRowWithOversizedField() throws {
        let longNote = String(repeating: "x", count: CSVImportService.MAX_FIELD_LENGTH + 1)
        let csv = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,income,10.00,USD,Salary,,0.00,\(longNote),
        2026-01-21,income,5.00,USD,Salary,,0.00,Normal note,
        """

        let result = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8))

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertNotNil(result.firstError)
    }

    func testImportCSV_InvalidCurrencyFallsBackToDefault() throws {
        UserDefaults.standard.set("EUR", forKey: "defaultCurrencyCode")
        defer { UserDefaults.standard.removeObject(forKey: "defaultCurrencyCode") }

        let csv = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,expense,50.00,INVALID,Food,,0.00,,Grocery
        """

        let result = try CSVImportService.importCSV(modelContext: context, data: Data(csv.utf8))
        XCTAssertEqual(result.imported, 1)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs[0].currency, "EUR")
    }

    func testImportCSV_ParsesCommaDecimal() throws {
        let csv = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,expense,12,34,USD,Food,,,Lunch,Cafe
        """

        // NOTE: This CSV is actually ambiguous because comma is also a separator.
        // Our exporter uses dot, so we test comma-decimal safely by quoting the amount:
        let fixed = """
        date,type,amount,currency,category,source,tax,note,merchant
        2026-01-20,expense,"12,34",USD,Food,,,Lunch,Cafe
        """

        let result = try CSVImportService.importCSV(modelContext: context, data: Data(fixed.utf8))
        XCTAssertEqual(result.imported, 1)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs[0].amountCents, 1234)
    }
}
