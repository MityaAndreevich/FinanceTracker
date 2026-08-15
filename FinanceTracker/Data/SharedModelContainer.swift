//
//  SharedModelContainer.swift
//  FinanceTracker
//
//  Single ModelContainer backed by the App Group store so AppIntents (which
//  run in a separate OS process) can read/write the same SwiftData database
//  as the main app. The widget never opens this store — it renders the baked
//  NetSnapshot from App Group defaults.
//
//  V2 (1.0.3): the container is no longer a bare lazy static. Opening the
//  store can now RUN A SCHEMA MIGRATION, so first access is orchestrated by
//  the guarded bootstrap below (design doc §9–§10): backup before the first
//  V2 open, an attempt sentinel around it, restore-from-backup on failure,
//  and a hard gate so a headless AppIntent can never be the process that
//  migrates. The old `fatalError` on open failure is gone — a failed
//  migration lands in a degraded-but-safe UI, never a crash loop.
//

import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.dmitrylogachev.budgetcrab"

    // MARK: - Sentinel keys (App Group defaults — visible to every process)

    /// Set only after a V2 open succeeded AND a sanity fetch answered.
    static let migrationCompleteKey = "v2MigrationComplete"
    /// Incremented before each V2 open attempt; cleared on success. A non-zero
    /// value at launch means a previous attempt died mid-migration.
    static let migrationAttemptKey = "v2MigrationAttemptCount"
    /// Set when a restore-from-backup ran; cleared when the user acknowledges
    /// the full-screen notice. No silent restores, ever.
    static let restorePendingNoticeKey = "v2RestorePendingNotice"

    static var isMigrationComplete: Bool {
        UserDefaults.appGroup.bool(forKey: migrationCompleteKey)
    }

    // MARK: - Schemas & locations

    /// The future-synced store (Vela.sqlite). CloudKit stays `.none` in 1.0.3 —
    /// this release ships the CloudKit-COMPATIBLE schema; the flip is 1.0.4.
    static let syncedSchema = Schema([
        Transaction.self, Category.self, Source.self, TransactionSplit.self,
    ])

    /// Local-only store (VelaLocal.sqlite). MerchantCategoryLearning's doc
    /// comment is a privacy promise — "NEVER leaves the device, no sync" — so
    /// it must not live in the store that will sync. Being non-synced is also
    /// what legally keeps its `@Attribute(.unique)`.
    static let localSchema = Schema([MerchantCategoryLearning.self])

    static let fullSchema = Schema([
        Transaction.self, Category.self, Source.self, TransactionSplit.self,
        MerchantCategoryLearning.self,
    ])

    static func groupURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    // NOTE: filename intentionally kept as "Vela.sqlite" (the app's former name).
    // This is the on-disk store path inside the App Group — renaming it would
    // orphan existing user/test data. Do not rename without a data migration.
    static func storeURL(groupURL: URL) -> URL {
        groupURL.appendingPathComponent("Vela.sqlite")
    }

    static func localStoreURL(groupURL: URL) -> URL {
        groupURL.appendingPathComponent("VelaLocal.sqlite")
    }

    static var storeFileExists: Bool {
        guard let groupURL = groupURL() else { return false }
        return FileManager.default.fileExists(atPath: storeURL(groupURL: groupURL).path)
    }

    /// Whether the launch sequence must run the pre-migration flow (backup +
    /// consent screen) before the store may be opened: an existing store that
    /// has not completed the V2 migration.
    static var needsGuardedMigration: Bool {
        storeFileExists && !isMigrationComplete
    }

    // MARK: - Accessors

    private static var current: ModelContainer?

    /// Graceful accessor for OUT-OF-LAUNCH-PATH callers (headless AppIntents).
    /// nil while the migration hasn't completed — the intent reports "open the
    /// app to finish updating" instead of becoming the process that migrates
    /// (inside an extension-sized memory budget, with no backup UI).
    static func readyContainer() -> ModelContainer? {
        if let current { return current }
        guard isMigrationComplete else { return nil }
        do {
            current = try openContainer()
            return current
        } catch {
            logSaveFailure("SharedModelContainer.readyContainer", error)
            return nil
        }
    }

    /// Post-bootstrap accessor for app UI paths. The launch gate guarantees
    /// bootstrap ran before any of these paths execute; reaching the trap
    /// means a code path bypassed the gate — a programmer error, not a user
    /// state, so it is loud.
    static var shared: ModelContainer {
        if let container = readyContainer() { return container }
        fatalError("SharedModelContainer accessed before the migration bootstrap completed — route launch through LaunchGateView.")
    }

    // MARK: - Guarded bootstrap (§10.2 ladder)

    enum BootstrapOutcome {
        case ready(ModelContainer, restoredFromBackup: Bool)
        /// The backup could not be written — the migration was NOT attempted.
        /// A migration without its safety net is never allowed to start.
        case backupFailed(Error)
        /// The ladder is exhausted. The store on disk is the restored pristine
        /// V1 copy; the app degrades to view/export (§10.4), never a crash.
        case failedPermanently(Error)
    }

    /// The one function allowed to trigger the V1→V2 migration. Called by the
    /// launch gate after the pre-migration screen resolves (or directly when
    /// there is nothing to migrate).
    @MainActor
    static func bootstrap() -> BootstrapOutcome {
        if let current { return .ready(current, restoredFromBackup: false) }
        let defaults = UserDefaults.appGroup

        // Fast path: already migrated (or a fresh install with no store file).
        if !needsGuardedMigration {
            let confirmedGoodBefore = isMigrationComplete
            do {
                let container = try openContainer()
                _ = try container.mainContext.fetchCount(FetchDescriptor<Transaction>())
                markComplete(defaults)
                current = container
                if confirmedGoodBefore {
                    // Second good launch — one full launch of soak has passed.
                    StoreBackup.deleteAfterConfirmedGood()
                }
                return .ready(container, restoredFromBackup: false)
            } catch {
                logSaveFailure("SharedModelContainer.bootstrap(fast)", error)
                return .failedPermanently(error)
            }
        }

        // Upgrading store: the guarded path.
        guard let groupURL = groupURL() else {
            return .failedPermanently(StoreBackup.BackupError.appGroupUnavailable)
        }
        let store = storeURL(groupURL: groupURL)

        // 1. The safety net, before anything opens the file. A thrown backup
        //    HALTS the migration (gap fix: disk-full must never silently
        //    proceed into a migration with no way back).
        do {
            try StoreBackup.writeIfAbsent(storeURL: store)
        } catch {
            logSaveFailure("SharedModelContainer.backup", error)
            return .backupFailed(error)
        }

        // 2. If a previous attempt died (crash/kill — the sentinel survived),
        //    restore the pristine V1 copy so failures never compound.
        var restored = false
        let priorAttempts = defaults.integer(forKey: migrationAttemptKey)
        if priorAttempts >= 1 {
            do {
                try StoreBackup.restore(storeURL: store, attempt: priorAttempts)
                restored = true
                defaults.set(true, forKey: restorePendingNoticeKey)
            } catch {
                logSaveFailure("SharedModelContainer.restore(prior)", error)
                return .failedPermanently(error)
            }
        }

        // 3. The in-process ladder: attempt → on throw, restore → retry once →
        //    on the second throw, stop (the floor). The sentinel is written
        //    BEFORE each attempt so a hard kill is indistinguishable from a
        //    throw on the next launch.
        var lastError: Error?
        for attempt in (priorAttempts + 1)...(priorAttempts + 2) {
            defaults.set(attempt, forKey: migrationAttemptKey)
            do {
                // Guarded path only: the backup above is what makes the
                // preflight SQL repair safe to run at all.
                let localStore = localStoreURL(groupURL: groupURL)
                let container = try openContainer(
                    storeURL: store, localStoreURL: localStore, preflightRepair: true
                )
                // Post-open sanity probe: the store must actually answer.
                _ = try container.mainContext.fetchCount(FetchDescriptor<Transaction>())
                markComplete(defaults)
                current = container
                return .ready(container, restoredFromBackup: restored)
            } catch {
                lastError = error
                logSaveFailure("SharedModelContainer.migrate(attempt \(attempt))", error)
                do {
                    try StoreBackup.restore(storeURL: store, attempt: attempt)
                    restored = true
                    defaults.set(true, forKey: restorePendingNoticeKey)
                } catch {
                    logSaveFailure("SharedModelContainer.restore(after-fail)", error)
                    return .failedPermanently(error)
                }
            }
        }
        return .failedPermanently(lastError ?? StoreBackup.BackupError.appGroupUnavailable)
    }

    private static func markComplete(_ defaults: UserDefaults) {
        defaults.set(true, forKey: migrationCompleteKey)
        defaults.removeObject(forKey: migrationAttemptKey)
    }

    // MARK: - Container opening

    /// V2 open with the migration plan attached. Fresh stores are created at
    /// V2 directly; V1 stores migrate through FinanceTrackerMigrationPlan.
    static func openContainer() throws -> ModelContainer {
        guard let groupURL = groupURL() else {
            throw StoreBackup.BackupError.appGroupUnavailable
        }
        let store = storeURL(groupURL: groupURL)
        let localStore = localStoreURL(groupURL: groupURL)
        let container = try openContainer(storeURL: store, localStoreURL: localStore)
        applyProtection(to: store)
        applyProtection(to: localStore)
        return container
    }

    /// URL-parameterized form — the production open above and the hermetic
    /// migration tests (temp-dir stores) go through the exact same code path,
    /// so the tests exercise the real two-configuration + migration-plan open.
    ///
    /// `preflightRepair` runs the raw-SQLite dangling-reference repair before
    /// the container touches the file. Passed ONLY on the guarded migration
    /// path — i.e. strictly after the §9.2 backup exists — never on the
    /// every-launch fast path.
    static func openContainer(
        storeURL store: URL, localStoreURL localStore: URL, preflightRepair: Bool = false
    ) throws -> ModelContainer {
        if preflightRepair {
            try StorePreflightRepair.repairDanglingReferences(storeURL: store)
            liftToDeclaredV1IfNeeded(storeURL: store)
        }
        let syncedConfig = ModelConfiguration(
            "synced", schema: syncedSchema, url: store, cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "local", schema: localSchema, url: localStore, cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: fullSchema,
            migrationPlan: FinanceTrackerMigrationPlan.self,
            configurations: [syncedConfig, localConfig]
        )
    }

    /// Lift a store OLDER than the declared V1 up to the declared V1 shape.
    ///
    /// WHY THIS EXISTS — the field bug of 2026-08-14.
    ///   `FinanceTrackerSchemaV1` is the **1.0.2** shape, not the 1.0.0 shape: it
    ///   declares `isPossibleDuplicate`, which was added on 2026-07-11, the day
    ///   AFTER 1.0.0 shipped. A store last written by 1.0.0 therefore matches
    ///   NEITHER version the plan knows, so `ModelContainer(for:migrationPlan:)`
    ///   throws `SwiftDataError` 1 — and the §10 ladder, working exactly as
    ///   designed, ran attempt→restore→retry→restore→floor in 188 ms and parked
    ///   the user on a terminal screen. Measured, not inferred: see
    ///   `outputs/BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`.
    ///
    /// WHY IT IS AN OPEN AND NOT A NEW SCHEMA VERSION
    ///   1.0.1 opened that same store successfully, because a PLANLESS open lets
    ///   SwiftData lightweight-migrate: it added the missing column itself
    ///   (measured, 0 → 1). The engine can do this; only the stage machinery
    ///   cannot, because it asserts a version match before it will start. So the
    ///   fix is one extra open, not a V0 stage — and a new stage would itself be
    ///   a migration that has to be right.
    ///
    /// SAFETY
    ///   • Guarded path ONLY (`preflightRepair == true`), which means strictly
    ///     after the §9.2 backup exists. This function WRITES (a lightweight
    ///     migration is a write), so it must never run before the safety net.
    ///   • Failure is swallowed on purpose: if the lift cannot help, behaviour is
    ///     byte-identical to before this function existed — the ladder runs and
    ///     the floor still catches it. It can only convert a failure into a
    ///     success, never the reverse.
    ///   • A no-op for stores already at V1 or later: measured at 86–99 ms
    ///     against 1.0.1 and 1.0.2-era stores, which then migrate as before.
    static func liftToDeclaredV1IfNeeded(storeURL store: URL) {
        let schema = Schema(versionedSchema: FinanceTrackerSchemaV1.self)
        let config = ModelConfiguration("v1-lift", schema: schema, url: store, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Force the open to complete before the container goes out of scope.
            // A fresh `ModelContext` rather than `mainContext`: this runs inside
            // the nonisolated `openContainer`, which the hermetic tests call
            // directly, and `mainContext` is main-actor isolated.
            let rows = try ModelContext(container).fetchCount(
                FetchDescriptor<FinanceTrackerSchemaV1.Transaction>())
            persistenceLog.notice("v1 lift: store opened at declared V1, \(rows, privacy: .public) row(s)")
        } catch {
            // Not a failure path — the ladder below is still the authority.
            let ns = error as NSError
            persistenceLog.notice(
                "v1 lift: skipped (\(ns.domain, privacy: .public)/\(ns.code, privacy: .public)) — continuing to the plan open"
            )
        }
    }

    /// The pre-migration export path (§9.4): open the UNMIGRATED store with
    /// the explicit V1 schema, read-only. `allowsSave: false` means it cannot
    /// mutate anything. Also the degraded floor's export path.
    ///
    /// ⚠️ CORRECTED 2026-08-14. This comment used to claim *"the schema matches
    /// the disk exactly, so this open can never trigger a migration"*. **That is
    /// false for any store older than the declared V1** — e.g. one last written
    /// by 1.0.0, which lacks `isPossibleDuplicate`. Such a store does not match,
    /// the read-only open THROWS, and the export fails.
    ///
    /// That made the failure worse than it looked: the degraded floor offers
    /// "Export my data" as the stranded user's only data-out route, and it was
    /// broken for exactly the population that reaches the floor. Callers on the
    /// floor must therefore handle the throw by lifting first — see
    /// `MigrationFloorView.prepareExport()`. Callers BEFORE the backup exists
    /// (the pre-migration screen) must not: no write may precede the safety net.
    static func openV1ReadOnly() throws -> ModelContainer {
        guard let groupURL = groupURL() else {
            throw StoreBackup.BackupError.appGroupUnavailable
        }
        let schema = Schema(versionedSchema: FinanceTrackerSchemaV1.self)
        let config = ModelConfiguration(
            "v1-readonly", schema: schema,
            url: storeURL(groupURL: groupURL),
            allowsSave: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Legacy sandbox → App Group migration (1.0.1, unchanged)

    /// One-time copy of the old sandbox store into the App Group on the first launch after
    /// this update. No-op if the App Group store already exists (migration already done or
    /// fresh install).
    static func migrateLegacyStoreIfNeeded() {
        // Cold-start win: the migration is one-time, but this ran an App Group
        // containerURL lookup (an XPC round-trip) on EVERY launch. Skip it entirely
        // once we've checked — the copy below is still guarded by fileExists, so the
        // flag only removes the redundant per-launch lookup, never a needed copy.
        let checkedKey = "legacyStoreMigrationChecked"
        guard !UserDefaults.standard.bool(forKey: checkedKey) else { return }
        // Mark complete only at definitive outcomes (nothing to migrate / copied),
        // never on a transient failure — otherwise a failed copy would orphan the
        // legacy store with no retry.
        func markChecked() { UserDefaults.standard.set(true, forKey: checkedKey) }

        guard let groupURL = groupURL() else { return }

        let dst = storeURL(groupURL: groupURL)
        guard !FileManager.default.fileExists(atPath: dst.path) else { markChecked(); return }

        // Default SwiftData location when no URL is specified in ModelConfiguration.
        guard let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }

        let src = supportDir.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: src.path) else { markChecked(); return }

        do {
            try FileManager.default.copyItem(at: src, to: dst)
            for suffix in ["-wal", "-shm"] {
                let s = URL(fileURLWithPath: src.path + suffix)
                let d = URL(fileURLWithPath: dst.path + suffix)
                if FileManager.default.fileExists(atPath: s.path) {
                    try FileManager.default.copyItem(at: s, to: d)
                }
            }
            markChecked()
            // Always compiled, both branches. Whether the store moved is the fact
            // that explains a whole class of later symptoms — "my data vanished",
            // a widget reading a different store, a migration re-running — and it
            // is unrecoverable after the fact: the flag and the file layout look
            // the same however this went. A DEBUG-only print made exactly the
            // builds users run the ones that recorded nothing.
            persistenceLog.notice("legacy store migrated to App Group")
        } catch {
            // Leave the flag unset so the next launch retries the migration.
            let ns = error as NSError
            persistenceLog.error(
                "legacy store migration to App Group FAILED (will retry next launch) domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) userInfo=\(String(describing: ns.userInfo), privacy: .public)"
            )
        }
    }

    // MARK: - Private

    private static func applyProtection(to url: URL) {
        // NOTE: must be `.completeUntilFirstUserAuthentication`, NOT `.complete`.
        // AddTransactionIntent (and the CategoryEntity/TransactionEntity queries) run
        // HEADLESS in a background process — no `openAppWhenRun` — and are auto-surfaced
        // via BudgetCrabShortcuts to Siri / Action Button / Shortcuts automations, which
        // can fire while the device is locked. `.complete` seals this store ~10s after
        // lock; the first `ModelContainer(for:)` open in that background process would then
        // throw — failing the intent and losing the user's transaction.
        // `.completeUntilFirstUserAuthentication` keeps the file encrypted at
        // rest but readable by background code after the first post-boot unlock (the widget
        // reads the App-Group snapshot, not this store, so it is unaffected either way).
        try? (url as NSURL).setResourceValue(URLFileProtection.completeUntilFirstUserAuthentication, forKey: .fileProtectionKey)
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }
}

// MARK: - App Group UserDefaults

extension UserDefaults {
    /// Shared defaults accessible from the main app, widget extension, and AppIntents.
    static let appGroup = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
}
