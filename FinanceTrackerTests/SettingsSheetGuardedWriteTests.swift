//
//  SettingsSheetGuardedWriteTests.swift
//  FinanceTrackerTests
//
//  F3 (Overnight 2026-08-05). Three sheet sites were fixed in the 2026-08
//  save-site audit and shipped WITHOUT tests, by explicit choice, because they
//  lived inside `private struct`s in `CategoriesSourcesView.swift` and there was
//  nothing to call:
//
//    * `CategoryLimitSheet` — save
//    * `CategoryLimitSheet` — clear
//    * `AddSourceSheet`     — add
//
//  An untested fix to an ERROR path is the fix most likely to be silently wrong:
//  the error path is the one nobody exercises, so a regression is invisible until
//  a user meets it, and the symptom ("I set a budget and it vanished") does not
//  point at a save. The sheets now call `CategoryLimitService` /
//  `SourceCreateService` and these drive those.
//
//  FAILURE IS REAL, NOT MOCKED. Every failing case runs against a store reopened
//  with `allowsSave: false`, so `save()` throws NSCocoaErrorDomain 513 out of the
//  real SwiftData path — the same mechanism `SaveFailureReachabilityProbe` and
//  `TransactionDeleteServiceTests` use. A mocked throw would prove the guard
//  compiles, not that it holds.
//
//  WHAT EACH TEST IS ACTUALLY FOR. Not "does the write work" — it always did.
//  The property is: on failure the caller learns about it (`false`/`nil`), the
//  in-memory object does NOT keep the value the store rejected, and nothing
//  outside the store is committed.
//

import Foundation
import SwiftData
import Testing
@testable import FinanceTracker

@Suite("Settings sheets gate their side effects on the save", .serialized)
@MainActor
struct SettingsSheetGuardedWriteTests {

    private static let models: [any PersistentModel.Type] = [
        Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
    ]

    /// Seeds one category (optionally already carrying a limit) and returns a
    /// context on the SAME store reopened read-only, so every later save throws.
    private func makeUnwritableStore(existingLimitCents: Int? = nil)
        throws -> (ModelContainer, ModelContext, URL)
    {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sheet-ro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let schema = Schema(Self.models)

        try autoreleasepool {
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            let category = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
            category.limitCents = existingLimitCents
            context.insert(category)
            try context.save()
        }

        let readOnly = try ModelContainer(
            for: schema, configurations: ModelConfiguration(url: url, allowsSave: false)
        )
        let context = ModelContext(readOnly)
        context.autosaveEnabled = false
        return (readOnly, context, dir)
    }

    private func makeWritableStore() throws -> (ModelContainer, ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sheet-rw-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Vela.sqlite")
        let container = try ModelContainer(
            for: Schema(Self.models), configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (container, context, dir)
    }

    private func seedCategory(in context: ModelContext) -> FinanceTracker.Category {
        let category = FinanceTracker.Category(name: "Food", kindRaw: "expense", order: 0)
        context.insert(category)
        try? context.save()
        return category
    }

    /// Restores `usage.ever.category_limits`, which `setLimit` writes for real.
    private func withCleanLimitSignal(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let key = "usage.ever.category_limits"
        let prior = defaults.object(forKey: key)
        defer {
            if let prior { defaults.set(prior, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)
        try body()
    }

    // MARK: - CategoryLimitSheet — save

    @Test("a failed limit save reports false and does not leave the value in memory")
    func failedSetLimitRevertsAndReports() throws {
        try withCleanLimitSignal {
            let (container, context, dir) = try makeUnwritableStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            _ = container

            let category = try #require(
                try context.fetch(FetchDescriptor<FinanceTracker.Category>()).first
            )
            #expect(category.limitCents == nil, "precondition")

            let committed = CategoryLimitService.setLimit(50_000, on: category, in: context)

            #expect(committed == false, "the caller must be able to tell the sheet not to dismiss")
            // The revert closure matters here specifically: `limitCents` is an
            // ATTRIBUTE, and `rollback()` alone does not restore those on a live
            // SwiftData object. Without it the rejected value stays in memory and
            // the sheet shows a limit the store never accepted.
            #expect(category.limitCents == nil, "the rejected value is still sitting on the object")
        }
    }

    @Test("a failed limit save does not record the usage signal")
    func failedSetLimitDoesNotMarkUsage() throws {
        try withCleanLimitSignal {
            let (container, context, dir) = try makeUnwritableStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            _ = container

            let category = try #require(
                try context.fetch(FetchDescriptor<FinanceTracker.Category>()).first
            )
            _ = CategoryLimitService.setLimit(50_000, on: category, in: context)

            #expect(
                !FeatureUsageSignals.wasUsed(.categoryLimits),
                "a limit the user never got must not count toward the pre-test instrument"
            )
        }
    }

    @Test("a successful limit save persists and records the usage signal")
    func successfulSetLimitPersistsAndMarks() throws {
        try withCleanLimitSignal {
            let (container, context, dir) = try makeWritableStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            _ = container

            let category = seedCategory(in: context)
            #expect(CategoryLimitService.setLimit(50_000, on: category, in: context))

            let reread = try #require(
                try context.fetch(FetchDescriptor<FinanceTracker.Category>()).first
            )
            #expect(reread.limitCents == 50_000)
            #expect(FeatureUsageSignals.wasUsed(.categoryLimits))
        }
    }

    // MARK: - CategoryLimitSheet — clear

    @Test("a failed limit clear reports false and leaves the limit intact")
    func failedClearLimitRevertsAndReports() throws {
        let (container, context, dir) = try makeUnwritableStore(existingLimitCents: 30_000)
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = container

        let category = try #require(
            try context.fetch(FetchDescriptor<FinanceTracker.Category>()).first
        )
        #expect(category.limitCents == 30_000, "precondition")

        #expect(CategoryLimitService.clearLimit(on: category, in: context) == false)
        #expect(
            category.limitCents == 30_000,
            "the limit was cleared in memory while the store still holds it — the sheet would dismiss on a lie"
        )
    }

    @Test("a successful limit clear removes it from disk")
    func successfulClearLimitPersists() throws {
        try withCleanLimitSignal {
            let (container, context, dir) = try makeWritableStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            _ = container

            let category = seedCategory(in: context)
            #expect(CategoryLimitService.setLimit(30_000, on: category, in: context))
            #expect(CategoryLimitService.clearLimit(on: category, in: context))

            let reread = try #require(
                try context.fetch(FetchDescriptor<FinanceTracker.Category>()).first
            )
            #expect(reread.limitCents == nil)
        }
    }

    /// Clearing a limit is not "using category limits". Marking on the clear path
    /// would let a user who only ever REMOVED one count toward the feature.
    @Test("clearing a limit does not record the usage signal")
    func clearLimitDoesNotMarkUsage() throws {
        try withCleanLimitSignal {
            let (container, context, dir) = try makeWritableStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            _ = container

            let category = seedCategory(in: context)
            category.limitCents = 30_000
            try context.save()

            #expect(CategoryLimitService.clearLimit(on: category, in: context))
            #expect(!FeatureUsageSignals.wasUsed(.categoryLimits))
        }
    }

    // MARK: - AddSourceSheet — add

    @Test("a failed account insert reports nil and puts no row on disk")
    func failedSourceAddReportsNil() throws {
        let (container, context, dir) = try makeUnwritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = container

        let created = SourceCreateService.add(name: "Checking", note: nil, in: context)

        #expect(created == nil, "the sheet must not dismiss or call onAdded")

        // The context must be left clean — a pending insert left behind would ride
        // along on the user's NEXT ordinary save and appear at a moment they never
        // asked for. That is the same defect class the whole audit was about.
        #expect(context.hasChanges == false)
        #expect(context.insertedModelsArray.isEmpty)

        // …and nothing reached disk. Read through a SEPARATE context, which is
        // both the honest claim ("no row on disk") and a way around the trap below.
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Source>()).isEmpty)
    }

    /// HARNESS TRAP, measured 2026-08-08 and pinned so nobody re-derives it —
    /// this one cost two wrong conclusions in a row, in OPPOSITE directions.
    ///
    /// The FIRST query issued on a context after a failed save + `rollback()`
    /// returns a STALE answer. The second is correct. Which query is wrong
    /// therefore depends on the order you happen to write them in:
    ///
    ///     fetchCount, then fetch   →  1,  []          ("fetchCount is broken")
    ///     fetch, then fetchCount   →  ["Checking"], 0 ("the guard is broken")
    ///
    /// Neither reading was right. `hasChanges == false` and
    /// `insertedModelsArray == []` throughout, in both orderings — the rollback
    /// worked, and the first query is simply served before the cache settles.
    ///
    /// The rule that follows: after inducing a save failure, assert through a
    /// FRESH `ModelContext`, never through the one that took the failure. A
    /// same-context assertion is a coin flip dressed as evidence.
    @Test("PIN: the first query after a rolled-back save is stale, in either order")
    func firstQueryAfterRollbackIsStale() throws {
        let (container, context, dir) = try makeUnwritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = SourceCreateService.add(name: "Checking", note: nil, in: context)

        // The context's own bookkeeping is correct and order-independent.
        #expect(context.hasChanges == false)
        #expect(context.insertedModelsArray.isEmpty)

        // The first query disagrees with the second. Pinned as an observation,
        // not endorsed: if a future SwiftData makes both agree, this test fails
        // and should be deleted along with the warning above.
        let first = try context.fetch(FetchDescriptor<Source>()).map(\.name)
        let second = try context.fetch(FetchDescriptor<Source>()).map(\.name)
        #expect(first == ["Checking"], "the stale-first-read behaviour changed")
        #expect(second.isEmpty, "the second read must be the settled one")

        // Ground truth, and what the test above asserts on instead.
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Source>()).isEmpty)
    }

    @Test("a successful account insert persists with trimmed fields")
    func successfulSourceAddPersists() throws {
        let (container, context, dir) = try makeWritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = container

        let created = try #require(
            SourceCreateService.add(name: "  Checking  ", note: "  rainy day  ", in: context)
        )
        #expect(created.name == "Checking")
        #expect(created.note == "rainy day")

        let rows = try context.fetch(FetchDescriptor<Source>())
        #expect(rows.count == 1)
        #expect(rows.first?.name == "Checking")
    }

    @Test("a whitespace-only note is stored as nil, not as blanks")
    func whitespaceNoteBecomesNil() throws {
        let (container, context, dir) = try makeWritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = container

        let created = try #require(
            SourceCreateService.add(name: "Savings", note: "   ", in: context)
        )
        #expect(created.note == nil)
    }

    @Test("a blank name is refused before anything is inserted")
    func blankNameInsertsNothing() throws {
        let (container, context, dir) = try makeWritableStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = container

        #expect(SourceCreateService.add(name: "   ", note: nil, in: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Source>()) == 0)
    }
}
