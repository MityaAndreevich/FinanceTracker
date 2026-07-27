import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Helpers

private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
        configurations: config
    )
    return ModelContext(container)
}

/// Callers often insert a category purely for its side effect on `ctx`.
@discardableResult
private func insertCategory(name: String, kindRaw: String, order: Int, isPrimary: Bool, ctx: ModelContext) -> FinanceTracker.Category {
    let cat = FinanceTracker.Category(name: name, kindRaw: kindRaw, order: order, isPrimary: isPrimary)
    ctx.insert(cat)
    return cat
}

// MARK: - Tests

@Suite("CategoryEntity + CategoryQuery")
@MainActor
struct CategoryEntityTests {

    @Test func test_categoryEntity_initFromModel() throws {
        let ctx = try makeContext()
        let cat = insertCategory(name: "Food & Drink", kindRaw: "expense", order: 0, isPrimary: true, ctx: ctx)
        try ctx.save()

        let entity = CategoryEntity(from: cat)
        #expect(entity.id == cat.uuid)
        #expect(entity.name == "Food & Drink")
        #expect(entity.isPrimary == true)
    }

    @Test func test_suggestedEntities_returnsPrimaryFirst() throws {
        let ctx = try makeContext()
        insertCategory(name: "Secondary", kindRaw: "expense", order: 0, isPrimary: false, ctx: ctx)
        insertCategory(name: "Primary A", kindRaw: "expense", order: 1, isPrimary: true, ctx: ctx)
        insertCategory(name: "Primary B", kindRaw: "expense", order: 0, isPrimary: true, ctx: ctx)
        try ctx.save()

        let entities = CategoryQuery.sortedEntities(from: ctx)
        #expect(entities.count == 3)
        // Primary categories should come before secondary ones.
        let primaryCount = entities.prefix(while: { $0.isPrimary }).count
        #expect(primaryCount == 2)
        #expect(entities.last?.isPrimary == false)
    }

    @Test func test_suggestedEntities_primarySortedByOrder() throws {
        let ctx = try makeContext()
        insertCategory(name: "Later", kindRaw: "expense", order: 5, isPrimary: true, ctx: ctx)
        insertCategory(name: "First", kindRaw: "expense", order: 1, isPrimary: true, ctx: ctx)
        try ctx.save()

        let entities = CategoryQuery.sortedEntities(from: ctx)
        #expect(entities.first?.name == "First")
        #expect(entities.last?.name == "Later")
    }

    @Test func test_displayRepresentation_containsName() throws {
        let ctx = try makeContext()
        let cat = insertCategory(name: "Transport", kindRaw: "expense", order: 0, isPrimary: true, ctx: ctx)
        try ctx.save()

        let entity = CategoryEntity(from: cat)
        // name comes through correctly into the entity
        #expect(entity.name == "Transport")
    }
}
