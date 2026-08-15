//
//  PreV1StoreDebugSeed.swift
//  FinanceTracker
//
//  DEBUG seam: put a store OLDER than the declared V1 schema in the App Group,
//  so the 1.0.0-upgrade path can be driven end-to-end by a UI test.
//
//  WHY THIS EXISTS
//    The field bug of 2026-08-14 (`BUG_MIGRATION_FLOOR_1_0_0_STORES`) needed a
//    store written by a 1.0.0-era BINARY to reproduce. Verifying the floor
//    screen's escape hatch therefore required manual setup — install an old
//    build, launch it, capture the store — so the check could not live in the
//    suite, and I deleted the scratch test rather than leave a non-hermetic
//    member in it. That is exactly how a fixed bug becomes permanently
//    untested. This seam closes that gap.
//
//  WHY IT GENERATES RATHER THAN SHIPS A FIXTURE
//    The captured fixture (`FinanceTrackerTests/Fixtures/StoreV1_0_0`) is
//    EVIDENCE about a released binary and belongs to the unit tests. Bundling it
//    in the app to reach a UI test would put a store file in the Release binary
//    for every user. So this writes an equivalent shape from an explicit V0
//    schema instead: same property (older than declared V1 — no
//    `isPossibleDuplicate`), no payload in the shipped app.
//
//    The two are NOT interchangeable, and the distinction matters:
//      • the fixture proves what 1.0.0 ACTUALLY wrote — it can disagree with us;
//      • this seam only reproduces the shape we BELIEVE 1.0.0 wrote.
//    Never let this replace the fixture in the unit tests.
//
//  The whole file is `#if DEBUG`: a Release build cannot seed anything from a
//  stray launch argument.
//

#if DEBUG
import Foundation
import SwiftData

/// The V1 shape MINUS `isPossibleDuplicate` — i.e. the shape 1.0.0 shipped with,
/// before `c1d59e4` added that property on 2026-07-11.
enum DebugSchemaV0: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(0, 9, 0) }

    static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Source.self]
    }

    @Model
    final class Transaction {
        @Attribute(.unique) var uuid: UUID
        var typeRaw: String
        var amountCents: Int
        var currency: String
        var date: Date
        var taxCents: Int?
        var note: String?
        var merchant: String?
        var recurrenceRaw: String?
        var isDemo: Bool = false
        // NO isPossibleDuplicate — that is the entire point of this schema.
        @Relationship(deleteRule: .nullify) var category: Category
        @Relationship(deleteRule: .nullify) var source: Source?
        var createdAt: Date
        var updatedAt: Date

        init(uuid: UUID = UUID(), typeRaw: String, amountCents: Int, currency: String,
             date: Date, category: Category, createdAt: Date = .now, updatedAt: Date = .now) {
            self.uuid = uuid
            self.typeRaw = typeRaw
            self.amountCents = amountCents
            self.currency = currency
            self.date = date
            self.category = category
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class Category {
        @Attribute(.unique) var uuid: UUID
        var name: String
        var nameKey: String?
        var nameCustom: String?
        var kindRaw: String
        var icon: String?
        var order: Int
        var isPrimary: Bool = true

        init(uuid: UUID = UUID(), name: String, kindRaw: String, order: Int) {
            self.uuid = uuid
            self.name = name
            self.kindRaw = kindRaw
            self.order = order
        }
    }

    @Model
    final class Source {
        @Attribute(.unique) var uuid: UUID
        var name: String
        var note: String?
        var isActive: Bool = true

        init(uuid: UUID = UUID(), name: String) {
            self.uuid = uuid
            self.name = name
        }
    }
}

enum PreV1StoreDebugSeed {

    static let argument = "--seed-pre-v1-store"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /// Row count written by the seam. Small on purpose: this drives a UI flow,
    /// not a performance measurement.
    static let transactionCount = 12

    /// Replace whatever is in the App Group with a freshly written V0 store, and
    /// clear the migration sentinels so the next launch takes the GUARDED path.
    ///
    /// Must run before `LaunchGateView.decide()` reads `needsGuardedMigration` —
    /// it is called from the app's init, which is the only point early enough.
    static func seedIfRequested() {
        guard isRequested else { return }
        guard let groupURL = SharedModelContainer.groupURL() else {
            persistenceLog.error("pre-V1 seed: App Group unavailable")
            return
        }
        let store = SharedModelContainer.storeURL(groupURL: groupURL)
        let fm = FileManager.default

        // Remove every file of BOTH stores — a leftover V2 local store or a
        // stale -wal would make the "this is a 1.0.0 upgrade" premise false, and
        // a test premised on a lie is worse than no test.
        for name in StoreBackup.storeFileNames(storeURL: store) {
            try? fm.removeItem(at: groupURL.appendingPathComponent(name))
        }
        let local = SharedModelContainer.localStoreURL(groupURL: groupURL)
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(fileURLWithPath: local.path + suffix))
        }
        try? fm.removeItem(at: groupURL.appendingPathComponent("Backups"))

        let defaults = UserDefaults.appGroup
        defaults.removeObject(forKey: SharedModelContainer.migrationCompleteKey)
        defaults.removeObject(forKey: SharedModelContainer.migrationAttemptKey)
        defaults.removeObject(forKey: SharedModelContainer.restorePendingNoticeKey)

        do {
            let schema = Schema(versionedSchema: DebugSchemaV0.self)
            let config = ModelConfiguration("v0-seed", schema: schema, url: store, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let category = DebugSchemaV0.Category(name: "Groceries", kindRaw: "expense", order: 0)
            context.insert(category)
            let source = DebugSchemaV0.Source(name: "Cash")
            context.insert(source)
            for i in 0..<transactionCount {
                let tx = DebugSchemaV0.Transaction(
                    typeRaw: "expense",
                    amountCents: 1000 + i * 37,
                    currency: "USD",
                    date: Date(timeIntervalSince1970: 1_750_000_000 + Double(i) * 86_400),
                    category: category
                )
                tx.source = source
                context.insert(tx)
            }
            try context.save()
            persistenceLog.notice(
                "pre-V1 seed: wrote a V0-shaped store with \(transactionCount, privacy: .public) transaction(s)"
            )
        } catch {
            logSaveFailure("PreV1StoreDebugSeed.seed", error)
        }
    }
}
#endif
