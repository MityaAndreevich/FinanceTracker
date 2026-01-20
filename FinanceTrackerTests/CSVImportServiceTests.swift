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
