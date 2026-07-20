//
//  StorePreflightRepair.swift
//  FinanceTracker
//
//  The dangling-reference repair, at the only layer that can actually perform
//  it (design doc §7.4's documented fallback, promoted to the primary after
//  rehearsal): raw SQLite, BEFORE the container ever opens the file.
//
//  Why not in didMigrate: rehearsed against a field-identical damaged store
//  (MigrationRepairTests), assigning `tx.source = nil` through the V2 model
//  setter crashes — the NEW inverse (Source.transactions) makes SwiftData
//  materialize the OLD destination to unhook the back-reference, and the
//  destination row is exactly what doesn't exist (EXC_BREAKPOINT in
//  Transaction.source.setter, observed 2026-07-21). Reading the fault's
//  persistentModelID is safe; SETTING through a relationship with an inverse
//  is not. So the repair happens where no faults and no inverse maintenance
//  exist: two UPDATE statements on the closed store file.
//
//  Safety posture:
//    • Runs ONLY on the guarded migration path — after the §9.2 backup exists,
//      never before. A bad repair is recoverable by construction.
//    • Touches only foreign-key columns (`ZSOURCE`, `ZCATEGORY` on
//      `ZTRANSACTION`) — never schema, never Core Data metadata, never values.
//    • No-op by inspection on a healthy store (`WHERE … NOT IN` matches
//      nothing); idempotent for the same reason.
//    • didMigrate then VERIFIES (read-only, fault-safe) and THROWS if anything
//      dangling remains — feeding the §10 rollback ladder instead of crashing.
//

import Foundation
import SQLite3

enum StorePreflightRepair {

    enum RepairError: LocalizedError {
        case cannotOpen(String)
        case sqlFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpen(let m): return "preflight repair could not open store: \(m)"
            case .sqlFailed(let m): return "preflight repair SQL failed: \(m)"
            }
        }
    }

    /// Nil out foreign keys on ZTRANSACTION whose destination row no longer
    /// exists. Returns the number of repaired references. A missing store file
    /// or a store without the expected tables is a no-op (fresh installs,
    /// future layouts) — the didMigrate verifier remains the net behind this.
    @discardableResult
    static func repairDanglingReferences(storeURL: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return 0 }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw RepairError.cannotOpen(message)
        }
        defer { sqlite3_close(db) }

        func tableExists(_ name: String) -> Bool {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            sqlite3_bind_text(stmt, 1, name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            return sqlite3_step(stmt) == SQLITE_ROW
        }

        // Core Data naming: entity → Z<UPPERCASED>, to-one FK → Z<UPPERCASED>
        // column on the owner's table, primary key → Z_PK.
        guard tableExists("ZTRANSACTION") else { return 0 }

        var repaired = 0
        let repairs: [(column: String, destinationTable: String)] = [
            ("ZSOURCE", "ZSOURCE"),
            ("ZCATEGORY", "ZCATEGORY"),
        ]
        for repair in repairs where tableExists(repair.destinationTable) {
            let sql = """
            UPDATE ZTRANSACTION SET \(repair.column) = NULL \
            WHERE \(repair.column) IS NOT NULL \
            AND \(repair.column) NOT IN (SELECT Z_PK FROM \(repair.destinationTable));
            """
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw RepairError.sqlFailed(String(cString: sqlite3_errmsg(db)))
            }
            repaired += Int(sqlite3_changes(db))
        }

        // Fold the write back into the main file so the subsequent Core Data
        // open sees one consistent store regardless of its WAL handling.
        _ = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)

        if repaired > 0 {
            persistenceLog.notice("preflight repair: nullified \(repaired, privacy: .public) dangling reference(s)")
        }
        return repaired
    }
}
