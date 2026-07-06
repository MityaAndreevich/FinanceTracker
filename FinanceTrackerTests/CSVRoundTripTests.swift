//
//  CSVRoundTripTests.swift
//  FinanceTracker
//
//  Export → import fidelity for the CSV subsystem. Guards the launch-blocker
//  data-integrity bugs found on device (ru_RU decimal separator + grouping
//  separator spilling the amount into the next comma-delimited column).
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class CSVRoundTripTests: XCTestCase {

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

    /// Fresh in-memory store to import into, so we round-trip into an *empty*
    /// database and can assert exactly one row survived.
    private func makeEmptyContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(c)
    }

    /// The exact device scenario: amount 1.52 EUR, Cyrillic category, a name
    /// containing a comma. Must re-import field-for-field identical, one row.
    func testRoundTrip_1_52_EUR_CyrillicCategory_CommaInName() throws {
        let cat = Category(name: "Еда и напитки", kindRaw: "expense", icon: nil, order: 1)
        context.insert(cat)
        let tx = Transaction(
            typeRaw: "expense",
            amountCents: 152,
            currency: "EUR",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            category: cat,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: "Картошка, лук"
        )
        context.insert(tx)
        try context.save()

        let exported = try CSVExportService.makeCSV(modelContext: context, scope: .all)

        let dest = try makeEmptyContext()
        let result = try CSVImportService.importCSV(modelContext: dest, data: exported.data)

        XCTAssertEqual(result.imported, 1)
        let txs = try dest.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1, "Column spill would drop/duplicate the row")
        XCTAssertEqual(txs[0].amountCents, 152, "Decimals must not spill into the currency column")
        XCTAssertEqual(txs[0].currency, "EUR")
        XCTAssertEqual(txs[0].category.displayName(), "Еда и напитки")
        XCTAssertEqual(txs[0].merchant, "Картошка, лук")
    }

    /// Locale-independent reproduction of the same class of bug: a large amount
    /// makes `.decimal` emit a thousands *grouping* comma (`1,234.56`) which
    /// splits the amount cell in two — regardless of the host machine's locale.
    func testRoundTrip_LargeAmount_NoGroupingSeparatorSpill() throws {
        let cat = Category(name: "Rent", kindRaw: "expense", icon: nil, order: 1)
        context.insert(cat)
        let tx = Transaction(
            typeRaw: "expense",
            amountCents: 123_456, // 1234.56
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            category: cat,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: "Landlord"
        )
        context.insert(tx)
        try context.save()

        let exported = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        let csvText = String(data: exported.data, encoding: .utf8)!
        XCTAssertFalse(csvText.contains("1,234"), "Amount must not carry a grouping separator")

        let dest = try makeEmptyContext()
        let result = try CSVImportService.importCSV(modelContext: dest, data: exported.data)

        XCTAssertEqual(result.imported, 1)
        let txs = try dest.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs[0].amountCents, 123_456)
        XCTAssertEqual(txs[0].currency, "USD")
    }
}
