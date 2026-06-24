//
//  TransactionModelTests.swift
//  FinanceTrackerTests
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class TransactionModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeTransaction(typeRaw: String = "expense", amountCents: Int = 500) -> Transaction {
        let cat = Category(name: "Test", kindRaw: "expense", icon: "circle", order: 1)
        context.insert(cat)
        let tx = Transaction(typeRaw: typeRaw, amountCents: amountCents, date: Date(), category: cat)
        context.insert(tx)
        return tx
    }

    // MARK: - Tests

    func testIsIncome_true_when_type_income() {
        let tx = makeTransaction(typeRaw: "income")
        XCTAssertTrue(tx.isIncome)
        XCTAssertFalse(tx.isExpense)
    }

    func testIsExpense_true_when_type_expense() {
        let tx = makeTransaction(typeRaw: "expense")
        XCTAssertTrue(tx.isExpense)
        XCTAssertFalse(tx.isIncome)
    }

    func testSignedAmountCents_income_positive() {
        let tx = makeTransaction(typeRaw: "income", amountCents: 1_000)
        XCTAssertEqual(tx.signedAmountCents, 1_000)
    }

    func testSignedAmountCents_expense_negative() {
        let tx = makeTransaction(typeRaw: "expense", amountCents: 1_000)
        XCTAssertEqual(tx.signedAmountCents, -1_000)
    }

    func testType_setter_updates_typeRaw() {
        let tx = makeTransaction(typeRaw: "expense")
        tx.type = .income
        XCTAssertEqual(tx.typeRaw, "income")
    }
}
