//
//  CSVImportPresetTests.swift
//  FinanceTrackerTests
//
//  Source-preset detection + default column mappings. The user can override any
//  of this in the mapping sheet, but a good auto-detect is what makes migration
//  one-tap. Mint columns are per the migration roadmap; YNAB (Outflow/Inflow)
//  and Monarch (signed Amount) use their documented public export formats.
//

import XCTest
@testable import FinanceTracker

final class CSVImportPresetTests: XCTestCase {

    private let mint = ["Date", "Description", "Original Description", "Amount",
                        "Transaction Type", "Category", "Account Name", "Labels", "Notes"]
    private let ynab = ["Account", "Flag", "Date", "Payee", "Category Group/Category",
                        "Category Group", "Category", "Memo", "Outflow", "Inflow", "Cleared"]
    private let monarch = ["Date", "Merchant", "Category", "Account",
                           "Original Statement", "Notes", "Amount", "Tags"]
    private let genericDebitCredit = ["Transaction Date", "Description", "Debit", "Credit", "Balance"]
    private let genericSigned = ["Date", "Payee", "Amount"]

    // MARK: - Detection

    func testDetectMint() { XCTAssertEqual(SourcePreset.detect(header: mint), .mint) }
    func testDetectYNAB() { XCTAssertEqual(SourcePreset.detect(header: ynab), .ynab) }
    func testDetectMonarch() { XCTAssertEqual(SourcePreset.detect(header: monarch), .monarch) }
    func testDetectGenericDebitCredit() { XCTAssertEqual(SourcePreset.detect(header: genericDebitCredit), .genericBank) }
    func testDetectGenericSigned() { XCTAssertEqual(SourcePreset.detect(header: genericSigned), .genericBank) }
    func testDetectUnknownIsCustom() {
        XCTAssertEqual(SourcePreset.detect(header: ["Foo", "Bar", "Baz"]), .custom)
    }

    // MARK: - Default mappings

    func testMintMapping() throws {
        let m = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mint))
        XCTAssertEqual(m.date, 0)
        XCTAssertEqual(m.amount, .unsignedWithType(amount: 3, type: 4))  // Amount + Transaction Type
        XCTAssertEqual(m.category, 5)
        XCTAssertEqual(m.merchant, 1)   // Description
        XCTAssertEqual(m.note, 8)       // Notes
        XCTAssertEqual(m.account, 6)    // Account Name
        XCTAssertEqual(m.dateOrder, .mdy)
    }

    func testYNABMappingIsTwoColumn() throws {
        let m = try XCTUnwrap(SourcePreset.ynab.defaultMapping(header: ynab))
        XCTAssertEqual(m.date, 2)
        XCTAssertEqual(m.amount, .debitCredit(debit: 8, credit: 9))  // Outflow / Inflow
        XCTAssertEqual(m.merchant, 3)   // Payee
        XCTAssertEqual(m.note, 7)       // Memo
    }

    func testMonarchMappingIsSigned() throws {
        let m = try XCTUnwrap(SourcePreset.monarch.defaultMapping(header: monarch))
        XCTAssertEqual(m.date, 0)
        XCTAssertEqual(m.amount, .signed(6))   // Amount column
        XCTAssertEqual(m.merchant, 1)          // Merchant
        XCTAssertEqual(m.dateOrder, .iso)
    }

    func testGenericDebitCreditMapping() throws {
        let m = try XCTUnwrap(SourcePreset.genericBank.defaultMapping(header: genericDebitCredit))
        XCTAssertEqual(m.date, 0)  // "Transaction Date"
        XCTAssertEqual(m.amount, .debitCredit(debit: 2, credit: 3))
    }

    func testGenericSignedMapping() throws {
        let m = try XCTUnwrap(SourcePreset.genericBank.defaultMapping(header: genericSigned))
        XCTAssertEqual(m.amount, .signed(2))
    }

    func testGenericMappingNilWhenNoDate() {
        XCTAssertNil(SourcePreset.genericBank.defaultMapping(header: ["Payee", "Amount"]))
    }

    // A preset with a KNOWN convention declares it (period) and so wins over
    // auto-detect; only the generic/custom fallbacks auto-detect.
    func testPresetDecimalConventions() throws {
        XCTAssertEqual(try XCTUnwrap(SourcePreset.mint.defaultMapping(header: mint)).decimal, .period)
        XCTAssertEqual(try XCTUnwrap(SourcePreset.ynab.defaultMapping(header: ynab)).decimal, .period)
        XCTAssertEqual(try XCTUnwrap(SourcePreset.monarch.defaultMapping(header: monarch)).decimal, .period)
        XCTAssertEqual(try XCTUnwrap(SourcePreset.genericBank.defaultMapping(header: genericSigned)).decimal, .auto)
    }
}
