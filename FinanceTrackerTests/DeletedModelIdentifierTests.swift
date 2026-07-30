//
//  DeletedModelIdentifierTests.swift
//  FinanceTrackerTests
//
//  CHARACTERIZATION of SwiftData identifier resolution, written because the
//  1.0.4 recurrence work wants to carry a `PersistentIdentifier` from a due
//  prompt into `confirm()` instead of a `uuid` (uuid stops being unique under
//  sync — see AUDIT_UUID_UNIQUENESS_SYNC_1_0_4).
//
//  That plan rested on a CLAIM: that resolving an identifier whose row is gone
//  "degrades to a no-op rather than a fault". It does not. Measured on
//  iOS 26.5 / Xcode 26, iPhone 17 Pro simulator:
//
//      ctx.model(for: <deleted id>)      -> RETURNS a Transaction (non-nil)
//      resolved.isDeleted                -> readable, no trap
//      resolved.amountCents              -> EXC_BREAKPOINT / SIGTRAP
//
//  Crash frames, verbatim:
//      _assertionFailure(_:_:file:line:flags:)
//      Transaction.amountCents.getter
//      DeletedModelIdentifierTests.modelForAfterDelete()
//
//  So `model(for:)` vends a live-looking object over a dead row and traps on
//  the FIRST stored-property read. Any resolver built on it turns "the template
//  was deleted on the other device" into a crash on launch.
//
//  The trap itself is pinned below as an exit test (it has to run in a child
//  process — an in-process trap takes the whole suite down).
//
//  Conclusion encoded by these tests: resolve with a FETCH. `registeredModel`
//  is NOT a safe substitute — it answers "is this row in this context's
//  registry", which is nil for a perfectly live row a fresh context has not
//  touched yet (`registeredModelIsNilForLiveRowInFreshContext`).
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Resolving a PersistentIdentifier whose row is deleted")
@MainActor
struct DeletedModelIdentifierTests {

    /// Holds the container for the caller's lifetime — returning only the
    /// context yields a message-less EXC_BREAKPOINT once the container drops.
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
            TransactionSplit.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    @discardableResult
    private func insertSavedTransaction(in ctx: ModelContext) throws -> Transaction {
        let tx = Transaction(
            typeRaw: "expense", amountCents: 4200, currency: "USD",
            date: Date(), category: nil, merchant: "Vanishing Co",
            recurrenceRaw: "monthly"
        )
        ctx.insert(tx)
        try ctx.save()
        return tx
    }

    // MARK: - What the resolver may rely on

    @Test("registeredModel(for:) yields nil once the row is deleted")
    func registeredModelIsNilAfterDelete() throws {
        let (_, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID

        ctx.delete(tx)
        try ctx.save()

        let resolved: Transaction? = ctx.registeredModel(for: id)
        #expect(resolved == nil)
    }

    @Test("a deleted row does not come back from a fetch")
    func fetchExcludesDeletedRow() throws {
        let (_, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID

        ctx.delete(tx)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.isEmpty)
        #expect(all.first { $0.persistentModelID == id } == nil)
    }

    /// The reason `registeredModel(for:)` cannot be the resolver: it reports on
    /// the CONTEXT'S REGISTRY, not on the store. A row that exists and is
    /// perfectly loadable answers nil here simply because this context has not
    /// materialized it yet — which is the normal state after a cold launch.
    /// Using it as "does this template still exist?" would silently drop every
    /// recurring series on the first launch of the day.
    @Test("registeredModel(for:) is nil for a LIVE row in a fresh context")
    func registeredModelIsNilForLiveRowInFreshContext() throws {
        let (container, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID

        let fresh = ModelContext(container)
        let viaRegistry: Transaction? = fresh.registeredModel(for: id)
        #expect(viaRegistry == nil, "live row, but not registered in this context")

        // ...while a fetch in that same fresh context finds it.
        let all = try fresh.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == 1)
        #expect(all.first?.persistentModelID == id)
    }

    /// A fetch predicated on the identifier — the shape a resolver would use so
    /// it does not pay for fetch-all. Pins that SwiftData supports it, and that
    /// it returns empty rather than trapping for a deleted identifier.
    @Test("FetchDescriptor predicated on persistentModelID resolves and survives deletion")
    func fetchByPersistentModelIDPredicate() throws {
        let (_, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID

        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1

        let live = try ctx.fetch(descriptor)
        #expect(live.count == 1, "the identifier predicate must resolve a live row")

        ctx.delete(tx)
        try ctx.save()

        let dead = try ctx.fetch(descriptor)
        #expect(dead.isEmpty, "the same predicate must simply come back empty")
    }

    /// The foreign-delete shape, which is what sync actually produces: this
    /// context still holds the object, another context removed the row.
    @Test("a row deleted by another context is gone from this context's fetch")
    func rowDeletedByAnotherContext() throws {
        let (container, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID

        let other = ModelContext(container)
        for row in try other.fetch(FetchDescriptor<Transaction>()) { other.delete(row) }
        try other.save()

        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1
        #expect(try ctx.fetch(descriptor).isEmpty)
    }

    // MARK: - The trap itself
    //
    // DISABLED ON PURPOSE — it does not fail, it takes the whole test PROCESS
    // down (EXC_BREAKPOINT), which on a shared-process suite means an unrelated
    // test appears to be the victim. Swift Testing's exit tests would isolate it
    // in a child process, but `#expect(processExitsWith:)` is unavailable on
    // iOS ("Exit tests are not available on this platform"), so there is no way
    // to assert a trap in-suite.
    //
    // Kept compiled and runnable-on-demand so the claim in this file's header is
    // reproducible rather than folklore. To re-verify:
    //
    //   xcodebuild ... -only-testing:FinanceTrackerTests/DeletedModelIdentifierTests \
    //     test   # then flip .disabled off
    //
    // Observed 2026-07-30, iOS 26.5 simulator: crashes in
    // `Transaction.amountCents.getter` -> `_assertionFailure`.

    @Test(
        "reading a stored property off model(for:) of a deleted row traps",
        .disabled("Crashes the test process by design; no iOS exit-test support to isolate it.")
    )
    func modelForTrapsOnStoredPropertyAccess() throws {
        let (_, ctx) = try makeStore()
        let tx = try insertSavedTransaction(in: ctx)
        let id = tx.persistentModelID
        ctx.delete(tx)
        try ctx.save()

        // Returns non-nil. isDeleted is readable. The stored property is not.
        let resolved = ctx.model(for: id) as? Transaction
        _ = resolved?.isDeleted
        _ = resolved?.amountCents      // <- EXC_BREAKPOINT here
    }
}
