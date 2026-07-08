//
//  CSVImportDecimalTests.swift
//  FinanceTrackerTests
//
//  Symmetric with the date-order handling: the decimal convention is detected
//  from the amount column's sample values, and reports `.ambiguous` (never a
//  silent period default) when the sample can't resolve it — so the mapping sheet
//  can force the user to confirm instead of failing every comma-decimal row.
//
//  Signal per value: both separators present → the later is the decimal; a lone
//  separator with a 3-digit group → grouping (the OTHER char is the decimal); a
//  lone separator with 1–2 digits → that char is the decimal.
//

import XCTest
@testable import FinanceTracker

final class CSVImportDecimalTests: XCTestCase {

    func testDetectsCommaDecimalEU() {
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1,23", "45,67", "1.234,56"]), .resolved(.comma))
    }

    func testDetectsPeriodDecimalUS() {
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1,234.56", "45.67", "1,000.00"]), .resolved(.period))
    }

    func testLoneThreeDigitGroupsImplyOtherIsDecimal() {
        // "1,234"/"5,678": comma can only be grouping here → decimal is period.
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1,234", "5,678"]), .resolved(.period))
    }

    func testLoneTwoDigitImpliesThatSeparatorIsDecimal() {
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1,23", "4,56"]), .resolved(.comma))
    }

    func testIntegersOnlyAreAmbiguous() {
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1234", "5678"]), .ambiguous)
    }

    func testConflictingSignalsAreAmbiguous() {
        // "1,23" votes comma-decimal, "1,234" votes comma-grouping (period decimal).
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: ["1,23", "1,234"]), .ambiguous)
    }

    func testEmptyIsAmbiguous() {
        XCTAssertEqual(ImportDecimal.classifyColumn(samples: []), .ambiguous)
    }
}
