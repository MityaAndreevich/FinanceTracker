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

    // MARK: - Single-separator + N-digit table (locked characterization)
    //
    // A lone separator can be grouping OR a decimal. The resolution rule: within a
    // consistent file, grouping uses the OTHER character than the declared decimal,
    // so a lone separator that MATCHES the declared decimal is a decimal, and one
    // that does NOT is grouping. This is why the two hints mirror each other and
    // why grouped thousands parse correctly under the RIGHT hint:
    //   "1,234" is 1234 in a period-decimal file (comma = grouping) and 1.234 in a
    //   comma-decimal file (comma = decimal). Both are correct for their file.
    // This is NOT the old Money bug: that force-replaced ','→'.' and destroyed the
    // convention, corrupting EVERY grouped number regardless of format. Here the
    // convention is honoured. No preset selects comma-decimal, so the comma-hint
    // column is only ever reached when the user explicitly declares it.
    func testSingleSeparatorTable() {
        //                    input                   hint "."      hint ","
        assertParse("1,234",           period: 123400,     comma: 123)         // comma+3: grouping / decimal(1.23)
        assertParse("1.234",           period: 123,        comma: 123400)      // period+3: decimal(1.23) / grouping
        assertParse("1,23",            period: 123,        comma: 123)         // 2-digit fraction: decimal either way
        assertParse("1.2345",          period: 123,        comma: 123)         // 4+ digits: decimal, fraction capped
        assertParse("1,2345",          period: 123,        comma: 123)
        assertParse("12,345,678.90",   period: 1234567890, comma: 1234567890)  // both present → position wins
        assertParse("12.345.678,90",   period: 1234567890, comma: 1234567890)
    }

    private func assertParse(_ input: String, period: Int?, comma: Int?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(AmountParsing.parseCents(input, decimalSeparator: "."), period, "\(input) with '.'", file: file, line: line)
        XCTAssertEqual(AmountParsing.parseCents(input, decimalSeparator: ","), comma, "\(input) with ','", file: file, line: line)
    }
}
