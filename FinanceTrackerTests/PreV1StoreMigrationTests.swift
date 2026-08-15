//
//  PreV1StoreMigrationTests.swift
//  FinanceTrackerTests
//
//  The regression test for the field bug of 2026-08-14: a store last written by
//  1.0.0 could not be migrated at all, and the user was parked on the terminal
//  floor screen (`outputs/BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`).
//
//  WHY A CAPTURED FIXTURE AND NOT A HAND-BUILT STORE
//    The bug is a mismatch between the schema we DECLARE and what a shipped
//    BINARY actually wrote. Any store this test constructs from today's model
//    types would be, by definition, the shape we already believe in — it could
//    not reproduce a disagreement with a real build. `Fixtures/StoreV1_0_0` was
//    produced the only way that can: check out the 1.0.0-era commit (`1e9b20b`,
//    2026-07-10, the last commit before `isPossibleDuplicate` was added the
//    following day), build it, run it on an erased simulator with `--demo-mode`,
//    and capture the store it wrote. 33 transactions, 635473 cents, no
//    `ZISPOSSIBLEDUPLICATE` column.
//
//    This fixture is the seed of the per-shipped-version corpus proposed in
//    `outputs/PROPOSAL_STORE_FIXTURE_CORPUS_2026-08-14.md`. One fixture catches
//    one bug; the corpus is what would have caught this one BEFORE 1.0.3.
//

import XCTest
import SwiftData
import SQLite3
@testable import FinanceTracker

@MainActor
final class PreV1StoreMigrationTests: XCTestCase {

    /// Repo-relative lookup from this source file, deliberately NOT a bundle
    /// resource: whether a `.sqlite` lands in the test bundle depends on target
    /// membership, and a fixture that silently fails to copy would make this
    /// test pass against nothing — the silent-success class this project has
    /// been bitten by repeatedly (`AUDIT_SILENT_SUCCESS_CLASS_2026-08-09`).
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // FinanceTrackerTests/
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("StoreFixtures/StoreV1_0_0", isDirectory: true)
    }

    /// Copy the fixture triple into a fresh temp directory. Never open the
    /// fixture in place — an open MIGRATES it, which would make the second run
    /// of this test meaningless.
    private func stagedStoreURL() throws -> URL {
        let fm = FileManager.default
        let source = fixtureDirectory
        // A missing fixture must FAIL, never skip. An XCTSkip here would report
        // green while verifying nothing.
        XCTAssertTrue(fm.fileExists(atPath: source.appendingPathComponent("Vela.sqlite").path),
                      "fixture missing at \(source.path) — this test verifies nothing without it")
        let stage = fm.temporaryDirectory.appendingPathComponent("prev1-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        for name in ["Vela.sqlite", "Vela.sqlite-shm", "Vela.sqlite-wal"] {
            let src = source.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: stage.appendingPathComponent(name))
            }
        }
        return stage.appendingPathComponent("Vela.sqlite")
    }

    /// The premise. If this ever fails, the fixture has been migrated in place
    /// or replaced, and every other assertion here is worthless.
    func test_fixture_isOlderThanDeclaredV1() throws {
        let store = try stagedStoreURL()
        let columns = try sqliteColumns(of: "ZTRANSACTION", in: store)
        XCTAssertFalse(columns.contains("ZISPOSSIBLEDUPLICATE"),
                       "fixture is supposed to PREDATE the isPossibleDuplicate column")
        XCTAssertTrue(columns.contains("ZAMOUNTCENTS"), "fixture does not look like our store at all")
    }

    /// THE REGRESSION. Before the fix this threw `SwiftDataError` 1 on every
    /// attempt, which is what stranded the user on the floor.
    func test_preV1Store_opensThroughTheGuardedPath() throws {
        let store = try stagedStoreURL()
        let local = store.deletingLastPathComponent().appendingPathComponent("VelaLocal.sqlite")

        let container = try SharedModelContainer.openContainer(
            storeURL: store, localStoreURL: local, preflightRepair: true
        )
        let count = try container.mainContext.fetchCount(FetchDescriptor<Transaction>())
        XCTAssertEqual(count, 33, "every transaction the 1.0.0 build wrote must survive the migration")
    }

    /// Migrating must not quietly lose or alter money. Counts alone would pass
    /// if the rows arrived empty.
    func test_preV1Store_preservesAmountsAndLinks() throws {
        let store = try stagedStoreURL()
        let local = store.deletingLastPathComponent().appendingPathComponent("VelaLocal.sqlite")

        let container = try SharedModelContainer.openContainer(
            storeURL: store, localStoreURL: local, preflightRepair: true
        )
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.reduce(0) { $0 + $1.amountCents }, 635473,
                       "total amount changed across the migration")
        XCTAssertEqual(Set(transactions.map(\.uuid)).count, 33, "uuids collided or were regenerated")
        XCTAssertTrue(transactions.allSatisfy { $0.category != nil },
                      "category links were dropped by the migration")
    }

    /// The lift is what makes the above work, and it must stay harmless on a
    /// store that is ALREADY at or past the declared V1 — running it twice is
    /// the cheapest way to assert that.
    func test_lift_isIdempotent() throws {
        let store = try stagedStoreURL()
        SharedModelContainer.liftToDeclaredV1IfNeeded(storeURL: store)
        let afterFirst = try sqliteColumns(of: "ZTRANSACTION", in: store)
        XCTAssertTrue(afterFirst.contains("ZISPOSSIBLEDUPLICATE"), "the lift did not reach declared V1")

        SharedModelContainer.liftToDeclaredV1IfNeeded(storeURL: store)
        let local = store.deletingLastPathComponent().appendingPathComponent("VelaLocal.sqlite")
        let container = try SharedModelContainer.openContainer(
            storeURL: store, localStoreURL: local, preflightRepair: true
        )
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Transaction>()), 33)
    }

    // MARK: - Raw schema read (no SwiftData — reading the DISK, not our belief about it)

    /// Reads column names via the SQLite C API. NOT `Process` — these tests run
    /// on iOS, where there is no `/usr/bin/sqlite3` to shell out to.
    private func sqliteColumns(of table: String, in store: URL) throws -> Set<String> {
        var db: OpaquePointer?
        guard sqlite3_open_v2(store.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            XCTFail("could not open \(store.lastPathComponent) for reading")
            return []
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &statement, nil) == SQLITE_OK else {
            XCTFail("PRAGMA table_info(\(table)) failed to prepare")
            return []
        }
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: raw))
            }
        }
        return names
    }
}
