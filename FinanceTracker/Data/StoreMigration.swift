//
//  StoreMigration.swift
//  FinanceTracker
//
//  The V1→V2 schema migration (design doc §7): one custom stage whose whole
//  purpose is that a 1.0.2 store arrives in 1.0.3 with its referential damage
//  repaired and its merchant-learning rows moved out of the future-synced store.
//
//  Why the repair lives in `didMigrate`, not `willMigrate` (§7.1):
//    1. Under V1, Transaction.category is non-optional — `tx.category = nil`
//       doesn't even compile there. Repair is only expressible under V2.
//    2. The schema transform between the closures is a table-level mapping: it
//       copies rows, never traverses relationships, never fires faults —
//       dangling foreign keys pass through untouched and harmlessly.
//    3. Inverse/delete-rule enforcement is event-driven (fires on deletes and
//       propagating saves). The repair deletes nothing and only writes nil
//       into the dangling side, so enforcement cannot fire mid-repair; the
//       single final save commits references that can no longer dangle.
//
//  The repair NULLIFIES, never deletes: a transaction with a dangling source/
//  category is an intact money record whose decoration pointer broke — because
//  of OUR unenforced-`.nullify` bug. Deleting a user's financial record to fix
//  our referential integrity would be indefensible; nil is exactly the state
//  the declared rule would have produced had it been enforced. The nil category
//  then renders as "Uncategorized".
//

import Foundation
import SwiftData

// MARK: - V2 (current shapes)

enum FinanceTrackerSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Source.self, TransactionSplit.self,
         MerchantCategoryLearning.self]
    }
}

// MARK: - Migration plan

enum FinanceTrackerMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [FinanceTrackerSchemaV1.self, FinanceTrackerSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [MigrationStage.custom(
            fromVersion: FinanceTrackerSchemaV1.self,
            toVersion: FinanceTrackerSchemaV2.self,
            willMigrate: { context in
                try MerchantLearningHandoff.exfiltrate(from: context)
            },
            didMigrate: { context in
                try StoreRepair.verifyNoDanglingReferences(in: context)
            }
        )]
    }
}

// MARK: - Dangling-reference verification (didMigrate, V2 context)

enum StoreRepair {

    struct DanglingReferencesError: LocalizedError {
        let count: Int
        var errorDescription: String? {
            "store still contains \(count) dangling reference(s) after preflight repair"
        }
    }

    /// READ-ONLY verification that the preflight SQL repair left no dangling
    /// references. Throwing here fails the migration attempt cleanly, which
    /// feeds the §10 rollback ladder (restore → retry → floor) — the user's
    /// data stays intact either way.
    ///
    /// Why verify-and-throw instead of repairing here: rehearsal against a
    /// field-identical damaged store showed that ASSIGNING through a V2
    /// relationship (`tx.source = nil`) crashes — the new inverse makes
    /// SwiftData materialize the missing destination to unhook the
    /// back-reference (EXC_BREAKPOINT in the setter). READING is safe:
    /// `persistentModelID` maps to Core Data's objectID access, which never
    /// fires the fault. So repair lives in StorePreflightRepair (raw SQLite,
    /// before the container opens) and this pass only reads, throws, and
    /// never mutates — `updatedAt` untouched, no save(), no-op on a clean
    /// store by construction.
    static func verifyNoDanglingReferences(in context: ModelContext) throws {
        let sourceIDs = Set(try context.fetch(FetchDescriptor<Source>()).map(\.persistentModelID))
        let categoryIDs = Set(try context.fetch(FetchDescriptor<Category>()).map(\.persistentModelID))

        var dangling = 0
        for tx in try context.fetch(FetchDescriptor<Transaction>()) {
            if let sid = tx.source?.persistentModelID, !sourceIDs.contains(sid) {
                dangling += 1
            }
            if let cid = tx.category?.persistentModelID, !categoryIDs.contains(cid) {
                dangling += 1
            }
        }
        // TransactionSplit was created empty by this very migration — nothing
        // to verify there, by construction.

        if dangling > 0 {
            persistenceLog.error("migration verify: \(dangling, privacy: .public) dangling reference(s) survived preflight")
            throw DanglingReferencesError(count: dangling)
        }
    }
}

// MARK: - Merchant-learning handoff (willMigrate → app-init import)

/// `MerchantCategoryLearning` carries a privacy promise ("NEVER leaves the
/// device — no sync") — so when iCloud ships it must not live in the synced
/// store. V2 moves it to a local-only store file. The V2 synced store no
/// longer contains the entity, so its rows leave via a sidecar JSON BEFORE the
/// transform (willMigrate, V1 context) and are re-inserted into the local
/// store on the first app launch after migration.
///
/// Losing the file entirely degrades to "suggestion personalization resets" —
/// it's a re-learnable cache, never user data.
enum MerchantLearningHandoff {

    struct Row: Codable, Equatable {
        let merchantNormalized: String
        let categoryName: String
        let useCount: Int
        let lastUsedAt: Date
    }

    static let filename = "merchant-learning-handoff.json"

    static func handoffURL(groupURL: URL) -> URL {
        groupURL.appendingPathComponent(filename)
    }

    /// willMigrate (V1 context): serialize every row to the sidecar. Writes
    /// nothing when there are no rows, mutates the store never (no save()).
    static func exfiltrate(from context: ModelContext) throws {
        let rows = try context
            .fetch(FetchDescriptor<FinanceTrackerSchemaV1.MerchantCategoryLearning>())
            .map { Row(merchantNormalized: $0.merchantNormalized,
                       categoryName: $0.categoryName,
                       useCount: $0.useCount,
                       lastUsedAt: $0.lastUsedAt) }
        guard !rows.isEmpty else { return }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID
        ) else { return }

        let data = try JSONEncoder().encode(rows)
        try data.write(to: handoffURL(groupURL: groupURL), options: .atomic)
        persistenceLog.notice("migration handoff: exfiltrated \(rows.count, privacy: .public) merchant-learning row(s)")
    }

    /// First launch after migration: upsert the sidecar's rows into the local
    /// store, save, THEN delete the file. A crash between save and delete
    /// re-upserts the same rows onto themselves next launch (`.unique` on
    /// merchantNormalized makes the upsert idempotent in the local store).
    static func importIfPresent(into context: ModelContext) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID
        ) else { return }
        let url = handoffURL(groupURL: groupURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
            let existing = try context.fetch(FetchDescriptor<MerchantCategoryLearning>())
            var byMerchant = Dictionary(uniqueKeysWithValues: existing.map { ($0.merchantNormalized, $0) })
            for row in rows {
                if let hit = byMerchant[row.merchantNormalized] {
                    hit.categoryName = row.categoryName
                    hit.useCount = max(hit.useCount, row.useCount)
                    hit.lastUsedAt = max(hit.lastUsedAt, row.lastUsedAt)
                } else {
                    let fresh = MerchantCategoryLearning(
                        merchantNormalized: row.merchantNormalized,
                        categoryName: row.categoryName,
                        useCount: row.useCount,
                        lastUsedAt: row.lastUsedAt
                    )
                    context.insert(fresh)
                    byMerchant[row.merchantNormalized] = fresh
                }
            }
            try context.save()
            try FileManager.default.removeItem(at: url)
            persistenceLog.notice("migration handoff: imported \(rows.count, privacy: .public) merchant-learning row(s) into the local store")
        } catch {
            logSaveFailure("MerchantLearningHandoff.import", error)
        }
    }
}
