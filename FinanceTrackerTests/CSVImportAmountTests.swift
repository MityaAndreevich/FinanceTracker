//
//  CSVImportAmountTests.swift
//  FinanceTrackerTests
//
//  Locale-tolerant amount parsing for FOREIGN CSV cells. Unlike Money.parseCents
//  (which naively maps "," → "." and corrupts grouped numbers), the import
//  tokenizer identifies the decimal separator by position and treats every other
//  "," / "." / space / NBSP as grouping. A Mint "1,234.56" and an EU "1.234,56"
//  must BOTH yield 123456. Sign is reported separately (leading "-" or the
//  accountant's "(12.34)" parenthesised negative) so the combiner can apply it.
//

import XCTest
@testable import FinanceTracker

final class CSVImportAmountTests: XCTestCase {

    // MARK: - US / period-decimal shapes

    func testPeriodDecimalWithCommaGrouping() {
        // Mint: comma groups thousands, period is the decimal.
        let r = ImportAmount.parse("1,234.56", decimal: .period)
        XCTAssertEqual(r?.cents, 123456)
        XCTAssertEqual(r?.isNegative, false)
    }

    func testCurrencySymbolStripped() {
        XCTAssertEqual(ImportAmount.parse("$1,342.15", decimal: .period)?.cents, 134215)
    }

    // MARK: - EU / comma-decimal shapes

    func testCommaDecimalWithPeriodGrouping() {
        // EU: period groups thousands, comma is the decimal.
        let r = ImportAmount.parse("1.234,56", decimal: .comma)
        XCTAssertEqual(r?.cents, 123456)
        XCTAssertEqual(r?.isNegative, false)
    }

    func testSpaceGroupingCommaDecimal() {
        // "10 143,15" (regular + NBSP grouping space) → 1014315
        XCTAssertEqual(ImportAmount.parse("10 143,15", decimal: .comma)?.cents, 1014315)
        XCTAssertEqual(ImportAmount.parse("10\u{00a0}143,15", decimal: .comma)?.cents, 1014315)
    }

    // MARK: - Position beats style when BOTH separators are present

    func testBothSeparatorsResolveByPositionRegardlessOfStyle() {
        // Even told the wrong style, "1,234.56" has the period last → period decimal.
        XCTAssertEqual(ImportAmount.parse("1,234.56", decimal: .comma)?.cents, 123456)
        XCTAssertEqual(ImportAmount.parse("1.234,56", decimal: .period)?.cents, 123456)
    }

    // MARK: - The genuinely ambiguous lone-separator + 3 digits case

    func testAmbiguousThreeDigitsResolvedByStyle() {
        // "1.234": one period, 3 digits after → could be 1.234 or 1234. Style decides.
        XCTAssertEqual(ImportAmount.parse("1.234", decimal: .comma)?.cents, 123400)  // period = grouping
        XCTAssertEqual(ImportAmount.parse("1.234", decimal: .period)?.cents, 123)     // period = decimal (capped 2dp)
    }

    // MARK: - Sign detection

    func testLeadingMinusIsNegative() {
        let r = ImportAmount.parse("-12.34", decimal: .period)
        XCTAssertEqual(r?.cents, 1234)
        XCTAssertEqual(r?.isNegative, true)
    }

    func testParenthesisedIsNegative() {
        let r = ImportAmount.parse("(12.34)", decimal: .period)
        XCTAssertEqual(r?.cents, 1234)
        XCTAssertEqual(r?.isNegative, true)
    }

    func testPlainPositive() {
        let r = ImportAmount.parse("12.34", decimal: .period)
        XCTAssertEqual(r?.cents, 1234)
        XCTAssertEqual(r?.isNegative, false)
    }

    // MARK: - Integers and edge cases

    func testPlainInteger() {
        XCTAssertEqual(ImportAmount.parse("1000", decimal: .period)?.cents, 100000)
    }

    func testCommaLeadingDecimal() {
        XCTAssertEqual(ImportAmount.parse(",15", decimal: .comma)?.cents, 15)
    }

    func testNonNumericIsNil() {
        XCTAssertNil(ImportAmount.parse("abc", decimal: .period))
    }

    func testEmptyIsNil() {
        XCTAssertNil(ImportAmount.parse("", decimal: .period))
        XCTAssertNil(ImportAmount.parse("   ", decimal: .period))
    }

    // MARK: - CSV strictness: a lone separator inconsistent with the declared
    // convention is rejected (→ nil → failedRows), never silently coerced.

    func testRejectsInconsistentGroupingCount() {
        XCTAssertNil(ImportAmount.parse("1,2345", decimal: .period), "comma grouping needs exactly 3 digits")
        XCTAssertNil(ImportAmount.parse("1,23", decimal: .period), "2-digit comma group is malformed here")
    }

    func testAcceptsValidGroupAndRoundsDecimal() {
        XCTAssertEqual(ImportAmount.parse("1,234", decimal: .period)?.cents, 123400)  // valid group
        XCTAssertEqual(ImportAmount.parse("1.235", decimal: .period)?.cents, 124)     // decimal, rounds half-up
        XCTAssertEqual(ImportAmount.parse("1,234.56", decimal: .period)?.cents, 123456) // both present
    }
}
