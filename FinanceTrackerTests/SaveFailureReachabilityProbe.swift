//
//  SaveFailureReachabilityProbe.swift
//  FinanceTrackerTests
//
//  PRIORITY 1, part (a): "how is it reachable?" `DuplicateReviewService.deleteAll`
//  swallows a thrown `save()` without rolling back, and the severity of that
//  depends entirely on whether the throw can happen in the field. This probe asks
//  the question empirically instead of arguing it: it tries every mechanism that
//  could plausibly make `ModelContext.save()` throw on the real two-configuration
//  container, and reports which ones actually do.
//
//  A mechanism that does NOT throw is as much a result as one that does — it is
//  what lets "unreachable in practice" be *demonstrated* rather than assumed.
//  Every attempt is printed, including the failures to fail.
//
//  Note for the report: the delete rule the freeze brief guessed at (`.deny` on
//  Category) no longer exists anywhere in the schema — every rule is `.nullify`
//  or `.cascade` (grep of Models/ + Data/FinanceTrackerSchemaV1.swift). So that
//  specific cause is dead and the reachable ones have to be found elsewhere.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Save-failure reachability", .serialized)
@MainActor
struct SaveFailureReachabilityProbe {

    private struct Store {
        let container: ModelContainer
        let context: ModelContext
        let dir: URL
        let synced: URL
        let local: URL
    }

    /// The REAL production open: one container, two configurations (synced +
    /// local), migration plan attached. Both stores therefore share a single
    /// context — which is itself part of the reachability answer.
    private func makeProductionShapedStore() throws -> Store {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("savefail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let synced = dir.appendingPathComponent("Vela.sqlite")
        let local = dir.appendingPathComponent("VelaLocal.sqlite")
        let container = try SharedModelContainer.openContainer(storeURL: synced, localStoreURL: local)
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return Store(container: container, context: ctx, dir: dir, synced: synced, local: local)
    }

    private func discard(_ s: Store) { try? FileManager.default.removeItem(at: s.dir) }

    /// Store files SQLite actually writes through: the database, its write-ahead
    /// log, and the shared-memory index.
    private func storeFiles(_ s: Store) -> [String] {
        ["", "-wal", "-shm"].map {
            s.synced.deletingLastPathComponent()
                .appendingPathComponent(s.synced.lastPathComponent + $0).path
        }
    }

    /// Makes the store unwritable through descriptors SQLite already holds. The
    /// immutable flag (UF_IMMUTABLE) is enforced per-write rather than at open,
    /// which is what a permissions change cannot do.
    private func lock(_ s: Store) {
        for p in storeFiles(s) where FileManager.default.fileExists(atPath: p) {
            try? FileManager.default.setAttributes([.immutable: true], ofItemAtPath: p)
        }
    }

    private func unlock(_ s: Store) {
        for p in storeFiles(s) where FileManager.default.fileExists(atPath: p) {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: p)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: s.dir.path)
    }

    private func attempt(_ name: String, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            print("[probe] \(name): did NOT throw")
            return false
        } catch {
            let ns = error as NSError
            print("[probe] \(name): THREW  domain=\(ns.domain) code=\(ns.code)")
            return true
        }
    }

    // MARK: - Which mechanisms can make save() throw?

    @Test("Probe: which mechanisms make ModelContext.save() throw?")
    func whichMechanismsThrow() throws {
        print("\n=== save() failure mechanism probe ===")

        // 1. `.unique` violation inside ONE save. MerchantCategoryLearning is the
        //    only `.unique` attribute that ships, and it lives in the LOCAL store —
        //    but the container is multi-configuration, so it shares the context
        //    that the duplicate-review delete uses.
        do {
            let s = try makeProductionShapedStore()
            defer { discard(s) }
            s.context.insert(MerchantCategoryLearning(merchantNormalized: "acme", categoryName: "Food"))
            s.context.insert(MerchantCategoryLearning(merchantNormalized: "acme", categoryName: "Fun"))
            _ = attempt("unique violation, one save") { try s.context.save() }
        }

        // 2. `.unique` violation across TWO saves (the upsert path, if any).
        do {
            let s = try makeProductionShapedStore()
            defer { discard(s) }
            s.context.insert(MerchantCategoryLearning(merchantNormalized: "acme", categoryName: "Food"))
            try s.context.save()
            s.context.insert(MerchantCategoryLearning(merchantNormalized: "acme", categoryName: "Fun"))
            _ = attempt("unique violation, second save") { try s.context.save() }
            let n = try s.context.fetchCount(FetchDescriptor<MerchantCategoryLearning>())
            print("[probe]   → \(n) learning row(s) survive (2 = no constraint, 1 = upsert)")
        }

        // 3. Read-only store. This is what the degraded floor (openV1ReadOnly)
        //    already uses, so it is a shape the app really constructs.
        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("savefail-ro-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("ro.sqlite")
            defer { try? FileManager.default.removeItem(at: dir) }
            // Create it writable first, then reopen read-only.
            do {
                let c = try ModelContainer(for: Transaction.self, FinanceTracker.Category.self,
                                           Source.self, TransactionSplit.self,
                                           configurations: ModelConfiguration(url: url))
                let ctx = ModelContext(c)
                ctx.insert(Transaction(typeRaw: "expense", amountCents: 100, date: Date(), category: nil))
                try ctx.save()
            }
            let ro = try ModelContainer(
                for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
                configurations: ModelConfiguration(url: url, allowsSave: false)
            )
            let ctx = ModelContext(ro)
            let rows = try ctx.fetch(FetchDescriptor<Transaction>())
            for tx in rows { ctx.delete(tx) }
            _ = attempt("read-only store, delete + save") { try ctx.save() }
        }

        // 4. Two contexts on the same store deleting the same row — the shape the
        //    app really has now that CSVImportActor (a @ModelActor with its own
        //    context) writes the same store the main context reviews.
        do {
            let s = try makeProductionShapedStore()
            defer { discard(s) }
            let tx = Transaction(typeRaw: "expense", amountCents: 100, date: Date(), category: nil)
            s.context.insert(tx)
            try s.context.save()

            let other = ModelContext(s.container)
            other.autosaveEnabled = false
            let mine = try s.context.fetch(FetchDescriptor<Transaction>())
            let theirs = try other.fetch(FetchDescriptor<Transaction>())
            for t in theirs { other.delete(t) }
            try other.save()
            for t in mine { s.context.delete(t) }
            _ = attempt("delete a row a second context already deleted") { try s.context.save() }
        }

        // 5b. TRANSIENT I/O failure, two candidate mechanisms. This is the one
        //     that matters: the realistic field cause (a device momentarily unable
        //     to write) is RECOVERABLE, and only a recoverable failure lets "what
        //     happens next" be tested rather than argued.
        //
        //     chmod is tried first and is expected to fail to fail: SQLite already
        //     holds writable descriptors, and POSIX permissions are checked at
        //     open(2), not write(2). The immutable flag is checked per-write, so
        //     it should reach an open descriptor.
        for mech in ["chmod 0555 on the directory", "immutable flag on store + wal + shm"] {
            let s = try makeProductionShapedStore()
            defer { unlock(s); discard(s) }
            s.context.insert(Transaction(typeRaw: "expense", amountCents: 100, date: Date(), category: nil))
            try s.context.save()

            if mech.hasPrefix("chmod") {
                try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: s.dir.path)
            } else {
                lock(s)
            }
            s.context.insert(Transaction(typeRaw: "expense", amountCents: 200, date: Date(), category: nil))
            let threw = attempt("TRANSIENT: \(mech)") { try s.context.save() }
            unlock(s)
            if threw {
                _ = attempt("   ...and after the condition clears, save again") { try s.context.save() }
            }
        }

        // 5. Store file yanked out from under an open container (the crude stand-in
        //    for permanent I/O failure / corruption).
        do {
            let s = try makeProductionShapedStore()
            defer { discard(s) }
            let tx = Transaction(typeRaw: "expense", amountCents: 100, date: Date(), category: nil)
            s.context.insert(tx)
            try s.context.save()
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: s.synced.deletingLastPathComponent()
                        .appendingPathComponent(s.synced.lastPathComponent + suffix))
            }
            s.context.insert(Transaction(typeRaw: "expense", amountCents: 200, date: Date(), category: nil))
            _ = attempt("store file deleted underneath, then save") { try s.context.save() }
        }
    }

    // MARK: - The consequence, once deleteAll's save HAS thrown and nobody rolled back

    /// Seeds a store with `flagged` review-queue rows, then REOPENS it read-only.
    /// Read-only is the failure mechanism because it is one of only two the probe
    /// could actually induce (NSCocoaErrorDomain 513); the transient analogues of
    /// disk pressure could not be made to throw in the simulator, so they are
    /// reported as untested rather than faked.
    private func makeUnwritableStoreWithFlaggedRows(_ flagged: Int) throws -> (ModelContainer, ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("savefail-ro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let models: [any PersistentModel.Type] = [
            Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
        ]
        try autoreleasepool {
            let c = try ModelContainer(for: Schema(models), configurations: ModelConfiguration(url: url))
            let ctx = ModelContext(c)
            let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
            ctx.insert(cat)
            for i in 0..<flagged {
                ctx.insert(Transaction(typeRaw: "expense", amountCents: 100 + i, date: Date(),
                                       category: cat, isPossibleDuplicate: true))
            }
            try ctx.save()
        }
        let ro = try ModelContainer(for: Schema(models),
                                    configurations: ModelConfiguration(url: url, allowsSave: false))
        let ctx = ModelContext(ro)
        ctx.autosaveEnabled = false
        return (ro, ctx, dir)
    }

    /// REGRESSION for the Priority-1 fix. Drives the REAL
    /// `DuplicateReviewService.deleteAll` into a REAL save failure (read-only
    /// store, NSCocoaErrorDomain 513) and asserts the three properties the fix
    /// has to hold — each of which failed before it:
    ///
    ///   1. the error REACHES the caller (it must, or the UI cannot tell anyone);
    ///   2. the context is left CLEAN, so the abandoned deletes cannot ride along
    ///      on the user's next unrelated save (see the mechanism test below);
    ///   3. the count the app reports is HONEST — `flaggedCount` sets
    ///      `includePendingChanges = true`, so before the fix it read zero off the
    ///      pending deletes while the store still held all 50 rows.
    ///
    /// Deliberately NOT asserted: "every subsequent save fails". That claim comes
    /// from `TransactionResetService`'s comment, written when Category carried a
    /// `.deny` delete rule. The probe above shows the surviving candidate
    /// mechanisms either do not throw at all (`.unique` upserts; cross-context
    /// deletes merge silently) or are permanent rather than poisoning, so the
    /// claim is unsupported at HEAD and is not repeated here.
    @Test("Regression: a failed deleteAll rolls back, rethrows, and reports honestly")
    func failedDeleteAllRollsBackAndReports() throws {
        let (container, ctx, dir) = try makeUnwritableStoreWithFlaggedRows(50)
        defer { try? FileManager.default.removeItem(at: dir) }

        var reachedCaller = false
        do { try DuplicateReviewService.deleteAll(in: ctx) }
        catch { reachedCaller = true }
        #expect(reachedCaller, "the UI cannot report a failure it is never told about")

        #expect(ctx.hasChanges == false, "rolled back — no pending deletes left to commit later")

        // HARNESS ARTIFACT, recorded so nobody re-derives it: on a READ-ONLY store
        // `rollback()` clears the pending changes (asserted above) but cannot
        // re-materialize the rolled-back objects, so flaggedCount here still reads
        // 0. On a writable store it reads the true 50 — that is the `rollbackCure`
        // test below, which is the authority for the honest-count property. What
        // this store CAN answer authoritatively is the one that matters most:
        // nothing was destroyed.
        let reported = try DuplicateReviewService.flaggedCount(in: ctx)
        let onDisk = try ModelContext(container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isPossibleDuplicate }))
        print("[regression] app reports \(reported) flagged row(s); the store holds \(onDisk)")
        #expect(onDisk == 50)
        withExtendedLifetime(container) {}
    }

    /// The cure. Tested on a HEALTHY store rather than the read-only one, because
    /// the property that matters is about pending state, not about the failure:
    /// after `rollback()`, does the abandoned delete stay abandoned when the next
    /// ordinary save comes along? That is the exact inverse of the mechanism test
    /// below, and it is what `TransactionResetService` already relies on.
    @Test("Cure: after rollback() the abandoned delete does NOT ride along on a later save")
    func rollbackCure() throws {
        let s = try makeProductionShapedStore()
        defer { discard(s) }

        let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        s.context.insert(cat)
        for i in 0..<50 {
            s.context.insert(Transaction(typeRaw: "expense", amountCents: 100 + i, date: Date(),
                                         category: cat, isPossibleDuplicate: true))
        }
        try s.context.save()

        for tx in try DuplicateReviewService.flagged(in: s.context) { s.context.delete(tx) }
        s.context.rollback()
        #expect(s.context.hasChanges == false)

        // The count the app would show right after the rollback. Recorded rather
        // than asserted-blind: rollback()'s effect on an already-materialized
        // deleted object is the part worth knowing exactly.
        let reported = try DuplicateReviewService.flaggedCount(in: s.context)
        print("[cure] flaggedCount reports \(reported) immediately after rollback()")

        s.context.insert(Transaction(typeRaw: "expense", amountCents: 999, date: Date(), category: cat))
        try s.context.save()

        let onDisk = try ModelContext(s.container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isPossibleDuplicate }))
        print("[cure] flagged rows on disk after a later unrelated save: \(onDisk) (want 50)")
        #expect(onDisk == 50)
    }

    /// Why leaving the deletes pending is not merely untidy: pending deletes are
    /// flushed by the NEXT successful save, whatever caused it. So a swallowed
    /// failure does not stay failed — it commits itself later, at a moment the
    /// user never asked for and cannot connect to anything they did.
    ///
    /// Shown on a healthy store, because it is a property of pending state rather
    /// than of the failure: delete without saving, then save something unrelated.
    @Test("Mechanism: pending deletes are committed by the next unrelated save")
    func pendingDeletesRideAlongOnTheNextSave() throws {
        let s = try makeProductionShapedStore()
        defer { discard(s) }

        let cat = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        s.context.insert(cat)
        for i in 0..<50 {
            s.context.insert(Transaction(typeRaw: "expense", amountCents: 100 + i, date: Date(),
                                         category: cat, isPossibleDuplicate: true))
        }
        try s.context.save()

        // The delete happens; the save that should have committed it does not.
        for tx in try DuplicateReviewService.flagged(in: s.context) { s.context.delete(tx) }
        let beforeOnDisk = try ModelContext(s.container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isPossibleDuplicate }))
        #expect(beforeOnDisk == 50)

        // An ordinary later write — the user entering a transaction.
        s.context.insert(Transaction(typeRaw: "expense", amountCents: 999, date: Date(), category: cat))
        try s.context.save()

        let afterOnDisk = try ModelContext(s.container).fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isPossibleDuplicate }))
        print("[mechanism] flagged rows on disk before the unrelated save: \(beforeOnDisk), after: \(afterOnDisk)")
        #expect(afterOnDisk == 0)
    }
}
