//
//  DuplicateReviewDebugSeed.swift
//  FinanceTracker
//
//  DEBUG-only seam (`--seed-possible-duplicates`) that reproduces the device
//  scenario the possible-duplicate review flow exists for: a foreign CSV (no
//  stable id) imported TWICE.
//
//  It deliberately drives the REAL importer rather than setting
//  `isPossibleDuplicate` by hand — a seeder that faked the flag could go on
//  "passing" long after the importer stopped setting it, which is exactly the
//  class of bug this feature is about. The flags here are produced by production
//  code or not at all.
//
//  The whole file is inside `#if DEBUG`: a Release build cannot import anything
//  from a launch argument.
//

#if DEBUG

import Foundation
import SwiftData

enum DuplicateReviewDebugSeed {

    static var isRequested: Bool {
        CommandLine.arguments.contains("--seed-possible-duplicates")
    }

    /// Wipes transactions, then imports the same foreign CSV twice. The first pass
    /// is clean; every row of the second content-matches and comes back flagged.
    /// `@MainActor` to match the sibling seams (and the ModelContext it is handed,
    /// which is the main context) — the report channel is main-isolated.
    @MainActor
    static func seed(modelContext: ModelContext) {
        do {
            let existing = try modelContext.fetch(FetchDescriptor<Transaction>())
            try hangProbe("DuplicateSeed.wipe", rows: existing.count) {
                for tx in existing {
                    modelContext.delete(tx)
                }
                try modelContext.save()
            }

            let data = Data(foreignCSV().utf8)
            try hangProbe("DuplicateSeed.import", rows: 2) {
                _ = try CSVImportService.importCSV(modelContext: modelContext, data: data)
                _ = try CSVImportService.importCSV(modelContext: modelContext, data: data)
            }

            // Report the shape the test actually depends on, not just "no throw":
            // rows landed AND some came back flagged. A wipe that succeeded and an
            // import that silently matched nothing would otherwise read the same.
            let landed = try modelContext.fetchCount(FetchDescriptor<Transaction>())
            let flagged = try modelContext.fetchCount(
                FetchDescriptor<Transaction>(predicate: #Predicate { $0.isPossibleDuplicate })
            )
            MainThreadStallMonitor.note("seed-possible-duplicates OK landed=\(landed) flagged=\(flagged)")
        } catch {
            // `print` alone is not a channel: app stdout is not captured in
            // xcodebuild logs, so a throw here was invisible to the very UI test
            // that depends on this seam — it would then look for a duplicate badge
            // in an empty ledger and blame the badge. Same fix
            // LargeDatasetDebugSeed already carries.
            MainThreadStallMonitor.note("seed-possible-duplicates FAILED \(error)")
            print("DuplicateReviewDebugSeed failed: \(error.localizedDescription)")
        }
    }

    /// Legacy 9-column shape (no `id` column) — i.e. a foreign file, which is the
    /// only kind that can ever be flagged. Dated today so the rows land in the
    /// default current-month scope of the Transactions list.
    private static func foreignCSV() -> String {
        let today = CSVImportService.makeISO8601Formatter().string(from: Date())
        // Match the store's default currency, or the seeded rows render in one
        // currency while the day-header subtotal (which reads defaultCurrencyCode)
        // renders in another — a confusing QA artifact that isn't a real bug.
        let currency = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "USD"
        return """
        date,type,amount,currency,category,source,tax,note,merchant
        \(today),expense,5.75,\(currency),Food,,0.00,,Starbucks
        \(today),expense,24.00,\(currency),Transport,,0.00,,Uber
        \(today),expense,1234.56,\(currency),Shopping,,0.00,,Amazon
        """
    }
}

#endif
