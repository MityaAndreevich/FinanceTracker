//
//  CSVImportActor.swift
//  FinanceTracker
//
//  Background CSV importer. Runs the entire parse + insert loop on a dedicated
//  SwiftData ModelActor executor so large imports (up to MAX_ROWS = 10k) never
//  block the main thread — eliminating the 0x8badf00d watchdog risk that the
//  previous @MainActor import path carried.
//
//  IMPORTANT (Thread-Affinity Trap): a @ModelActor adopts the executor of the
//  thread that constructs it. It MUST be instantiated from a detached, non-main
//  context (see DataSettingsView.startAsyncImport) — otherwise it inherits the
//  MainActor and we gain nothing. The parse logic itself is NOT duplicated here:
//  we reuse CSVImportService.prepare / processRow, differing only in that this
//  path saves in batches of 100 and yields cooperatively between batches.
//

import Foundation
import SwiftData

@ModelActor
actor CSVImportActor {

    /// Number of rows inserted before each intermediate `save()`. Bounds peak
    /// memory and gives a natural cooperative-yield boundary on large imports.
    private static let batchSize = 100

    func importData(
        data: Data,
        progress: @Sendable (Int, Int) -> Void
    ) async throws -> CSVImportResult {
        let preamble = try CSVImportService.prepare(modelContext: modelContext, data: data)
        var result = CSVImportResult()
        guard !preamble.rows.isEmpty else { return result }

        var categoryCache = preamble.categoryCache
        var sourceCache = preamble.sourceCache
        let dateFormatter = CSVImportService.makeISO8601Formatter()
        var processed = 0

        for i in preamble.startIndex..<preamble.rows.count {
            CSVImportService.processRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                dateFormatter: dateFormatter,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                result: &result
            )
            processed += 1
            progress(processed, preamble.totalDataRows)

            // Batch save + yield: flush every 100 rows and hand the executor back
            // so other work (and cancellation) can interleave on huge imports.
            if processed % Self.batchSize == 0 {
                try modelContext.save()
                await Task.yield()
            }
        }

        try modelContext.save()
        return result
    }
}
