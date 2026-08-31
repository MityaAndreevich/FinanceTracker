//
//  PoisonedAmountsDebugSeed.swift
//  FinanceTracker
//
//  QA seam for the ONE thing unit tests cannot close: the ENUMERATION.
//
//  The recovery work assumed a list — "these are the sums evaluated on the launch
//  path". That list has been wrong three times in one day, twice by grep
//  (`\.draw(in: CGRect` missing multi-line calls; `+=|reduce\(0` missing
//  `running + share.amountCents`) and once by inspection (SafeToSpend was
//  predicted to be on the dashboard; it is not — the 22nd site was). Unit tests
//  prove each KNOWN site reports overflow. Only a real launch proves there is no
//  site nobody listed.
//
//  So this seeds the exact state an already-affected user is in — rows a build
//  without an import ceiling could write — and the UI test simply launches the
//  app. If any unlisted aggregate still traps, the app dies at launch and the
//  test fails. That is the whole design: the assertion is "it is still running".
//
//  These rows CANNOT be created through the app any more: import now rejects them
//  (AmountParsing.maxAmountCents). They are inserted directly, which is precisely
//  how a store written by 1.0.3–1.0.5 would hold them.
//

import Foundation
import SwiftData

enum PoisonedAmountsDebugSeed {

    static let argument = "--poison-amounts"

    /// Set while this seam's rows are in the store, so a later launch that did not
    /// ask for them cleans up rather than inheriting an unlaunchable ledger.
    private static let markerKey = "debug.poisonedAmountsSeed.applied"

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// Two rows that each fit `Int` and together do not. Dated today, because the
    /// dashboard sums `currentMonthTransactions` — a past-month row would not
    /// exercise the launch screen at all.
    @MainActor
    static func seedIfRequested(modelContext: ModelContext) {
        guard isRequested else { return }
        do {
            try wipe(modelContext: modelContext)

            var categories = try modelContext.fetch(FetchDescriptor<Category>())
            if categories.isEmpty {
                let c = Category(name: "Food", kindRaw: "expense", order: 0)
                modelContext.insert(c)
                categories = [c]
            }

            for i in 0..<2 {
                modelContext.insert(
                    Transaction(
                        typeRaw: "expense",
                        amountCents: Int.max - 8,
                        currency: "USD",
                        date: Date(),
                        category: categories.first,
                        merchant: "poisoned \(i)"
                    )
                )
            }
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: markerKey)
            print("PoisonedAmountsDebugSeed: seeded 2 unsummable rows")
        } catch {
            print("PoisonedAmountsDebugSeed failed: \(error.localizedDescription)")
        }
    }

    /// Clears the seeded rows when this launch did NOT ask for them. Without it a
    /// single QA run would leave every later launch on this simulator carrying an
    /// unsummable ledger.
    @MainActor
    static func purgeIfLeftOver(modelContext: ModelContext) {
        guard !isRequested else { return }
        guard UserDefaults.standard.bool(forKey: markerKey) else { return }
        do {
            try wipe(modelContext: modelContext)
            UserDefaults.standard.removeObject(forKey: markerKey)
            print("PoisonedAmountsDebugSeed: purged rows left by an earlier run")
        } catch {
            print("PoisonedAmountsDebugSeed purge failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func wipe(modelContext: ModelContext) throws {
        // Splits before transactions — deleting a parent and letting an unenforced
        // rule decide the rest has bitten this project once already.
        for split in try modelContext.fetch(FetchDescriptor<TransactionSplit>()) {
            modelContext.delete(split)
        }
        for tx in try modelContext.fetch(FetchDescriptor<Transaction>()) {
            modelContext.delete(tx)
        }
        try modelContext.save()
    }
}
