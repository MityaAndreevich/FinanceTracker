//
//  CSVExportServiceTests.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 20.01.2026.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // In-memory SwiftData container for isolated tests
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testExportCSV_HasHeader() throws {
        // Given: no transactions
        let result = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        let csv = String(data: result.data, encoding: .utf8)

        XCTAssertNotNil(csv)
        XCTAssertTrue(csv!.hasPrefix("date,type,amount,currency,category,source,tax,note,merchant"))
    }

    func testExportCSV_ExportsOneTransactionRow() throws {
        // Given
        let cat = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        context.insert(cat)

        let tx = Transaction(
            typeRaw: "expense",
            amountCents: 1234,
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000), // fixed
            category: cat,
            source: nil,
            taxCents: nil,
            note: "Lunch",
            merchant: "Cafe"
        )
        context.insert(tx)
        try context.save()

        // When
        let result = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        let csv = String(data: result.data, encoding: .utf8)!

        // Then: header + 1 row
        let lines = csv.components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 2)

        // Row should contain category and merchant and note
        XCTAssertTrue(csv.contains("Food"))
        XCTAssertTrue(csv.contains("Cafe"))
        XCTAssertTrue(csv.contains("Lunch"))
    }

    func testExportCSV_EscapesCommasAndQuotes() throws {
        // Given
        let cat = Category(name: "Food, Drinks", kindRaw: "expense", icon: nil, order: 1)
        context.insert(cat)

        let tx = Transaction(
            typeRaw: "expense",
            amountCents: 500,
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            category: cat,
            source: nil,
            taxCents: nil,
            note: "He said \"hi\"",
            merchant: "Cafe, Inc."
        )
        context.insert(tx)
        try context.save()

        // When
        let result = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        let csv = String(data: result.data, encoding: .utf8)!

        // Then: values with commas/quotes should be quoted and quotes doubled
        XCTAssertTrue(csv.contains("\"Food, Drinks\""))
        XCTAssertTrue(csv.contains("\"Cafe, Inc.\""))
        XCTAssertTrue(csv.contains("\"He said \"\"hi\"\"\""))
    }
}
