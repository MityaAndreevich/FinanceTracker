//
//  StoreBackup.swift
//  FinanceTracker
//
//  The pre-migration safety belt (design doc §9.2, §10.3): an immutable
//  file-level copy of the store triple, made BEFORE the V2 schema ever opens
//  the file, and the restore path that turns a failed migration back into a
//  pristine V1 store.
//
//  Invariants:
//    • The backup is written AT MOST ONCE, from the pre-V2 store, while no
//      connection is open — and never overwritten by a later (possibly
//      damaged) state.
//    • The backup is immutable for its whole life (read-only after the copy)
//      and restore COPIES from it, never moves — so restore is idempotent and
//      safe to run twice by construction.
//    • A failed backup write must HALT the migration — a migration without
//      its safety net is never allowed to start.
//    • Restore MOVES the damaged files aside into a per-attempt diagnostics
//      directory — evidence is preserved, never deleted.
//

import Foundation

enum StoreBackup {

    struct Manifest: Codable, Equatable {
        let appVersion: String
        let createdAt: Date
        /// Byte sizes per store file — the restore-verification checksum.
        let files: [String: Int]
    }

    enum BackupError: LocalizedError {
        case appGroupUnavailable
        case verificationFailed(file: String)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable: return "App Group container unavailable"
            case .verificationFailed(let file): return "Restored \(file) does not match the backup manifest"
            }
        }
    }

    static let backupDirectoryName = "Backups/pre-v2"
    static let diagnosticsDirectoryName = "Diagnostics"
    static let manifestName = "manifest.json"

    // MARK: - Locations

    static func groupURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID
        ) else { throw BackupError.appGroupUnavailable }
        return url
    }

    /// `root` overrides the App Group container (hermetic tests use a temp dir).
    static func backupDirectory(root: URL? = nil) throws -> URL {
        try (root ?? groupURL()).appendingPathComponent(backupDirectoryName, isDirectory: true)
    }

    /// The store triple: main file + WAL + SHM (whichever exist).
    static func storeFileNames(storeURL: URL) -> [String] {
        let base = storeURL.lastPathComponent
        return [base, base + "-wal", base + "-shm"]
    }

    static func backupExists(root: URL? = nil) -> Bool {
        guard let dir = try? backupDirectory(root: root) else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(manifestName).path)
    }

    // MARK: - Write (§9.2)

    /// Copy the store triple + manifest into Backups/pre-v2, once. Throws on
    /// any failure — the caller must treat a thrown backup as "do NOT migrate".
    static func writeIfAbsent(storeURL: URL, root: URL? = nil) throws {
        guard !backupExists(root: root) else { return }   // a previous launch already made it

        let fm = FileManager.default
        let dir = try backupDirectory(root: root)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var sizes: [String: Int] = [:]
        for name in storeFileNames(storeURL: storeURL) {
            let src = storeURL.deletingLastPathComponent().appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }   // WAL/SHM may be absent
            let dst = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }  // partial prior write
            try fm.copyItem(at: src, to: dst)
            sizes[name] = (try fm.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0
            try? fm.setAttributes([.immutable: true], ofItemAtPath: dst.path)
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let manifest = Manifest(appVersion: version, createdAt: Date(), files: sizes)
        let data = try JSONEncoder().encode(manifest)
        // Manifest is written LAST: its presence is the "backup complete" marker.
        try data.write(to: dir.appendingPathComponent(manifestName), options: .atomic)
        // The live store is excluded from device backup (privacy posture in
        // SharedModelContainer.applyProtection); its safety copy follows suit.
        try? (dir as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

        persistenceLog.notice("pre-V2 backup written: \(sizes.count, privacy: .public) file(s)")
    }

    // MARK: - Restore (§10.3)

    /// Move the damaged store aside (evidence), copy the pristine backup back,
    /// verify byte sizes against the manifest. Idempotent: the backup is never
    /// consumed, and per-attempt diagnostics directories never collide.
    static func restore(storeURL: URL, attempt: Int, root: URL? = nil) throws {
        let fm = FileManager.default
        let dir = try backupDirectory(root: root)
        let manifestURL = dir.appendingPathComponent(manifestName)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))

        // 1. Evidence: move the current (damaged) files aside, never delete.
        let diagnostics = try (root ?? groupURL())
            .appendingPathComponent(diagnosticsDirectoryName, isDirectory: true)
            .appendingPathComponent("failed-v2-\(attempt)", isDirectory: true)
        try fm.createDirectory(at: diagnostics, withIntermediateDirectories: true)
        for name in storeFileNames(storeURL: storeURL) {
            let current = storeURL.deletingLastPathComponent().appendingPathComponent(name)
            guard fm.fileExists(atPath: current.path) else { continue }
            let dst = diagnostics.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.moveItem(at: current, to: dst)
        }

        // 2. Copy (never move) the backup into place — the backup survives for
        //    the next rung of the ladder.
        for (name, expectedSize) in manifest.files {
            let src = dir.appendingPathComponent(name)
            let dst = storeURL.deletingLastPathComponent().appendingPathComponent(name)
            try fm.copyItem(at: src, to: dst)
            try? fm.setAttributes([.immutable: false], ofItemAtPath: dst.path)

            // 3. Verify against the manifest.
            let restoredSize = (try fm.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? -1
            guard restoredSize == expectedSize else {
                throw BackupError.verificationFailed(file: name)
            }
        }

        persistenceLog.notice("pre-V2 backup restored (attempt \(attempt, privacy: .public))")
    }

    // MARK: - Retention (§9.2)

    /// Called on the SECOND good V2 launch (one full launch of soak) and by the
    /// 1.0.4 sweep. Clears the immutable bits, then removes the directory.
    static func deleteAfterConfirmedGood(root: URL? = nil) {
        guard let dir = try? backupDirectory(root: root) else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return }
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files { try? fm.setAttributes([.immutable: false], ofItemAtPath: f.path) }
        }
        try? fm.removeItem(at: dir)
        persistenceLog.notice("pre-V2 backup deleted after confirmed-good launch")
    }
}
