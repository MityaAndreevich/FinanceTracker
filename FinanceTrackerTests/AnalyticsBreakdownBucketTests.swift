//
//  AnalyticsBreakdownBucketTests.swift
//  FinanceTrackerTests
//
//  Locks the donut segment cap (Item 4): the Breakdown donut shows at most a
//  handful of named category slices plus a single aggregated "Other" bucket, so
//  a long tail of tiny categories can't shatter the ring into unreadable slivers.
//  The partition logic is a pure function so it's tested without a chart or a
//  locale — the view only supplies the localized "Other" label + neutral color.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

final class AnalyticsBreakdownBucketTests: XCTestCase {

    private typealias Total = AnalyticsBreakdownView.CategoryTotal

    /// Descending-sorted fixtures (the function assumes its input is pre-sorted,
    /// mirroring `sortedCategories`).
    private func makeSorted(_ cents: [Int]) -> [Total] {
        cents.enumerated().map { idx, c in
            Total(id: UUID(), name: "cat\(idx)", symbol: "circle",
                  cents: c, isIncome: false, color: .gray)
        }
    }

    // MARK: - No bucketing needed

    func test_atOrBelowCap_passesThroughUnchanged() {
        let five = makeSorted([500, 400, 300, 200, 100])
        let out = AnalyticsBreakdownView.displaySlices(
            from: five, otherName: "Other", otherColor: .gray)
        XCTAssertEqual(out.map(\.cents), [500, 400, 300, 200, 100])
        XCTAssertFalse(out.contains { $0.id == AnalyticsBreakdownView.otherBucketID })
    }

    /// Exactly six real categories is better shown as six named slices than as
    /// five + a one-category "Other" (which would hide a real category behind a
    /// vague label). So six passes through untouched.
    func test_sixCategories_notBucketedIntoSinglemberOther() {
        let six = makeSorted([600, 500, 400, 300, 200, 100])
        let out = AnalyticsBreakdownView.displaySlices(
            from: six, otherName: "Other", otherColor: .gray)
        XCTAssertEqual(out.count, 6)
        XCTAssertFalse(out.contains { $0.id == AnalyticsBreakdownView.otherBucketID })
    }

    // MARK: - Bucketing

    func test_longTail_collapsesToTopFivePlusOther() {
        // 8 categories → top 5 named + Other aggregating ranks 6..8 (60+40+20).
        let eight = makeSorted([800, 700, 600, 500, 400, 60, 40, 20])
        let out = AnalyticsBreakdownView.displaySlices(
            from: eight, otherName: "Other", otherColor: .gray)

        XCTAssertEqual(out.count, 6, "5 named + 1 Other")
        XCTAssertEqual(out.prefix(5).map(\.cents), [800, 700, 600, 500, 400],
                       "top 5 preserved in order")

        let other = out.last!
        XCTAssertEqual(other.id, AnalyticsBreakdownView.otherBucketID)
        XCTAssertEqual(other.name, "Other")
        XCTAssertEqual(other.cents, 120, "Other sums the remaining tail")
    }

    func test_other_inheritsDirection_ofTheSet() {
        let income = [800, 700, 600, 500, 400, 100, 50].enumerated().map { idx, c in
            Total(id: UUID(), name: "inc\(idx)", symbol: "circle",
                  cents: c, isIncome: true, color: .gray)
        }
        let out = AnalyticsBreakdownView.displaySlices(
            from: income, otherName: "Other", otherColor: .gray)
        XCTAssertTrue(out.last?.isIncome == true,
                      "Other must match the income/expense direction it aggregates")
    }

    func test_empty_returnsEmpty() {
        let out = AnalyticsBreakdownView.displaySlices(
            from: [], otherName: "Other", otherColor: .gray)
        XCTAssertTrue(out.isEmpty)
    }
}
