//
//  MigrationRepairTests.swift
//  FinanceTrackerTests
//
//  The V1→V2 migration's contract (design doc §7.5, §10):
//
//    • a damaged store (dangling source/category refs — produced by the V1
//      bug ITSELF, not by SQL surgery) migrates clean: references nullified,
//      every other byte of user data intact, row counts unchanged;
//    • a healthy store is a no-op (updatedAt untouched — the repair never
//      stamps rows as modified);
//    • the repair is idempotent;
//    • merchant learning survives the move to the local store via the handoff;
//    • restore-from-backup produces a byte-verified pristine store, preserves
//      evidence, never consumes the backup, and is safe to run twice.
//
//  Everything runs ON-DISK in temp directories — this bug class does not exist
//  in in-memory stores — through the SAME openContainer(storeURL:localStoreURL:)
//  path production uses, so the two-configuration + migration-plan open is
//  exercised for real, not simulated.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class MigrationRepairTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        // The handoff file lands in the real App Group (the production path) —
        // never leave one behind for the host app's next launch to import.
        if let group = try? StoreBackup.groupURL() {
            try? FileManager.default.removeItem(
                at: MerchantLearningHandoff.handoffURL(groupURL: group))
        }
    }

    private var storeURL: URL { tempDir.appendingPathComponent("Vela.sqlite") }
    private var localURL: URL { tempDir.appendingPathComponent("VelaLocal.sqlite") }

    // MARK: - V1 fixtures (the damage is made by the V1 bug itself)

    /// Builds a V1 on-disk store. `mutate` runs inside the V1 world — delete a
    /// Source there and the unenforced `.nullify` leaves the dangling ref,
    /// exactly as it happened in the field. The container is released before
    /// returning so the V2 open sees a closed store.
    private func makeV1Store(
        mutate: (ModelContext, FinanceTrackerSchemaV1.Transaction,
                 FinanceTrackerSchemaV1.Category, FinanceTrackerSchemaV1.Source) throws -> Void
    ) throws {
        let schema = Schema(versionedSchema: FinanceTrackerSchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)

        let category = FinanceTrackerSchemaV1.Category(name: "Food", kindRaw: "expense", order: 0)
        let source = FinanceTrackerSchemaV1.Source(name: "Visa")
        ctx.insert(category)
        ctx.insert(source)
        let tx = FinanceTrackerSchemaV1.Transaction(
            typeRaw: "expense", amountCents: 12_345, currency: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            category: category, source: source,
            note: "lunch", merchant: "Cafe",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        ctx.insert(tx)
        try ctx.save()

        try mutate(ctx, tx, category, source)
        // container + ctx go out of scope here → store closes.
    }

    /// Mirrors the production GUARDED path: preflight SQL repair runs before
    /// the container opens, exactly as bootstrap does after the backup.
    private func openV2() throws -> ModelContainer {
        try SharedModelContainer.openContainer(
            storeURL: storeURL, localStoreURL: localURL, preflightRepair: true
        )
    }

    // MARK: - §7.5 repair contract

    func testDirtyStore_DanglingSource_IsNullified_DataIntact() throws {
        try makeV1Store { ctx, _, _, source in
            // THE BUG: no inverse under V1 → deleting the Source leaves the
            // transaction's foreign key dangling on disk.
            ctx.delete(source)
            try ctx.save()
        }

        let container = try openV2()   // migration + didMigrate repair run here
        let ctx = ModelContext(container)
        let txs = try ctx.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(txs.count, 1, "row count must be unchanged by migration")
        let tx = try XCTUnwrap(txs.first)
        XCTAssertNil(tx.source, "the dangling source reference must be nullified")
        XCTAssertEqual(tx.amountCents, 12_345, "money data must be untouched")
        XCTAssertEqual(tx.merchant, "Cafe")
        XCTAssertEqual(tx.note, "lunch")
        XCTAssertEqual(tx.category?.name, "Food", "the intact category reference must survive")
    }

    func testDirtyStore_DanglingCategory_BecomesUncategorized() throws {
        try makeV1Store { ctx, _, category, _ in
            ctx.delete(category)
            try ctx.save()
        }

        let container = try openV2()
        let ctx = ModelContext(container)
        let tx = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Transaction>()).first)

        XCTAssertNil(tx.category, "the dangling category reference must be nullified (renders as Uncategorized)")
        XCTAssertEqual(tx.source?.name, "Visa", "the intact source reference must survive")
        XCTAssertEqual(tx.amountCents, 12_345)
    }

    func testCleanStore_MigrationIsANoOpOnUserData() throws {
        try makeV1Store { _, _, _, _ in }   // healthy — no mutation

        let container = try openV2()
        let ctx = ModelContext(container)
        let tx = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Transaction>()).first)

        XCTAssertEqual(tx.updatedAt, Date(timeIntervalSince1970: 1_700_000_000),
                       "migration must never bump updatedAt — the user didn't edit anything")
        XCTAssertNotNil(tx.category)
        XCTAssertNotNil(tx.source)
        XCTAssertEqual(tx.amountCents, 12_345)

        // The preflight repair reports zero on a healthy (now-migrated) store
        // and stays zero on a second run (no-op + idempotence), and the
        // read-only verifier agrees.
        XCTAssertEqual(try StorePreflightRepair.repairDanglingReferences(storeURL: storeURL), 0,
                       "a clean store must repair nothing")
        XCTAssertEqual(try StorePreflightRepair.repairDanglingReferences(storeURL: storeURL), 0,
                       "the repair must be idempotent")
        XCTAssertNoThrow(try StoreRepair.verifyNoDanglingReferences(in: ctx))
    }

    func testDirtyStore_RepairIsIdempotentAfterMigration() throws {
        try makeV1Store { ctx, _, _, source in
            ctx.delete(source)
            try ctx.save()
        }

        let container = try openV2()
        let ctx = ModelContext(container)
        // The migration already repaired; a second preflight pass finds
        // nothing and the verifier is clean.
        XCTAssertEqual(try StorePreflightRepair.repairDanglingReferences(storeURL: storeURL), 0)
        XCTAssertNoThrow(try StoreRepair.verifyNoDanglingReferences(in: ctx))
    }

    // MARK: - Merchant-learning handoff (§7.2)

    func testMerchantLearning_SurvivesToTheLocalStore() throws {
        let schema = Schema(versionedSchema: FinanceTrackerSchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = ModelContext(container)
            let cat = FinanceTrackerSchemaV1.Category(name: "Food", kindRaw: "expense", order: 0)
            ctx.insert(cat)
            ctx.insert(FinanceTrackerSchemaV1.MerchantCategoryLearning(
                merchantNormalized: "starbucks", categoryName: "Food", useCount: 7))
            try ctx.save()
        }

        let container = try openV2()   // willMigrate exfiltrates to the sidecar
        let ctx = ModelContext(container)
        MerchantLearningHandoff.importIfPresent(into: ctx)

        let learned = try ctx.fetch(FetchDescriptor<MerchantCategoryLearning>())
        XCTAssertEqual(learned.count, 1, "the learning row must survive into the local store")
        XCTAssertEqual(learned.first?.merchantNormalized, "starbucks")
        XCTAssertEqual(learned.first?.useCount, 7)

        // Crash-window replay: a second import (file already deleted) is a
        // no-op; if the file had survived, the upsert is row-stable anyway.
        MerchantLearningHandoff.importIfPresent(into: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<MerchantCategoryLearning>()), 1)
    }

    // MARK: - §10.3 rollback / restore

    func testRestore_ProducesTheBackedUpBytes_KeepsEvidence_AndIsRepeatable() throws {
        // A store triple with known contents (raw bytes are all the restore
        // machinery sees — no SwiftData needed for this contract).
        let original = Data("PRISTINE-V1-STORE".utf8)
        let wal = Data("WAL".utf8)
        try original.write(to: storeURL)
        try wal.write(to: URL(fileURLWithPath: storeURL.path + "-wal"))

        try StoreBackup.writeIfAbsent(storeURL: storeURL, root: tempDir)
        XCTAssertTrue(StoreBackup.backupExists(root: tempDir))

        // A second write must NOT overwrite the pristine backup (§9.2).
        try Data("DAMAGED".utf8).write(to: storeURL)
        try StoreBackup.writeIfAbsent(storeURL: storeURL, root: tempDir)

        // Restore attempt 1: bytes come back, damage becomes evidence.
        try StoreBackup.restore(storeURL: storeURL, attempt: 1, root: tempDir)
        XCTAssertEqual(try Data(contentsOf: storeURL), original,
                       "restore must produce the byte-identical pristine store")
        let evidence = tempDir
            .appendingPathComponent(StoreBackup.diagnosticsDirectoryName)
            .appendingPathComponent("failed-v2-1")
            .appendingPathComponent("Vela.sqlite")
        XCTAssertEqual(try Data(contentsOf: evidence), Data("DAMAGED".utf8),
                       "the damaged store is evidence — moved aside, never deleted")
        XCTAssertTrue(StoreBackup.backupExists(root: tempDir),
                      "restore must never consume the backup")

        // Damage again, restore again (attempt 2) — idempotent by construction.
        try Data("DAMAGED-AGAIN".utf8).write(to: storeURL)
        try StoreBackup.restore(storeURL: storeURL, attempt: 2, root: tempDir)
        XCTAssertEqual(try Data(contentsOf: storeURL), original)
        XCTAssertTrue(StoreBackup.backupExists(root: tempDir))

        // A restored store then migrates normally end-to-end: overwrite with a
        // REAL V1 store, back it up, restore it, and open V2 on it.
        StoreBackup.deleteAfterConfirmedGood(root: tempDir)
        try FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        try makeV1Store { _, _, _, _ in }
        try StoreBackup.writeIfAbsent(storeURL: storeURL, root: tempDir)
        try StoreBackup.restore(storeURL: storeURL, attempt: 1, root: tempDir)
        let container = try openV2()
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Transaction>()), 1,
                       "a restored store must migrate and answer queries")
    }
}
