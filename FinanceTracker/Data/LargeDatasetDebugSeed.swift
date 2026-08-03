//
//  LargeDatasetDebugSeed.swift
//  FinanceTracker
//
//  DEBUG-only seam (`--seed-large-dataset`) that fills the REAL store with a
//  large, realistic ledger: thousands of transactions spread across ~24 months.
//
//  Why it exists: the main-thread Core Data hang scales with ROW COUNT. A fresh
//  simulator (~30 demo rows) pays sub-millisecond for the synchronous fetches
//  and can never reproduce what a device that has accumulated months of data
//  shows constantly (device Console: performBlockAndWait / sqlite3_step on
//  com.apple.main-thread on every save). This seam is how a simulator — and the
//  founder's device — gets a store big enough for the hang to be measurable.
//
//  DETERMINISM (2026-08-04). This seam previously topped up to a threshold:
//  `guard existing < targetCount` then `for i in existing..<targetCount`. That
//  made every seeded run depend on whatever the store already held, and left the
//  rows behind forever. Three consequences, all observed:
//
//    1. Content drifted even when the COUNT matched. The loop index started at
//       `existing`, so merchants, amounts and which rows carried splits all
//       shifted with the prior row count. Two runs at "8 000 rows" were not the
//       same 8 000 rows.
//    2. If a prior test had pushed the store OVER the target (an import, a
//       duplicate seed, a few QuickAdds), the guard returned early and the run
//       silently measured an unknown, larger store.
//    3. The rows outlived the run. Nothing removed them, so every LATER test —
//       including ones that never asked for scale — launched against 8 000 rows
//       until someone erased the simulator. That is what made the 2026-08-03
//       suite comparison meaningless: neither run's figure was trustworthy.
//
//  The property now guaranteed is the one that was missing: TWO CONSECUTIVE RUNS
//  OF THE SAME TEST SEE THE SAME STORE. It is achieved with two halves:
//
//    - `seedIfRequested` RESETS rather than tops up: it clears the ledger, then
//      writes exactly `targetCount` rows from index 0. The result is independent
//      of what was there before, in content as well as in count.
//    - `purgeIfLeftOver` runs on the next launch that does NOT ask for scale and
//      clears the residue. Teardown deliberately happens at the START of the
//      following launch rather than the END of the seeding one, because a test
//      that crashes, times out, or is killed never reaches its own teardown —
//      and killed runs are exactly how this went unnoticed.
//
//  The marker is what makes the purge targeted: only a store this seam actually
//  seeded gets cleared, so an unseeded run against a hand-made store is untouched.
//  If the marker is ever lost, the failure mode is one skipped purge, never a
//  wipe of something we did not write.
//
//  The whole file is inside `#if DEBUG`: a Release build cannot seed anything
//  from a stray launch argument.
//

#if DEBUG
import Foundation
import SwiftData

enum LargeDatasetDebugSeed {

    static let argument = "--seed-large-dataset"
    static let targetCount = 8_000

    /// Set while this seam's rows are in the store. Standard `UserDefaults`, not
    /// the app group: it describes THIS install's store, and the widget has no
    /// business reading it.
    private static let markerKey = "debug.largeDatasetSeed.applied"

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// Clears a previously seeded ledger when the current launch did NOT ask for
    /// scale. Call before any other seam that writes rows, so an importer or a
    /// duplicate seed never runs against 8 000 rows it did not expect.
    @MainActor
    static func purgeIfLeftOver(modelContext: ModelContext) {
        guard !isRequested else { return }
        guard UserDefaults.standard.bool(forKey: markerKey) else { return }
        do {
            try wipeLedger(modelContext: modelContext)
            UserDefaults.standard.removeObject(forKey: markerKey)
            print("LargeDatasetDebugSeed: purged a seeded ledger left by an earlier run")
        } catch {
            print("LargeDatasetDebugSeed purge failed: \(error.localizedDescription)")
        }
    }

    /// Deletes splits before transactions. `TransactionSplit.parent` is the
    /// inverse of a to-many, and the project has already been bitten once by
    /// deleting a related row and letting an unenforced rule decide the rest
    /// (`.nullify` with no inverse → persistent `EXC_BREAKPOINT`). Explicit
    /// order costs nothing and removes the question.
    @MainActor
    private static func wipeLedger(modelContext: ModelContext) throws {
        try modelContext.delete(model: TransactionSplit.self)
        try modelContext.delete(model: Transaction.self)
        try modelContext.save()
    }

    @MainActor
    static func seedIfRequested(modelContext: ModelContext) {
        guard isRequested else { return }
        do {
            // Reset, don't top up. Without this the ledger below is a function of
            // whatever the previous test left behind.
            try wipeLedger(modelContext: modelContext)
            let existing = 0

            // Reuse the seeded default categories; create plain ones if the
            // store predates seeding (order of launch tasks).
            var categories = try modelContext.fetch(FetchDescriptor<Category>())
            if categories.isEmpty {
                for (i, name) in ["Food", "Transport", "Home", "Fun", "Health", "Other"].enumerated() {
                    let c = Category(name: name, kindRaw: "expense", order: i)
                    modelContext.insert(c)
                    categories.append(c)
                }
            }
            let expenseCategories = categories.filter { $0.kindRaw == "expense" }
            let incomeCategory = categories.first { $0.kindRaw == "income" }
                ?? expenseCategories.first ?? categories[0]

            let daySeconds: TimeInterval = 24 * 60 * 60
            let start = Date().addingTimeInterval(-730 * daySeconds)   // ~24 months
            for i in existing..<targetCount {
                let isIncome = i % 20 == 0
                let tx = Transaction(
                    typeRaw: isIncome ? "income" : "expense",
                    amountCents: 500 + (i % 300) * 37,
                    currency: "USD",
                    date: start.addingTimeInterval(Double(i % 730) * daySeconds),
                    category: isIncome ? incomeCategory : expenseCategories[i % max(1, expenseCategories.count)],
                    source: nil, taxCents: nil, note: nil,
                    merchant: "Seed Merchant \(i % 40)",
                    recurrenceRaw: nil
                )
                modelContext.insert(tx)

                // Every 7th expense carries a 2-part split (~1.1k split purchases
                // at the 8k target). Without these the seeded store is a 1.0.2
                // store and cannot reproduce a 1.0.3 symptom: `shares(for:)` and
                // `orderedSplits(of:)` touch `tx.splits`, a SwiftData to-many
                // relationship, so the per-row cost the freeze report is about
                // simply isn't present in a split-free ledger. Sum is kept BELOW
                // the parent total so the remainder share exists too — the
                // partially-split shape, which is the one both attribution
                // branches have to walk.
                if !isIncome && i % 7 == 0 && expenseCategories.count >= 2 {
                    let half = max(1, tx.amountCents / 4)
                    for part in 0..<2 {
                        let split = TransactionSplit(
                            amountCents: half,
                            category: expenseCategories[(i + part + 1) % expenseCategories.count],
                            order: part
                        )
                        modelContext.insert(split)
                        split.parent = tx
                    }
                }

                if i % 500 == 0 { try modelContext.save() }   // bounded pending set
            }
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: markerKey)
            print("LargeDatasetDebugSeed: store now holds \(try modelContext.fetchCount(FetchDescriptor<Transaction>())) transactions")
        } catch {
            print("LargeDatasetDebugSeed failed: \(error.localizedDescription)")
        }
    }
}
#endif
