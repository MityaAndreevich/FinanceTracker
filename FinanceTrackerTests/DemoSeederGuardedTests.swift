//
//  DemoSeederGuardedTests.swift
//  FinanceTrackerTests
//
//  The onboarding demo sandbox must route inserts through a guarded save so a
//  mid-seed failure leaves NO ghost rows (Brief 28 Part C — the anti-poison guard).
//  Serialized because the failure toggle is shared static state.
//

import Testing
import SwiftData
import Foundation
@testable import FinanceTracker

@MainActor
@Suite("DemoSeeder guarded onboarding sandbox", .serialized)
struct DemoSeederGuardedTests {

    private func makeSeededContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        let ctx = ModelContext(container)
        SeedService.seedIfNeeded(modelContext: ctx)   // seeds the categories the demo maps to
        return ctx
    }

    @Test func guardedSeed_success_insertsOnlyDemoRows() throws {
        DemoSeeder._forceOnboardingSeedFailureForTesting = false
        let ctx = try makeSeededContext()

        let n = try DemoSeeder.seedOnboardingDemoGuarded(modelContext: ctx)
        #expect(n > 0, "demo seed should insert transactions")

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == n)
        #expect(all.allSatisfy { $0.isDemo }, "every sandbox row is flagged isDemo")
        #expect(DemoSeeder.hasDemoData(modelContext: ctx))
    }

    @Test func guardedSeed_failure_leavesZeroRows_noGhosts() throws {
        DemoSeeder._forceOnboardingSeedFailureForTesting = true
        defer { DemoSeeder._forceOnboardingSeedFailureForTesting = false }
        let ctx = try makeSeededContext()

        #expect(throws: (any Error).self) {
            _ = try DemoSeeder.seedOnboardingDemoGuarded(modelContext: ctx)
        }

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.isEmpty, "delete-on-failure must leave no ghost/pending rows")
        #expect(DemoSeeder.hasDemoData(modelContext: ctx) == false)
    }

    @Test func clearDemoData_removesOnlyDemoRows() throws {
        DemoSeeder._forceOnboardingSeedFailureForTesting = false
        let ctx = try makeSeededContext()

        let other = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>()).first { $0.name == "Other" }!
        let real = Transaction(
            typeRaw: "expense", amountCents: 100, currency: "USD", date: .now,
            category: other, source: nil, merchant: "RealRow", isDemo: false
        )
        ctx.insert(real)
        try ctx.save()

        _ = try DemoSeeder.seedOnboardingDemoGuarded(modelContext: ctx)
        #expect(DemoSeeder.hasDemoData(modelContext: ctx))

        DemoSeeder.clearDemoData(modelContext: ctx)

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == 1, "only the real row survives")
        #expect(all.first?.merchant == "RealRow")
        #expect(DemoSeeder.hasDemoData(modelContext: ctx) == false)
    }
}
