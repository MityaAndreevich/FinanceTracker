//
//  AmountParsingTests.swift
//  FinanceTrackerTests
//
//  The single money-string → cents numeric core, shared by the QuickAdd NL
//  tokenizer, the CSV column mapper, and Money.parseCents. Callers differ only in
//  how they choose the decimal separator (user locale vs file format vs sanitized
//  field); the numeric parsing is one implementation so it cannot diverge — this
//  is where three prior/potential locale bugs lived.
//
//  Grouping is resolved POSITIONALLY: when both "," and "." appear, the later is
//  the decimal (so a mis-declared separator can't corrupt an unambiguous value);
//  a lone separator followed by exactly 3 digits is the one ambiguous case and is
//  broken by the declared decimalSeparator. Whitespace/NBSP are always grouping.
//

import XCTest
@testable import FinanceTracker

final class AmountParsingTests: XCTestCase {

    func testPeriodDecimalCommaGrouping() {
        XCTAssertEqual(AmountParsing.parseCents("1,234.56", decimalSeparator: "."), 123456)
    }

    func testCommaDecimalPeriodGrouping() {
        XCTAssertEqual(AmountParsing.parseCents("1.234,56", decimalSeparator: ","), 123456)
    }

    func testSpaceAndNBSPGrouping() {
        XCTAssertEqual(AmountParsing.parseCents("10 143,15", decimalSeparator: ","), 1014315)
        XCTAssertEqual(AmountParsing.parseCents("10\u{00a0}143,15", decimalSeparator: ","), 1014315)
    }

    func testCurrencySymbolStripped() {
        XCTAssertEqual(AmountParsing.parseCents("$1,342.15", decimalSeparator: "."), 134215)
    }

    func testLeadingDecimal() {
        XCTAssertEqual(AmountParsing.parseCents(",15", decimalSeparator: ","), 15)
        XCTAssertEqual(AmountParsing.parseCents(".15", decimalSeparator: "."), 15)
    }

    func testPlainInteger() {
        XCTAssertEqual(AmountParsing.parseCents("1234", decimalSeparator: "."), 123400)
        XCTAssertEqual(AmountParsing.parseCents("1000", decimalSeparator: "."), 100000)
    }

    // Position wins over a mis-declared separator when both symbols are present.
    func testPositionBeatsDeclaredSeparator() {
        XCTAssertEqual(AmountParsing.parseCents("1,234.56", decimalSeparator: ","), 123456)
        XCTAssertEqual(AmountParsing.parseCents("1.234,56", decimalSeparator: "."), 123456)
    }

    // The one genuinely ambiguous shape is resolved by the declared separator.
    func testAmbiguousThreeDigitsResolvedBySeparator() {
        XCTAssertEqual(AmountParsing.parseCents("1.234", decimalSeparator: "."), 123)     // period = decimal
        XCTAssertEqual(AmountParsing.parseCents("1.234", decimalSeparator: ","), 123400)  // period = grouping
    }

    func testGarbageIsNil() {
        XCTAssertNil(AmountParsing.parseCents("abc", decimalSeparator: "."))
        XCTAssertNil(AmountParsing.parseCents("", decimalSeparator: "."))
        XCTAssertNil(AmountParsing.parseCents("   ", decimalSeparator: "."))
    }
}
