//
//  ShippedStoreShapeTests.swift
//  FinanceTrackerTests
//
//  One assertion per SHIPPED VERSION: the store that version's binary actually
//  wrote must still open under the CURRENT schema plan.
//
//  WHY THIS SUITE EXISTS
//    `FinanceTrackerSchemaV1` turned out to describe the 1.0.2 shape, not the
//    1.0.0 shape, and stores last written by 1.0.0 could not be migrated at all
//    — their owners were stranded on a terminal screen for two releases. It went
//    unnoticed because every fixture we had came from a version that works, so
//    every drill validated the path that works
//    (`outputs/BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`).
//
//    Declared schema versions are checked against each other. Nothing checked
//    them against what a released binary put on disk. This does.
//
//  HOW A FIXTURE IS MADE
//    `scripts/capture-store-fixture.sh <commit> <label>` — build the shipping
//    commit, run it on an erased simulator, capture the store it writes. Each
//    fixture carries a MANIFEST.md recording the commit, version, build, capture
//    date, counts and raw columns. Capture belongs to SHIPPING version N, while
//    the binary that writes that store still exists and still builds.
//
//  WHAT IT WOULD HAVE CAUGHT
//    The 2026-08-14 field bug, before 1.0.3 shipped.
//

import XCTest
import SwiftData
import SQLite3
@testable import FinanceTracker

@MainActor
final class ShippedStoreShapeTests: XCTestCase {

    /// Every shipped version whose store shape a user can still be sitting on.
    ///
    /// This list is DELIBERATELY hard-coded rather than derived from whatever
    /// directories happen to exist. A directory scan silently shrinks coverage
    /// when a fixture is deleted or fails to capture, and reports green for the
    /// versions that remain — the silent-success class this project keeps
    /// getting caught by (`AUDIT_SILENT_SUCCESS_CLASS_2026-08-09`). A missing
    /// fixture must FAIL, loudly, in `test_everyShippedVersionHasAFixture`.
    private static let shippedVersions = ["V1_0_0", "V1_0_1", "V1_0_2", "V1_0_3", "V1_0_4"]

    /// Rows written by `--demo-mode` at capture time. Identical across versions
    /// because the demo seed is deterministic — which is exactly why it is the
    /// seed the capture script uses.
    private static let expectedTransactions = 33
    private static let expectedAmountSum = 635473

    private func fixtureDirectory(_ label: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // FinanceTrackerTests/
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("StoreFixtures/Store\(label)", isDirectory: true)
    }

    /// Stage a COPY. Opening a fixture in place migrates it, which would destroy
    /// the shape the fixture exists to preserve — silently, and only visibly on
    /// the *second* run of the suite.
    private func stage(_ label: String) throws -> URL {
        let fm = FileManager.default
        let source = fixtureDirectory(label)
        let stage = fm.temporaryDirectory
            .appendingPathComponent("shipped-\(label)-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        for name in ["Vela.sqlite", "Vela.sqlite-shm", "Vela.sqlite-wal"] {
            let src = source.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: stage.appendingPathComponent(name))
            }
        }
        return stage.appendingPathComponent("Vela.sqlite")
    }

    // MARK: - The corpus is complete

    func test_everyShippedVersionHasAFixture() {
        for label in Self.shippedVersions {
            let dir = fixtureDirectory(label)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: dir.appendingPathComponent("Vela.sqlite").path),
                "no fixture for \(label). Capture it: scripts/capture-store-fixture.sh <commit> \(label)"
            )
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: dir.appendingPathComponent("MANIFEST.md").path),
                "\(label) has a store but no MANIFEST — an unlabelled .sqlite is not evidence of anything"
            )
        }
    }

    // MARK: - Every shipped shape opens under the CURRENT plan

    /// The guarded path, because that is the one that must tolerate any shipped
    /// shape: it is what runs for every store that has not completed the V2
    /// migration, and it is where the 1.0.0 stores died.
    private func assertOpens(_ label: String,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let store = try stage(label)
        let local = store.deletingLastPathComponent().appendingPathComponent("VelaLocal.sqlite")

        let container = try SharedModelContainer.openContainer(
            storeURL: store, localStoreURL: local, preflightRepair: true
        )
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, Self.expectedTransactions,
                       "\(label): transactions lost opening a shipped store", file: file, line: line)
        XCTAssertEqual(transactions.reduce(0) { $0 + $1.amountCents }, Self.expectedAmountSum,
                       "\(label): amounts changed opening a shipped store", file: file, line: line)
        XCTAssertTrue(transactions.allSatisfy { $0.category != nil },
                      "\(label): category links dropped", file: file, line: line)
    }

    func test_v1_0_0_storeOpens() throws { try assertOpens("V1_0_0") }
    func test_v1_0_1_storeOpens() throws { try assertOpens("V1_0_1") }
    func test_v1_0_2_storeOpens() throws { try assertOpens("V1_0_2") }
    func test_v1_0_3_storeOpens() throws { try assertOpens("V1_0_3") }
    func test_v1_0_4_storeOpens() throws { try assertOpens("V1_0_4") }

    // MARK: - The corpus actually spans distinct shapes

    /// A corpus of five identical stores would pass everything above and prove
    /// nothing. These are the shape boundaries as captured, and they are the
    /// reason the 1.0.0 case exists at all:
    ///
    ///   1.0.0  — no `ZISPOSSIBLEDUPLICATE`, no `ZTRANSACTIONSPLIT`  (pre-V1)
    ///   1.0.1  — has the column, no split table                     (declared V1)
    ///   1.0.2  — has the column, no split table                     (declared V1)
    ///   1.0.3+ — has both                                           (V2)
    func test_fixturesSpanDistinctShapes() throws {
        let v100 = try columns(of: "ZTRANSACTION", in: try stage("V1_0_0"))
        XCTAssertFalse(v100.contains("ZISPOSSIBLEDUPLICATE"),
                       "the 1.0.0 fixture no longer predates the declared V1 — the regression it guards is untested")

        let v101 = try columns(of: "ZTRANSACTION", in: try stage("V1_0_1"))
        XCTAssertTrue(v101.contains("ZISPOSSIBLEDUPLICATE"),
                      "the 1.0.1 fixture should carry the column added on 2026-07-11")

        XCTAssertTrue(try tableExists("ZTRANSACTIONSPLIT", in: try stage("V1_0_3")),
                      "the 1.0.3 fixture should be V2-shaped — that is the shape V3 will meet")
        XCTAssertTrue(try tableExists("ZTRANSACTIONSPLIT", in: try stage("V1_0_4")),
                      "the 1.0.4 fixture should be V2-shaped")
    }

    // MARK: - Raw reads (the DISK, not our belief about it)

    private func columns(of table: String, in store: URL) throws -> Set<String> {
        try query("PRAGMA table_info(\(table));", in: store, column: 1)
    }

    private func tableExists(_ name: String, in store: URL) throws -> Bool {
        try query("SELECT name FROM sqlite_master WHERE type='table' AND name='\(name)';",
                  in: store, column: 0).isEmpty == false
    }

    private func query(_ sql: String, in store: URL, column: Int32) throws -> Set<String> {
        var db: OpaquePointer?
        guard sqlite3_open_v2(store.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            XCTFail("could not open \(store.lastPathComponent)")
            return []
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            XCTFail("could not prepare: \(sql)")
            return []
        }
        defer { sqlite3_finalize(statement) }
        var out: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, column) { out.insert(String(cString: raw)) }
        }
        return out
    }
}
