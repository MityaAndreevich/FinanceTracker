//
//  TransactionEditServiceTests.swift
//  FinanceTrackerTests
//
//  QA round 2 #4 — editing a transaction from the list. The happy path already
//  works (see EditTransactionFlowTests UI test); the real defect is the UNGUARDED
//  save that poisons the mainContext on failure. These tests pin both: an edit
//  persists and the list query reflects it, and a failed save rolls back instead
//  of poisoning the context.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("TransactionEditService (QA round 2 #4)")
@MainActor
struct TransactionEditServiceTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func seedOne(in ctx: ModelContext) -> (Transaction, FinanceTracker.Category) {
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        let tx = Transaction(
            typeRaw: "expense", amountCents: 5200, currency: "USD",
            date: Date(), category: cat
        )
        ctx.insert(tx)
        try? ctx.save()
        return (tx, cat)
    }

    private func fields(from tx: Transaction, cat: FinanceTracker.Category, amountCents: Int) -> TransactionEditService.Fields {
        TransactionEditService.Fields(
            typeRaw: tx.typeRaw, amountCents: amountCents, taxCents: tx.taxCents,
            currency: tx.currency, merchant: tx.merchant, note: tx.note,
            date: tx.date, category: cat, source: tx.source
        )
    }

    @Test func testEditAmount_persists_andListQueryReflects() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(in: ctx)
        let uuid = tx.uuid

        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, amountCents: 999_900), in: ctx)

        // Re-fetch exactly as TransactionsView's @Query does (date, reverse).
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let rows = try ctx.fetch(descriptor)
        let updated = try #require(rows.first { $0.uuid == uuid })
        #expect(updated.amountCents == 999_900, "edit did not persist — the list would not reflect it")
    }

    @Test func testSaveFailure_rollsBackEdit_andContextNotPoisoned() throws {
        let ctx = try makeContext()
        let (tx, cat) = seedOne(in: ctx)
        #expect(tx.amountCents == 5200)

        // Force the guarded save to throw AFTER mutating.
        TransactionEditService._forceSaveFailureForTesting = true
        defer { TransactionEditService._forceSaveFailureForTesting = false }

        #expect(throws: (any Error).self) {
            try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, amountCents: 111_100), in: ctx)
        }

        // Rollback reverted the dirty mutation; no half-applied edit lingers.
        #expect(tx.amountCents == 5200, "a failed save must roll the edit back, not leave a dirty context")
        #expect(ctx.hasChanges == false, "context must be clean after a guarded failure")

        // And the context still saves — a real edit succeeds right after (proving
        // the context was not poisoned, unlike an unguarded save()).
        TransactionEditService._forceSaveFailureForTesting = false
        try TransactionEditService.update(tx, with: fields(from: tx, cat: cat, amountCents: 222_200), in: ctx)
        let rows = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(rows.first?.amountCents == 222_200, "context was poisoned — the recovery save should have worked")
    }
}
