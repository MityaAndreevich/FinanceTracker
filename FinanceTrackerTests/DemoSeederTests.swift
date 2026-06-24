//
//  DemoSeederTests.swift
//  FinanceTrackerTests
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class DemoSeederTests: XCTestCase {

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

    // MARK: - Tests

    func testResetAndSeed_clears_existing_data() throws {
        let dummy = Category(name: "DUMMY_TEST", kindRaw: "expense", icon: "circle", order: 999)
        context.insert(dummy)
        let tx = Transaction(typeRaw: "expense", amountCents: 1, date: Date(), category: dummy)
        tx.merchant = "SHOULD_BE_GONE"
        context.insert(tx)
        try context.save()

        DemoSeeder.resetAndSeedDemoData(modelContext: context)

        let cats = try context.fetch(FetchDescriptor<FinanceTracker.Category>())
        XCTAssertFalse(cats.contains { $0.name == "DUMMY_TEST" }, "Dummy category survived wipeAll")

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertFalse(txs.contains { $0.merchant == "SHOULD_BE_GONE" }, "Pre-existing transaction survived wipeAll")
    }

    func testSeed_creates_11_categories() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let cats = try context.fetch(FetchDescriptor<FinanceTracker.Category>())
        XCTAssertEqual(cats.count, 11)
    }

    func testSeed_creates_3_sources() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let sources = try context.fetch(FetchDescriptor<Source>())
        XCTAssertEqual(sources.count, 3)
        let names = Set(sources.map { $0.name })
        XCTAssertEqual(names, ["Checking", "Credit Card", "Cash"])
    }

    func testSeed_creates_anomaly_transaction() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let anomalies = txs.filter { tx in
            tx.isExpense &&
            tx.category.nameKey == "category.food" &&
            tx.date >= sevenDaysAgo &&
            tx.amountCents > 10_000
        }
        XCTAssertFalse(anomalies.isEmpty, "Expected a Food anomaly > $100 in the last 7 days")
    }

    func testSeed_no_affluence_amounts() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        let nonRentExpenses = txs.filter { $0.isExpense && $0.category.nameKey != "category.rent" }
        for tx in nonRentExpenses {
            XCTAssertLessThanOrEqual(
                tx.amountCents, 20_000,
                "Expense \(tx.amountCents)¢ exceeds $200 (category: \(tx.category.name), merchant: \(tx.merchant ?? "-"))"
            )
        }
    }

    func testSeed_idempotent() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let cats1 = try context.fetch(FetchDescriptor<FinanceTracker.Category>()).count
        let srcs1 = try context.fetch(FetchDescriptor<Source>()).count
        let txs1  = try context.fetch(FetchDescriptor<Transaction>()).count

        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let cats2 = try context.fetch(FetchDescriptor<FinanceTracker.Category>()).count
        let srcs2 = try context.fetch(FetchDescriptor<Source>()).count
        let txs2  = try context.fetch(FetchDescriptor<Transaction>()).count

        XCTAssertEqual(cats1, cats2, "Category count changed on second seed")
        XCTAssertEqual(srcs1, srcs2, "Source count changed on second seed")
        XCTAssertEqual(txs1,  txs2,  "Transaction count changed on second seed")
    }
}
