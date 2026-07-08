//
//  CSVImportRowMapperTests.swift
//  FinanceTrackerTests
//
//  The pure end-to-end mapper: a raw foreign CSV row + a ColumnMapping →
//  a NormalizedTransaction (or a typed failure). This is the single seam the
//  SwiftData importer (Unit 6) sits on top of, so it must never crash and never
//  silently drop a row: unmappable rows come back as failures, empty category
//  becomes the uncategorized fallback (nil), and a missing currency is assumed +
//  flagged.
//

import XCTest
@testable import FinanceTracker

final class CSVImportRowMapperTests: XCTestCase {

    private func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private let mintHeader = ["Date", "Description", "Original Description", "Amount",
                              "Transaction Type", "Category", "Account Name", "Labels", "Notes"]

    private func map(_ row: [String], _ mapping: ColumnMapping) -> Result<NormalizedTransaction, RowMapFailure> {
        ImportRowMapper.map(row: row, mapping: mapping, defaultCurrency: "USD")
    }

    // MARK: - Mint end-to-end

    func testMintExpenseRow() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["1/20/2026", "Starbucks", "STARBUCKS #123", "5.50", "debit", "Food", "Chase", "", "coffee"]
        let tx = try map(row, m).get()
        XCTAssertEqual(tx.date, utc(2026, 1, 20))
        XCTAssertEqual(tx.amountCents, 550)
        XCTAssertEqual(tx.typeRaw, "expense")
        XCTAssertEqual(tx.categoryName, "Food")
        XCTAssertEqual(tx.merchant, "Starbucks")
        XCTAssertEqual(tx.note, "coffee")
        XCTAssertEqual(tx.account, "Chase")
        XCTAssertEqual(tx.currency, "USD")
        XCTAssertTrue(tx.currencyAssumed, "Mint files carry no currency → assumed + flagged")
    }

    func testMintCreditRowIsIncomeWithGroupedAmount() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["2/1/2026", "Payroll", "ACME", "1,234.56", "credit", "Income", "Chase", "", ""]
        let tx = try map(row, m).get()
        XCTAssertEqual(tx.amountCents, 123456)
        XCTAssertEqual(tx.typeRaw, "income")
        XCTAssertNil(tx.note, "Empty note cell → nil, not empty string")
    }

    // MARK: - EU comma-decimal generic bank

    func testEUCommaDecimalDMY() {
        // decimal ",", date DD.MM.YYYY. amount "1.234,56" must be 123456, not corrupted.
        let mapping = ColumnMapping(
            date: 0, dateOrder: .dmy, decimal: .comma,
            amount: .signed(1), category: nil, merchant: 2, note: nil, account: nil)
        let tx = try? map(["20.01.2026", "-1.234,56", "Grocery"], mapping).get()
        XCTAssertEqual(tx?.date, utc(2026, 1, 20))
        XCTAssertEqual(tx?.amountCents, 123456)
        XCTAssertEqual(tx?.typeRaw, "expense")
        XCTAssertEqual(tx?.merchant, "Grocery")
    }

    // MARK: - Uncategorized fallback

    func testEmptyCategoryFallsBackToNil() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["1/20/2026", "Corner Shop", "", "9.99", "debit", "", "Cash", "", ""]
        let tx = try map(row, m).get()
        XCTAssertNil(tx.categoryName, "Empty category → uncategorized fallback, NOT a failure")
    }

    // MARK: - Currency column honored when present + valid

    func testExplicitCurrencyNotAssumed() {
        let mapping = ColumnMapping(
            date: 0, dateOrder: .iso, decimal: .period,
            amount: .signed(1), category: nil, merchant: nil, note: nil, account: nil, currency: 2)
        let tx = try? map(["2026-01-20", "10.00", "EUR"], mapping).get()
        XCTAssertEqual(tx?.currency, "EUR")
        XCTAssertEqual(tx?.currencyAssumed, false)
    }

    func testInvalidCurrencyFallsBackAssumed() {
        let mapping = ColumnMapping(
            date: 0, dateOrder: .iso, decimal: .period,
            amount: .signed(1), category: nil, merchant: nil, note: nil, account: nil, currency: 2)
        let tx = try? map(["2026-01-20", "10.00", "XYZ"], mapping).get()
        XCTAssertEqual(tx?.currency, "USD")
        XCTAssertEqual(tx?.currencyAssumed, true)
    }

    // MARK: - Failures are reported, never dropped or crashed

    func testMissingDate() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["", "X", "", "1.00", "debit", "Food", "", "", ""]
        XCTAssertEqual(map(row, m), .failure(.missingDate))
    }

    func testInvalidDate() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["31/31/2026", "X", "", "1.00", "debit", "Food", "", "", ""]
        XCTAssertEqual(map(row, m), .failure(.invalidDate("31/31/2026")))
    }

    func testUnparsableAmount() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mintHeader))
        let row = ["1/20/2026", "X", "", "N/A", "debit", "Food", "", "", ""]
        XCTAssertEqual(map(row, m), .failure(.amount(.unparsableAmount)))
    }

    func testDebitCreditBothEmptyReported() {
        let mapping = ColumnMapping(
            date: 0, dateOrder: .iso, decimal: .period,
            amount: .debitCredit(debit: 1, credit: 2), category: nil, merchant: nil, note: nil, account: nil)
        XCTAssertEqual(map(["2026-01-20", "", ""], mapping), .failure(.amount(.bothColumnsEmpty)))
    }
}
