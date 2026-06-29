//
//  DemoDataControllerTests.swift
//  FinanceTrackerTests
//

import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class DemoDataControllerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        // Reset state before each test
        UserDefaults.standard.removeObject(forKey: "hasDemoDataActive")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "hasDemoDataActive")
        container = nil
        context = nil
    }

    // MARK: - isDemoDataActive

    func test_isDemoDataActive_defaultsFalse() {
        XCTAssertFalse(DemoDataController.isDemoDataActive)
    }

    func test_isDemoDataActive_reflectsStoredValue() {
        DemoDataController.isDemoDataActive = true
        XCTAssertTrue(DemoDataController.isDemoDataActive)

        DemoDataController.isDemoDataActive = false
        XCTAssertFalse(DemoDataController.isDemoDataActive)
    }

    // MARK: - clearDemoData

    func test_clearDemoData_removesOnlyDemoFlaggedTransactions() throws {
        // Seed one category so we can create transactions
        let cat = Category(name: "Test", kindRaw: "expense", icon: "circle", order: 1)
        context.insert(cat)

        // Real user transaction
        let userTx = Transaction(
            typeRaw: "expense", amountCents: 1000, currency: "USD",
            date: .now, category: cat, isDemo: false
        )
        context.insert(userTx)

        // Demo transaction
        let demoTx = Transaction(
            typeRaw: "expense", amountCents: 500, currency: "USD",
            date: .now, category: cat, isDemo: true
        )
        context.insert(demoTx)
        try context.save()

        DemoDataController.isDemoDataActive = true
        DemoDataController.clearDemoData(modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(remaining.count, 1, "Only 1 real transaction should remain")
        XCTAssertFalse(remaining.first?.isDemo ?? true, "Remaining transaction should not be demo")
        XCTAssertFalse(DemoDataController.isDemoDataActive)
    }

    func test_clearDemoData_setsIsDemoDataActiveFalse() throws {
        DemoDataController.isDemoDataActive = true
        DemoDataController.clearDemoData(modelContext: context)
        XCTAssertFalse(DemoDataController.isDemoDataActive)
    }

    // MARK: - Fresh install stays empty (Bug 11)

    /// A fresh database must seed default *categories* but never any transactions —
    /// a clean install shows $0 totals and no demo amounts until the user adds data.
    func test_freshDatabase_seedsCategoriesButNoTransactions() throws {
        SeedService.seedIfNeeded(modelContext: context)

        let categories = try context.fetch(FetchDescriptor<FinanceTracker.Category>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertFalse(categories.isEmpty, "Fresh install should seed default categories")
        XCTAssertEqual(transactions.count, 0, "Fresh install must have zero transactions (no demo leak)")
        XCTAssertFalse(DemoDataController.isDemoDataActive, "Demo must not be active on a fresh install")
    }

    // MARK: - isDemo field on Transaction

    func test_transaction_isDemo_defaultsFalse() throws {
        let cat = Category(name: "Test", kindRaw: "expense", icon: "circle", order: 1)
        context.insert(cat)
        let tx = Transaction(typeRaw: "expense", amountCents: 100, currency: "USD", date: .now, category: cat)
        XCTAssertFalse(tx.isDemo, "isDemo should default to false")
    }

    func test_transaction_isDemo_canBeSetTrue() throws {
        let cat = Category(name: "Test", kindRaw: "expense", icon: "circle", order: 1)
        context.insert(cat)
        let tx = Transaction(
            typeRaw: "expense", amountCents: 100, currency: "USD",
            date: .now, category: cat, isDemo: true
        )
        XCTAssertTrue(tx.isDemo)
    }
}
