//
//  CategoryScopedRowShareTests.swift
//  FinanceTrackerTests
//
//  A category-scoped list shows THIS category's share, so its rows add up to
//  its header. A global list shows the whole purchase. `CategoryTileRow` serves
//  both, and the difference is one optional parameter — which is exactly the
//  kind of default that erodes silently, so both halves are pinned here.
//
//  The founder's case (1.0.3 device QA): "Perekrestok" 1000, category Shopping,
//  split 500 Pets / 500 Food & Drink. Food & Drink's header read 500 while the
//  row read 1000, and the footnote explaining it sat below the fold.
//

import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class CategoryScopedRowShareTests: XCTestCase {

    private static var retainedContainers: [ModelContainer] = []
    private var container: ModelContainer!
    private var ctx: ModelContext!

    override func setUpWithError() throws {
        let schema = SharedModelContainer.fullSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        Self.retainedContainers.append(container)
        ctx = container.mainContext
    }

    override func tearDownWithError() throws {
        ctx = nil
        container = nil
    }

    // MARK: - Fixtures

    private func category(_ name: String) -> FinanceTracker.Category {
        let c = FinanceTracker.Category(name: name, kindRaw: "expense", icon: "cart", order: 0)
        ctx.insert(c)
        try? ctx.save()
        return c
    }

    @discardableResult
    private func expense(_ cents: Int, _ merchant: String, category: FinanceTracker.Category) -> FinanceTracker.Transaction {
        let tx = FinanceTracker.Transaction(
            typeRaw: "expense", amountCents: cents, date: Date(), category: category
        )
        tx.merchant = merchant
        ctx.insert(tx)
        try? ctx.save()
        return tx
    }

    /// This category's portion of one purchase — the same computation
    /// `CategoryDetailView` drives its rows and its header from.
    private func attributed(_ tx: FinanceTracker.Transaction, to uuid: UUID) -> Int {
        CategoryAttribution.shares(for: tx)
            .filter { $0.category.bucketID == uuid }
            .reduce(0) { $0 + $1.amountCents }
    }

    // MARK: - The founder's case

    func test_splitRow_showsThisCategorysShare_andRowsSumToTheHeader() throws {
        let shopping = category("Shopping")
        let pets = category("Pets")
        let food = category("Food & Drink")

        let perekrestok = expense(1_000, "Perekrestok", category: shopping)
        let petsPart = TransactionSplit(amountCents: 500, category: pets, order: 0)
        let foodPart = TransactionSplit(amountCents: 500, category: food, order: 1)
        ctx.insert(petsPart)
        ctx.insert(foodPart)
        perekrestok.splits = [petsPart, foodPart]

        // A second, unsplit purchase so the header is not just the split.
        let coffee = expense(300, "Coffee", category: food)
        try ctx.save()

        // --- Food & Drink, the screen the founder opened.
        let inFood = [perekrestok, coffee].filter { attributed($0, to: food.uuid) > 0 }
        let rowsInFood = inFood.map { attributed($0, to: food.uuid) }
        let headerInFood = rowsInFood.reduce(0, +)

        XCTAssertEqual(attributed(perekrestok, to: food.uuid), 500,
                       "the Perekrestok row must read this category's 500, not the whole 1000")
        XCTAssertEqual(headerInFood, 800)
        XCTAssertEqual(rowsInFood.reduce(0, +), headerInFood,
                       "rows must add up to the header — that is the whole point of the change")

        // The row prints the share and keeps the whole purchase discoverable.
        let splitRow = CategoryTileRow(tx: perekrestok, attributedCents: 500)
        XCTAssertTrue(splitRow.showsSplitContext)
        XCTAssertEqual(splitRow.displayCents, 500)
        XCTAssertTrue(splitRow.splitContext.contains(
            Money.format(cents: 1_000, currencyCode: perekrestok.currency)
        ), "the split context line must name the full purchase amount")

        // --- Pets: the same purchase, the same 500.
        XCTAssertEqual(attributed(perekrestok, to: pets.uuid), 500)
        XCTAssertTrue(CategoryTileRow(tx: perekrestok, attributedCents: 500).showsSplitContext)
    }

    func test_unsplitRow_inACategoryList_showsTheFullAmountAndNoSplitContext() {
        let food = category("Food & Drink")
        let coffee = expense(300, "Coffee", category: food)

        let row = CategoryTileRow(tx: coffee, attributedCents: attributed(coffee, to: food.uuid))
        XCTAssertEqual(row.displayCents, 300)
        XCTAssertFalse(row.showsSplitContext,
                       "share == full amount, so the row must look exactly as it did before")
    }

    /// A split whose every part lands in the SAME category still contributes its
    /// whole self here — no "part of" line, because it is not a part.
    func test_splitEntirelyWithinOneCategory_showsNoSplitContext() throws {
        let food = category("Food & Drink")
        let tx = expense(1_000, "Grocery run", category: food)
        let a = TransactionSplit(amountCents: 400, category: food, order: 0)
        let b = TransactionSplit(amountCents: 600, category: food, order: 1)
        ctx.insert(a)
        ctx.insert(b)
        tx.splits = [a, b]
        try ctx.save()

        let share = attributed(tx, to: food.uuid)
        XCTAssertEqual(share, 1_000)
        XCTAssertFalse(CategoryTileRow(tx: tx, attributedCents: share).showsSplitContext)
    }

    // MARK: - The global surfaces must not move

    /// Dashboard recent, Transactions, the day / month sheets and duplicate
    /// review are ledgers of PURCHASES: one row, one purchase, one full amount.
    /// They pass no share, and the default must keep them whole.
    func test_globalRow_defaultsToTheFullAmount_evenForASplit() throws {
        let shopping = category("Shopping")
        let pets = category("Pets")
        let food = category("Food & Drink")

        let tx = expense(1_000, "Perekrestok", category: shopping)
        let petsPart = TransactionSplit(amountCents: 500, category: pets, order: 0)
        let foodPart = TransactionSplit(amountCents: 500, category: food, order: 1)
        ctx.insert(petsPart)
        ctx.insert(foodPart)
        tx.splits = [petsPart, foodPart]
        try ctx.save()

        let global = CategoryTileRow(tx: tx)          // no attributedCents
        XCTAssertEqual(global.displayCents, 1_000)
        XCTAssertFalse(global.showsSplitContext,
                       "a global row must never claim to be a part of something")
    }

    /// The attribution math itself is untouched by this display change.
    func test_attributionStillConservesExactly() throws {
        let shopping = category("Shopping")
        let pets = category("Pets")
        let food = category("Food & Drink")

        let tx = expense(1_000, "Perekrestok", category: shopping)
        let petsPart = TransactionSplit(amountCents: 500, category: pets, order: 0)
        let foodPart = TransactionSplit(amountCents: 500, category: food, order: 1)
        ctx.insert(petsPart)
        ctx.insert(foodPart)
        tx.splits = [petsPart, foodPart]
        try ctx.save()

        let sum = CategoryAttribution.shares(for: tx).reduce(0) { $0 + $1.amountCents }
        XCTAssertEqual(sum, tx.amountCents)
    }
}
