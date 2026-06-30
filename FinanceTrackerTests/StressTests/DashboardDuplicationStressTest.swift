import XCTest
import SwiftData
@testable import FinanceTracker

// MARK: - Round 9 (device test #8): duplication recurs at scale (50+)
//
// CRITICAL CONTEXT: the duplicates DISAPPEAR after force-quit + reopen, which
// rules the persistence layer out — a store-level dup would survive a restart.
// The bug is in the render/state layer at scale.
//
// This harness reproduces the *store* side programmatically FIRST, to stop the
// "claim fix → device fails" cycle. If these pass, the store is provably sound
// and the defect is in the View → @Query → render chain (see Commit 2). If any
// fail, Brief 35 missed a real persistence bug.
//
// NOTE: the brief's sketch used an instance `QuickAddSaveService(modelContext:)`
// with `save(amount:merchant:type:)` and a `MerchantCategoryMemory` model — none
// of which exist. The real API is the `@MainActor enum QuickAddSaveService` with
// a static `save(parsed:modelContext:defaultCurrencyCode:overrideCategory:now:)`,
// the learning model is `MerchantCategoryLearning`, and `Transaction` needs
// `typeRaw/amountCents/date/category`. Adapted accordingly; intent preserved.

@MainActor
final class DashboardDuplicationStressTest: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func seedOther(_ ctx: ModelContext) throws -> FinanceTracker.Category {
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        try ctx.save()
        return other
    }

    // 100 distinct saves through the shared Quick Add service (Dashboard / voice /
    // AppIntent all funnel through this one path) must yield exactly 100 rows.
    func testHundredMixedSavesProducesExactCountInStore() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let container = try makeContainer()
        let ctx = container.mainContext
        try seedOther(ctx)

        for i in 0..<100 {
            let parsed = QuickAddParsedInput(
                amountCents: (i + 1) * 10,
                typeRaw: "expense",
                merchant: "Test\(i)",
                suggestedCategoryName: nil
            )
            _ = try QuickAddSaveService.save(
                parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD"
            )
        }

        let stored = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(stored.count, 100,
            "Expected exactly 100 transactions, got \(stored.count).")
        // Distinct merchants → distinct rows, no silent collapse.
        XCTAssertEqual(Set(stored.compactMap(\.merchant)).count, 100,
            "All 100 merchants must be distinct rows.")
    }

    // Idempotency at scale: the same amount+type+merchant fired 10× within the 30s
    // window collapses to one row (the recognizer can deliver repeated finals).
    func testRapidSameMerchantSavesWithin30sStillRespectsIdempotency() throws {
        QuickAddSaveService._resetDedupCacheForTesting()
        let container = try makeContainer()
        let ctx = container.mainContext
        try seedOther(ctx)

        let now = Date()
        for _ in 0..<10 {
            let parsed = QuickAddParsedInput(
                amountCents: 145, typeRaw: "expense", merchant: "Баклажаны", suggestedCategoryName: nil
            )
            _ = try QuickAddSaveService.save(
                parsed: parsed, modelContext: ctx, defaultCurrencyCode: "USD", now: now
            )
        }

        let stored = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(stored.count, 1,
            "Idempotency at scale failed: got \(stored.count) Баклажаны entries.")
    }

    // A bulk insert then two identical fetches (simulating @Query re-evaluation)
    // must return the same set with the same STABLE identity (uuid) — no ghost rows
    // and no duplicate identity. uuid is the app-level id the row ForEachs key on;
    // persistentModelID is deliberately NOT used here because it is temporary until
    // save and is exactly what makes the UI ghost at scale (see Commit 2).
    func testQueryRefreshAfterBulkInsertDoesNotShowDuplicates() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let other = try seedOther(ctx)

        for i in 0..<50 {
            ctx.insert(Transaction(
                typeRaw: "expense", amountCents: 100 + i, currency: "USD",
                date: Date().addingTimeInterval(TimeInterval(i)), category: other, merchant: "Item\(i)"
            ))
        }
        try ctx.save()

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let firstFetch = try ctx.fetch(descriptor)
        let secondFetch = try ctx.fetch(descriptor)

        XCTAssertEqual(firstFetch.count, 50)
        XCTAssertEqual(secondFetch.count, 50)
        XCTAssertEqual(Set(firstFetch.map(\.uuid)).count, 50, "no duplicate identities in a single fetch")
        XCTAssertEqual(firstFetch.map(\.uuid), secondFetch.map(\.uuid),
            "two @Query evaluations must yield identical stable identities — no ghost rows")
    }
}
