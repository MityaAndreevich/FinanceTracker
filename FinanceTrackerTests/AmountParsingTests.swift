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

    // MARK: - Separator-consistency gate (CSV-only strictness)
    //
    // The core parseCents stays lenient (QuickAdd shows the field, a guess is
    // recoverable). CSV import must NOT guess: this predicate flags a lone
    // separator whose digit count can't match the declared convention, so the
    // mapper can route the row to failedRows instead of silently coercing it.
    func testConsistencyGate() {
        // Grouping char (the non-decimal one) is only valid as an exact 3-digit group.
        XCTAssertFalse(AmountParsing.hasConsistentSeparators("1,2345", decimalSeparator: "."))  // 4 digits
        XCTAssertFalse(AmountParsing.hasConsistentSeparators("1,23", decimalSeparator: "."))    // 2 digits
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1,234", decimalSeparator: "."))    // valid group
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1,234,567", decimalSeparator: ".")) // repeated → grouping
        // Decimal char is always fine (1–2 normal, 3+ rounds).
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1.235", decimalSeparator: "."))
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1.23", decimalSeparator: "."))
        // Both present → unambiguous by position; integers → nothing to check.
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1,234.56", decimalSeparator: "."))
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1234", decimalSeparator: "."))
        // Mirror under comma convention.
        XCTAssertTrue(AmountParsing.hasConsistentSeparators("1.234", decimalSeparator: ","))    // period grouping, 3 digits
        XCTAssertFalse(AmountParsing.hasConsistentSeparators("1.2345", decimalSeparator: ","))  // period grouping, 4 digits

        // The gate is advisory only — the CORE stays lenient (QuickAdd path).
        XCTAssertEqual(AmountParsing.parseCents("1,2345", decimalSeparator: "."), 123)
    }

    // MARK: - Rounding (a >2-decimal value must round half-up, not truncate down)
    //
    // Truncation biased every foreign amount with a 3rd decimal ≥5 down by up to a
    // cent — systematic, silent, in a finance app. Half-up fixes it. The comma-hint
    // column here reads the period as grouping (3 digits) so it's an integer group,
    // unaffected by rounding.
    func testRoundsHalfUpNotTruncate() {
        assertParse("1.235", period: 124, comma: 123500)   // 1.235 → 1.24, not 1.23
        assertParse("1.999", period: 200, comma: 199900)   // carries into the integer part
        assertParse("0.005", period: 1,   comma: 500)      // 0.005 → 0.01, not 0.00
        assertParse("2.675", period: 268, comma: 267500)   // 2.675 → 2.68 (string-exact, no float)
        assertParse("1.2345", period: 123, comma: 123)     // 3rd digit 4 → stays 1.23 (4 digits → decimal both hints)
    }
}
