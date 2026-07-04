import XCTest
import SwiftData
@testable import FinanceTracker

// MARK: - Root cause of the on-device save cascade: a .deny delete rule (Code 1600)
//
// Device NSError captured 2026-07-04:
//   NSCocoaErrorDomain Code=1600 "Items cannot be deleted from %{PROPERTY}@."
//   NSValidationErrorKey = category   (origin: TransactionResetService.reset)
//
// Code 1600 = NSValidationRelationshipDeniedDeleteError. `Transaction.category`
// carried `@Relationship(deleteRule: .deny)`. In Core Data / SwiftData the delete
// rule governs deletion of the object that OWNS the relationship — so `.deny` on
// `Transaction.category` DENIES deleting any Transaction whose `category` is set.
// Since `category` is non-optional, EVERY transaction delete is denied. Reset's
// save() throws, the un-committable pending deletes linger in the long-lived
// mainContext, and every later save re-throws the same error ("after Reset, every
// save fails").
//
// Why the existing suite stayed green: those tests use `isStoredInMemoryOnly: true`,
// which does not enforce the relationship-deny validation the way the on-disk store
// does. This test uses a TEMPORARY ON-DISK ModelContainer to reproduce the real path.
// It FAILS on the pre-fix code (1600) and PASSES once `category` is `.nullify`.
@MainActor
final class TransactionResetDeleteRuleTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        // Unique on-disk store per test run so we exercise the real (non-in-memory)
        // validation path and never share state across runs.
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResetDeleteRule-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        // Clean up the store and its SQLite side-files.
        let base = storeURL.deletingPathExtension().lastPathComponent
        let dir = storeURL.deletingLastPathComponent()
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where f.hasPrefix(base) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        storeURL = nil
    }

    private func makeOnDiskContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: ModelConfiguration(url: storeURL)
        )
    }

    /// Seeds the primary "Other" category + one Transaction pointing at it — the
    /// exact shape the device repro had before Reset (uuid BE58ABAA… in the log).
    @discardableResult
    private func seedOtherWithOneTransaction(_ ctx: ModelContext) throws -> FinanceTracker.Category {
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        ctx.insert(Transaction(
            typeRaw: "expense", amountCents: 5000, currency: "USD",
            date: Date(), category: other
        ))
        try ctx.save()
        return other
    }

    // Reset must SUCCEED (no denied-delete), leave the context clean (no lingering
    // pending changes), and empty the store — then a following save must work and
    // yield exactly one row (proving the context was not poisoned).
    func testResetThenSave_onDisk_succeedsAndDoesNotPoisonContext() throws {
        let container = try makeOnDiskContainer()
        let ctx = container.mainContext
        try seedOtherWithOneTransaction(ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 1)

        // (1) Reset succeeds and empties the store.
        let outcome = TransactionResetService.reset(in: ctx)
        XCTAssertEqual(outcome, .success,
            "Reset must not be denied by a relationship delete rule (Code 1600).")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 0,
            "Every transaction must be gone after a successful reset.")

        // (2) The long-lived context must carry no un-committable pending changes.
        XCTAssertFalse(ctx.hasChanges,
            "A clean reset must not leave pending (poisoning) changes in the context.")

        // (3) A subsequent quick-add save must succeed and produce exactly one row —
        //     the device symptom was 'after Reset every save fails'.
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        ctx.insert(Transaction(
            typeRaw: "expense", amountCents: 250, currency: "USD",
            date: Date(), category: other
        ))
        XCTAssertNoThrow(try ctx.save(),
            "The save after a reset must not re-throw the poisoned delete error.")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 1,
            "Exactly one transaction must exist after the post-reset save.")
    }

    // Directly proves the relationship no longer denies a transaction delete: delete
    // a single Transaction that points at a Category and commit it on disk.
    func testDeletingTransactionWithCategory_onDisk_isAllowed() throws {
        let container = try makeOnDiskContainer()
        let ctx = container.mainContext
        try seedOtherWithOneTransaction(ctx)

        let tx = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        ctx.delete(tx)
        XCTAssertNoThrow(try ctx.save(),
            "Deleting a Transaction whose category is set must be allowed (not .deny).")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 0)
    }
}
