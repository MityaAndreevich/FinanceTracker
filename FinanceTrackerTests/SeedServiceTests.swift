//
//  SeedServiceTests.swift
//  FinanceTrackerTests
//
//  Sprint B (Bug 3): the fallback category was rebranded from "Другое"/"Other"
//  to "Без категории"/"Uncategorized" with a questionmark.folder symbol. Its
//  stable English `name` ("Other") is intentionally unchanged — only the
//  localized label and icon move — so existing data and the save/suggest
//  matchers keep working. These tests pin that contract.
//

import Foundation
import SwiftData
import Testing
@testable import FinanceTracker

// Disambiguate from the C `Category` (OpaquePointer) that leaks into this test
// target's lookup once Foundation + SwiftData + Testing are all imported.
private typealias Category = FinanceTracker.Category

@Suite("SeedService — Uncategorized rebrand")
@MainActor
struct SeedServiceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func other(in context: ModelContext) throws -> Category? {
        try context.fetch(FetchDescriptor<Category>()).first { $0.nameKey == "category.other" }
    }

    @Test func testFreshSeed_otherUsesQuestionmarkFolderIcon() throws {
        let context = try makeContext()
        SeedService.seedIfNeeded(modelContext: context)

        let fallback = try #require(try other(in: context))
        #expect(fallback.name == "Other")                       // stable matcher kept
        #expect(fallback.icon == SeedService.uncategorizedIcon) // questionmark.folder
        #expect(fallback.icon == "questionmark.folder")
    }

    @Test func testMigration_existingOther_iconUpdated_dataIntact() throws {
        let context = try makeContext()
        // Simulate a pre-rebrand install: an "Other" category with the old icon
        // plus a transaction filed under it.
        let legacy = Category(
            name: "Other", kindRaw: "expense", icon: "square.grid.2x2",
            order: 6, nameKey: "category.other"
        )
        context.insert(legacy)
        let legacyUUID = legacy.uuid
        let tx = Transaction(
            typeRaw: "expense", amountCents: 500, currency: "USD", date: .now,
            category: legacy, source: nil, taxCents: nil, note: nil,
            merchant: "corner store", recurrenceRaw: nil
        )
        context.insert(tx)
        try context.save()

        SeedService.seedIfNeeded(modelContext: context)

        let fallback = try #require(try other(in: context))
        #expect(fallback.uuid == legacyUUID)                    // same row, not replaced
        #expect(fallback.icon == "questionmark.folder")         // icon migrated
        // The transaction still points at the (same) fallback category.
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        #expect(txs.count == 1)
        #expect(txs.first?.category.uuid == legacyUUID)
    }

    @Test func testMigration_userCustomizedOtherIcon_isPreserved() throws {
        let context = try makeContext()
        // A user who changed the Other icon to something of their own keeps it.
        let custom = Category(
            name: "Other", kindRaw: "expense", icon: "star.fill",
            order: 6, nameKey: "category.other"
        )
        context.insert(custom)
        try context.save()

        SeedService.seedIfNeeded(modelContext: context)

        let fallback = try #require(try other(in: context))
        #expect(fallback.icon == "star.fill")
    }
}
