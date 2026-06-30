import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Bug 22: transaction loss / replacement on restart
//
// Device test #7 reported that after adding N transactions and restarting the
// app, some original rows disappeared and were replaced with duplicates of the
// newest entry (the visible total stayed correct because it is computed off the
// @Query array, not the buggy ForEach). The UI defect was a position-keyed
// ForEach (id: \.offset) in DashboardView — fixed separately.
//
// This integration test pins the OTHER half of the guarantee: the SwiftData
// store itself round-trips every row, with stable identity, across a full
// container teardown + reopen at the same on-disk URL (the closest a test can
// get to a real process restart). An in-memory store cannot prove this — it
// dies with the container — so this uses a real file-backed store.

@Suite("Transaction persistence across restart")
@MainActor
struct TransactionPersistenceTests {

    /// Builds a file-backed container at `url`. Each call is an independent
    /// container instance, so releasing one and opening another at the same URL
    /// simulates an app restart against the same on-disk database.
    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([
            Transaction.self, FinanceTracker.Category.self,
            Source.self, MerchantCategoryLearning.self,
        ])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("persist-\(UUID().uuidString).sqlite")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    @Test func testTransactionPersistence_acrossModelContainerRestart() throws {
        let url = tempStoreURL()
        defer { removeStore(at: url) }

        // Distinct amounts so a "replaced with duplicate of newest" regression is
        // detectable both by identity AND by the multiset of amounts.
        let amounts = [111, 222, 333, 444, 555]
        var insertedUUIDs: [UUID] = []

        // --- Session 1: insert 5 distinct transactions, then drop the container.
        try autoreleasepool {
            let container = try makeContainer(at: url)
            let ctx = ModelContext(container)

            let category = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
            ctx.insert(category)

            for (i, cents) in amounts.enumerated() {
                let tx = Transaction(
                    typeRaw: "expense",
                    amountCents: cents,
                    currency: "USD",
                    date: Date().addingTimeInterval(TimeInterval(i)), // strictly increasing → distinct "newest"
                    category: category,
                    merchant: "merchant-\(cents)"
                )
                ctx.insert(tx)
                insertedUUIDs.append(tx.uuid)
            }
            try ctx.save()
        }

        // --- Session 2: reopen the same store (simulated restart) and verify.
        let container2 = try makeContainer(at: url)
        let ctx2 = ModelContext(container2)
        let reloaded = try ctx2.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .forward)])
        )

        // No missing, no duplicate rows.
        #expect(reloaded.count == amounts.count, "every inserted transaction must survive a restart")

        // Identity is stable — same uuids, all distinct (no collapse onto one row).
        let reloadedUUIDs = Set(reloaded.map(\.uuid))
        #expect(reloadedUUIDs.count == amounts.count, "no two rows may share an identity after reload")
        #expect(reloadedUUIDs == Set(insertedUUIDs), "reloaded uuids must match the originals exactly")

        // The multiset of amounts is preserved — not all replaced by the newest.
        #expect(reloaded.map(\.amountCents).sorted() == amounts.sorted(),
                "amounts must round-trip unchanged — no row replaced by a duplicate of the newest")

        // And the newest entry did not overwrite earlier ones.
        let distinctAmounts = Set(reloaded.map(\.amountCents))
        #expect(distinctAmounts.count == amounts.count, "each original amount remains distinct after restart")
    }
}
