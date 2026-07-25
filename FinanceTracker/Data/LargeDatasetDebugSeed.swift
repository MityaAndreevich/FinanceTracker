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
//  Idempotent by threshold: if the store already holds >= `targetCount` rows it
//  does nothing, so relaunching with the argument doesn't stack another 8k rows.
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

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    @MainActor
    static func seedIfRequested(modelContext: ModelContext) {
        guard isRequested else { return }
        do {
            let existing = try modelContext.fetchCount(FetchDescriptor<Transaction>())
            guard existing < targetCount else { return }

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
            print("LargeDatasetDebugSeed: store now holds \(try modelContext.fetchCount(FetchDescriptor<Transaction>())) transactions")
        } catch {
            print("LargeDatasetDebugSeed failed: \(error.localizedDescription)")
        }
    }
}
#endif
