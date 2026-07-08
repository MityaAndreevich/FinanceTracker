//
//  CSVImportSignTests.swift
//  FinanceTrackerTests
//
//  The #1 place naive importers corrupt financial data: deriving the signed
//  amount. Foreign files express direction three incompatible ways, and all
//  three must resolve to a positive magnitude + a typeRaw ("income"/"expense"),
//  because Transaction stores an unsigned amountCents and derives sign from type.
//    1. Signed single column         "-12.34"          → expense 1234
//    2. Unsigned amount + type col   "12.34" + "debit" → expense 1234  (Mint)
//    3. Two columns debit/credit     debit vs credit   → the non-empty one wins
//  Degenerate rows (both debit+credit empty, or both filled) are REPORTED, not
//  crashed and not silently coerced.
//

import XCTest
@testable import FinanceTracker

final class CSVImportSignTests: XCTestCase {

    private func ok(_ cents: Int, _ type: String) -> Result<SignedAmount, ImportAmountFailure> {
        .success(SignedAmount(cents: cents, typeRaw: type))
    }

    // MARK: - Shape 1: signed single column

    func testSignedNegativeIsExpense() {
        XCTAssertEqual(ImportSign.combineSigned("-12.34", decimal: .period), ok(1234, "expense"))
    }

    func testSignedPositiveIsIncome() {
        XCTAssertEqual(ImportSign.combineSigned("12.34", decimal: .period), ok(1234, "income"))
    }

    func testSignedParenthesesIsExpense() {
        XCTAssertEqual(ImportSign.combineSigned("(99.00)", decimal: .period), ok(9900, "expense"))
    }

    func testSignedUnparsable() {
        XCTAssertEqual(ImportSign.combineSigned("abc", decimal: .period), .failure(.unparsableAmount))
    }

    // MARK: - Shape 2: unsigned amount + Mint-style type column

    func testMintDebitIsExpense() {
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "1,234.56", type: "debit", decimal: .period),
                       ok(123456, "expense"))
    }

    func testMintCreditIsIncome() {
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "1,234.56", type: "credit", decimal: .period),
                       ok(123456, "income"))
    }

    func testTypeSynonymsClassify() {
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "50.00", type: "DEPOSIT", decimal: .period), ok(5000, "income"))
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "50.00", type: "Withdrawal", decimal: .period), ok(5000, "expense"))
    }

    func testUnrecognizedTypeReported() {
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "50.00", type: "banana", decimal: .period),
                       .failure(.unrecognizedType("banana")))
    }

    func testUnsignedWithTypeUnparsableAmount() {
        XCTAssertEqual(ImportSign.combineUnsignedWithType(amount: "xx", type: "debit", decimal: .period),
                       .failure(.unparsableAmount))
    }

    // MARK: - Shape 3: two-column debit/credit

    func testCreditColumnIsIncome() {
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "", credit: "100.00", decimal: .period), ok(10000, "income"))
    }

    func testDebitColumnIsExpense() {
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "25.00", credit: "", decimal: .period), ok(2500, "expense"))
    }

    func testDebitColumnMagnitudeIgnoresSign() {
        // Some banks write the debit column as a negative; take the magnitude.
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "-25.00", credit: "", decimal: .period), ok(2500, "expense"))
    }

    func testBothColumnsZeroIsReportedEmpty() {
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "0.00", credit: "0.00", decimal: .period), .failure(.bothColumnsEmpty))
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "", credit: "", decimal: .period), .failure(.bothColumnsEmpty))
    }

    func testBothColumnsFilledIsReported() {
        XCTAssertEqual(ImportSign.combineDebitCredit(debit: "10.00", credit: "20.00", decimal: .period), .failure(.bothColumnsFilled))
    }
}
