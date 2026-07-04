//
//  QuickEntryCategoryResolutionTests.swift
//  FinanceTrackerTests
//
//  End-to-end category resolution for the Quick Entry "+" screen: parse a typed
//  string, then resolve it against the REAL seeded taxonomy (SeedService), exactly
//  as QuickEntryView.effectiveCategory does. The existing CategorySuggestionTests
//  only exercise the raw lookup table; these assert the category a user actually
//  sees on the + screen for common inputs (Brief: auto-detect regression).
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("QuickEntry category resolution (seeded)")
@MainActor
struct QuickEntryCategoryResolutionTests {

    /// A container seeded with the production default taxonomy.
    private func makeSeededContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        let ctx = ModelContext(container)
        SeedService.seedIfNeeded(modelContext: ctx)
        return ctx
    }

    /// Mirrors QuickEntryView.effectiveCategory for the no-manual-override case.
    private func resolved(_ input: String, in ctx: ModelContext) -> String? {
        guard let parsed = QuickAddParser.parse(input) else { return nil }
        return QuickAddSaveService.resolveCategory(for: parsed, in: ctx)?.name
    }

    @Test func sanity_seedProducesFoodDrinkCategory() throws {
        let ctx = try makeSeededContext()
        let all = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        #expect(all.contains { $0.name == "Food & Drink" }, "seed must include Food & Drink")
        #expect(all.contains { $0.name == "Other" }, "seed must include Other fallback")
    }

    // Brief's common inputs — each must NOT land on "Other".
    @Test func starbucks_550() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("Starbucks 5.50", in: ctx) == "Food & Drink")
    }

    @Test func coffee_4() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("coffee 4", in: ctx) == "Food & Drink")
    }

    @Test func uber_20() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("uber 20", in: ctx) == "Transport")
    }

    @Test func groceries_40() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("groceries 40", in: ctx) == "Food & Drink")
    }

    @Test func rent_1000() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("rent 1000", in: ctx) == "Housing")
    }

    // MARK: - Typo tolerance (near-miss) — Brief #2 secondary ask.

    @Test func typo_coffe_stillFood() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("coffe 4", in: ctx) == "Food & Drink",
                "a single-char typo of a known keyword should still resolve")
    }

    @Test func typo_starbuks_stillFood() throws {
        let ctx = try makeSeededContext()
        #expect(resolved("starbuks 5.50", in: ctx) == "Food & Drink",
                "a single-char typo of a known brand should still resolve")
    }

    @Test func gibberish_staysOther() throws {
        let ctx = try makeSeededContext()
        // The false-positive guardrail: unknown input must NOT fuzzy-match anything.
        #expect(resolved("xyzqrs 5", in: ctx) == "Other")
    }
}
