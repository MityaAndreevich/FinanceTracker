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

    static let appGroupID = "group.com.dmitrylogachev.vela"

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
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let dst = groupURL.appendingPathComponent("Vela.sqlite")
        guard !FileManager.default.fileExists(atPath: dst.path) else { return }

        // Default SwiftData location when no URL is specified in ModelConfiguration.
        guard let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }

        let src = supportDir.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: src.path) else { return }

        do {
            try FileManager.default.copyItem(at: src, to: dst)
            for suffix in ["-wal", "-shm"] {
                let s = URL(fileURLWithPath: src.path + suffix)
                let d = URL(fileURLWithPath: dst.path + suffix)
                if FileManager.default.fileExists(atPath: s.path) {
                    try FileManager.default.copyItem(at: s, to: d)
                }
            }
            print("[SharedModelContainer] Legacy store migrated → App Group.")
        } catch {
            print("[SharedModelContainer] ⚠️ Migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static func applyProtection(to url: URL) {
        try? (url as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }
}

// MARK: - App Group UserDefaults

extension UserDefaults {
    /// Shared defaults accessible from the main app, widget extension, and AppIntents.
    static let appGroup = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
}
