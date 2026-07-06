//
//  SharedModelContainer.swift
//  FinanceTracker
//
//  Single ModelContainer backed by the App Group store so AppIntents (which
//  run in a separate OS process) can read/write the same SwiftData database
//  as the main app and the widget extension.
//

import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.dmitrylogachev.budgetcrab"

    static let schema = Schema([
        Transaction.self,
        Category.self,
        Source.self,
        MerchantCategoryLearning.self,
    ])

    // Lazily created on first access. Migration must happen before first access — see
    // migrateLegacyStoreIfNeeded(), called from FinanceTrackerApp.init().
    static let shared: ModelContainer = {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App Group '\(appGroupID)' not found in entitlements.")
        }
        // NOTE: filename intentionally kept as "Vela.sqlite" (the app's former name).
        // This is the on-disk store path inside the App Group — renaming it would
        // orphan existing user/test data. The display-name rename to "Budget Crab"
        // does not touch persistence. Do not rename without a data migration.
        let storeURL = groupURL.appendingPathComponent("Vela.sqlite")

        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            applyProtection(to: storeURL)
            return container
        } catch {
            fatalError("SharedModelContainer init failed at \(storeURL.lastPathComponent): \(error)")
        }
    }()

    // MARK: - Legacy migration

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

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let dst = groupURL.appendingPathComponent("Vela.sqlite") // legacy filename — see note above
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
            #if DEBUG
            print("[SharedModelContainer] Legacy store migrated → App Group.")
            #endif
        } catch {
            // Leave the flag unset so the next launch retries the migration.
            #if DEBUG
            print("[SharedModelContainer] ⚠️ Migration failed: \(error.localizedDescription)")
            #endif
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
        // throw and hit the `fatalError` above — crashing the intent and losing the user's
        // transaction. `.completeUntilFirstUserAuthentication` keeps the file encrypted at
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
