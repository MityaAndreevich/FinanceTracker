//
//  TransactionSearchTests.swift
//  FinanceTrackerTests
//
//  Locks the Transactions search semantics (device QA round 2 #3). The headline
//  case: the stale device query "Футболка 550" must match the "Футболка" row
//  when that purchase was 550 — the old whole-string substring match returned
//  nothing here, which read as data loss.
//

import XCTest
@testable import FinanceTracker

final class TransactionSearchTests: XCTestCase {

    private func matches(_ q: String, merchant: String? = nil, category: String? = nil,
                         source: String? = nil, note: String? = nil, amountCents: Int = 0) -> Bool {
        TransactionSearch.matches(
            query: q,
            fields: [merchant, category, source, note],
            amountCents: amountCents
        )
    }

    func test_empty_query_matches_everything() {
        XCTAssertTrue(matches("", merchant: "Anything"))
        XCTAssertTrue(matches("   ", merchant: "Anything"))
    }

    func test_matches_merchant_substring() {
        XCTAssertTrue(matches("Футб", merchant: "Футболка"))
    }

    func test_case_insensitive() {
        XCTAssertTrue(matches("футболка", merchant: "Футболка"))
    }

    func test_diacritic_insensitive() {
        XCTAssertTrue(matches("Cafe", merchant: "Café"))
        XCTAssertTrue(matches("senor", merchant: "Señor Tacos"))
    }

    // Headline regression: name + amount token, previously matched nothing.
    func test_name_plus_amount_token_matches_that_purchase() {
        XCTAssertTrue(matches("Футболка 550", merchant: "Футболка", amountCents: 55000))
    }

    func test_amount_alone_matches_by_major_unit() {
        XCTAssertTrue(matches("550", merchant: "Футболка", amountCents: 55000))
    }

    // AND across tokens: a token that matches nothing excludes the row.
    func test_nonmatching_token_excludes_row() {
        XCTAssertFalse(matches("Футболка 999", merchant: "Футболка", amountCents: 55000))
    }

    func test_matches_category_source_and_note() {
        XCTAssertTrue(matches("groceries", category: "Groceries"))
        XCTAssertTrue(matches("cash", source: "Cash"))
        XCTAssertTrue(matches("birthday", note: "Birthday gift"))
    }

    func test_no_match_returns_false() {
        XCTAssertFalse(matches("xyz", merchant: "Футболка", amountCents: 55000))
    }
}
