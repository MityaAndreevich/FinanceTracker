//
//  CSVImportDateTests.swift
//  FinanceTrackerTests
//
//  Foreign CSVs carry dates in mutually-incompatible orders. "03/04/2026" is
//  March 4 in a US file and April 3 in an EU file — guessing wrong silently
//  misdates a transaction. So the order is DECLARED by the preset; `.auto` only
//  infers when a component >12 makes it unambiguous, and otherwise falls back to
//  the US default (our foreign presets — Mint/YNAB/Monarch — are US-formatted).
//

import XCTest
@testable import FinanceTracker

final class CSVImportDateTests: XCTestCase {

    /// UTC midnight for the given y/m/d — the importer stores dates in UTC (matching
    /// the existing ISO-8601 export/import), so parsed foreign dates must land there too.
    private func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testISO() {
        XCTAssertEqual(ImportDate.parse("2026-01-20", order: .iso), utc(2026, 1, 20))
    }

    func testISOParsedEvenWhenOrderSaysSlash() {
        // An unambiguous ISO value is accepted regardless of declared order.
        XCTAssertEqual(ImportDate.parse("2026-01-20", order: .mdy), utc(2026, 1, 20))
    }

    func testUSSlash() {
        XCTAssertEqual(ImportDate.parse("01/20/2026", order: .mdy), utc(2026, 1, 20))
    }

    func testEUSlash() {
        XCTAssertEqual(ImportDate.parse("20/01/2026", order: .dmy), utc(2026, 1, 20))
    }

    func testEUDot() {
        XCTAssertEqual(ImportDate.parse("20.01.2026", order: .dmy), utc(2026, 1, 20))
    }

    func testAmbiguousRespectsDeclaredOrder() {
        // Both components ≤12: the declared order is authoritative, no guessing.
        XCTAssertEqual(ImportDate.parse("03/04/2026", order: .mdy), utc(2026, 3, 4))
        XCTAssertEqual(ImportDate.parse("03/04/2026", order: .dmy), utc(2026, 4, 3))
    }

    func testAutoInfersFromDayOverTwelve() {
        // "13/04" → 13 can only be the day → DMY.
        XCTAssertEqual(ImportDate.parse("13/04/2026", order: .auto), utc(2026, 4, 13))
        // "04/13" → 13 can only be the day → MDY.
        XCTAssertEqual(ImportDate.parse("04/13/2026", order: .auto), utc(2026, 4, 13))
    }

    func testAutoFallsBackToUS() {
        // Both ≤12, no signal → US default (MDY).
        XCTAssertEqual(ImportDate.parse("03/04/2026", order: .auto), utc(2026, 3, 4))
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(ImportDate.parse("notadate", order: .mdy))
        XCTAssertNil(ImportDate.parse("2026-13-01", order: .iso))     // month 13
        XCTAssertNil(ImportDate.parse("31/02/2026", order: .dmy))     // Feb 31
        XCTAssertNil(ImportDate.parse("", order: .mdy))
    }

    // MARK: - Column-level order detection (surfaced in the preview)

    func testDetectOrderFromColumnWithDayOverTwelve() {
        // A column containing "13/04/2026" can only be DMY.
        XCTAssertEqual(ImportDate.detectOrder(samples: ["03/04/2026", "13/04/2026", "01/02/2026"]), .dmy)
    }

    func testDetectOrderDefaultsToMDYWhenAllAmbiguous() {
        XCTAssertEqual(ImportDate.detectOrder(samples: ["03/04/2026", "01/02/2026"]), .mdy)
    }

    func testDetectOrderISO() {
        XCTAssertEqual(ImportDate.detectOrder(samples: ["2026-03-04", "2026-01-02"]), .iso)
    }
}
