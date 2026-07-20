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

    func testSeed_creates_13_categories() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let cats = try context.fetch(FetchDescriptor<FinanceTracker.Category>())
        // 6 primary expense + 1 primary income + 6 secondary expense = 13
        XCTAssertEqual(cats.count, 13)
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

        // The demo intentionally seeds ONE Food & Drink spending anomaly — a grocery
        // run ~30% above the normal food spend (DemoSeeder header). We assert that
        // outlier *structurally* (largest food expense stands well above the median),
        // NOT via an absolute dollar threshold or a "last 7 days" window:
        //   • The "no displays of affluence" rule deliberately keeps amounts modest
        //     ($93, not $487), so the old hardcoded > $100 check is stale by design.
        //   • Dates are dayOfMonth-anchored and clamped to `now`, so a real-clock
        //     "last 7 days" filter is fragile (most rows collapse onto today early in
        //     the month). The anomaly's defining trait is the amount, not the date.
        let foodExpenses = txs
            .filter { $0.isExpense && $0.category?.nameKey == "category.food_drink" }
            .map(\.amountCents)
            .sorted()
        XCTAssertFalse(foodExpenses.isEmpty, "Demo seed must include Food & Drink expenses")

        let maxFood = foodExpenses.last!
        let median = foodExpenses[foodExpenses.count / 2]
        XCTAssertGreaterThanOrEqual(
            Double(maxFood), Double(median) * 1.3,
            "Expected a Food & Drink anomaly ≥30% above the median food spend "
                + "(got max \(maxFood)¢ vs median \(median)¢)"
        )
    }

    func testSeed_no_affluence_amounts() throws {
        DemoSeeder.resetAndSeedDemoData(modelContext: context)
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        // Housing (rent) is allowed to exceed $200 — all others should not
        let nonHousingExpenses = txs.filter {
            $0.isExpense && $0.category?.nameKey != "category.housing"
        }
        for tx in nonHousingExpenses {
            XCTAssertLessThanOrEqual(
                tx.amountCents, 20_000,
                "Expense \(tx.amountCents)¢ exceeds $200 (category: \(tx.category?.name ?? "nil"), merchant: \(tx.merchant ?? "-"))"
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
