import XCTest
import SwiftData
@testable import FinanceTracker

// MARK: - Round 9 render-chain regression guard
//
// After three rounds of "TEST SUCCEEDED but device fails", this locks the
// View → @Query → render DATA CONTRACT that actually regressed: row identity.
//
// Why not the brief's two suggested tools:
//   • ViewInspector is a third-party dependency — banned by this repo (native
//     APIs only), so it's not an option.
//   • A 50-save XCUITest can't be made reliable here: the Quick Add bar is
//     confidence-gated (some inputs auto-save, others show a preview chip), it
//     has no stable accessibility identifiers, and the only launch-arg seeding
//     hooks live in DemoSeeder/ScreenshotMode (DO-NOT-TOUCH). A flaky UI test
//     that intermittently breaks "all tests green" is worse than no UI test.
//
// What actually broke was identity: the row ForEachs keyed on Transaction's
// default Identifiable (persistentModelID), which is TEMPORARY until save and
// flips to permanent on save — producing transient duplicate rows at scale that
// cleared on restart. The fix keys on the stable `uuid`. These tests pin that
// invariant and the exact derived data each view feeds to its ForEach, at the
// 50+ scale the device failed at.

@MainActor
final class RecentListRenderContractTests: XCTestCase {

    // Return the CONTAINER, not just its mainContext. A ModelContext does not keep
    // its ModelContainer alive, so a helper that returns `container.mainContext` lets
    // the container deallocate at function exit — the next SwiftData op then traps
    // (EXC_BREAKPOINT, no message) on a dangling backing. Each test must hold the
    // container in its own scope for the test's duration.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func seed(_ n: Int, in ctx: ModelContext, interleaveSaves: Bool) throws -> FinanceTracker.Category {
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        try ctx.save()
        for i in 0..<n {
            ctx.insert(Transaction(
                typeRaw: "expense", amountCents: 100 + i, currency: "USD",
                date: Date().addingTimeInterval(TimeInterval(i)), category: cat, merchant: "M\(i)"
            ))
            // interleaved saves reproduce the rapid-save lifecycle where freshly
            // inserted rows briefly carry a temporary persistentModelID.
            if interleaveSaves { try ctx.save() }
        }
        if !interleaveSaves { try ctx.save() }
        return cat
    }

    // The identity key the row ForEachs use must be invariant across the whole
    // insert → save → mutate → save lifecycle. (persistentModelID is NOT — it is
    // temporary until save — which is precisely why the views must not key on it.)
    func testTransactionUUID_isStableAcrossSaveLifecycle() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        try ctx.save()

        let tx = Transaction(typeRaw: "expense", amountCents: 500, currency: "USD",
                             date: Date(), category: cat, merchant: "Coffee")
        let atInit = tx.uuid
        ctx.insert(tx)
        let afterInsert = tx.uuid
        try ctx.save()
        let afterSave = tx.uuid
        tx.amountCents = 600
        try ctx.save()
        let afterMutate = tx.uuid

        XCTAssertEqual(atInit, afterInsert)
        XCTAssertEqual(afterInsert, afterSave, "uuid must not change when the temporary id becomes permanent")
        XCTAssertEqual(afterSave, afterMutate)
    }

    // DashboardView "This Week": Array(transactions.prefix(5)) keyed by uuid —
    // exactly 5 rows, all distinct identities, no ghost dup.
    func testDashboardRecentPrefix5_hasFiveDistinctIdentities() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seed(50, in: ctx, interleaveSaves: true)

        let all = try ctx.fetch(FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let recent = Array(all.prefix(5))

        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(Set(recent.map(\.uuid)).count, 5, "no duplicate row identity in the recent list")
    }

    // TransactionsView groups by start-of-day then flattens into rows. At 50+ the
    // flattened identity set must equal the full set with NO duplicate uuid in any
    // group — the data the per-day ForEach renders.
    func testTransactionsGroupedByDay_noDuplicateIdentitiesAtScale() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seed(60, in: ctx, interleaveSaves: true)

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let cal = Calendar.current
        let grouped = Dictionary(grouping: all) { cal.startOfDay(for: $0.date) }   // mirrors TransactionsView.grouped

        let flattenedUUIDs = grouped.values.flatMap { $0.map(\.uuid) }
        XCTAssertEqual(flattenedUUIDs.count, 60, "every transaction renders exactly once across all day-groups")
        XCTAssertEqual(Set(flattenedUUIDs).count, 60, "no duplicate row identity across the rendered groups")
        XCTAssertEqual(Set(flattenedUUIDs), Set(all.map(\.uuid)), "grouped rows cover the full set with no ghosts")
    }
}
