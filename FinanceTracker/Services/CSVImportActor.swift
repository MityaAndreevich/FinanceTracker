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
        mode: CSVImportMode = .skipDuplicates,
        progress: @Sendable (Int, Int) -> Void
    ) async throws -> CSVImportResult {
        let preamble = try CSVImportService.prepare(modelContext: modelContext, data: data)
        var result = CSVImportResult()
        guard !preamble.rows.isEmpty else { return result }

        var categoryCache = preamble.categoryCache
        var sourceCache = preamble.sourceCache
        var seenUUIDs = preamble.existingUUIDs
        var seenHeuristics = preamble.existingHeuristics
        var processed = 0

        for i in preamble.startIndex..<preamble.rows.count {
            CSVImportService.processRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                mode: mode,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                seenUUIDs: &seenUUIDs,
                seenHeuristics: &seenHeuristics,
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

    /// Tier-2 flexible import (column mapping + presets). Mirrors `importData` but
    /// drives `processMappedRow`; same batched-save + cooperative-yield discipline.
    func importMappedData(
        data: Data,
        mapping: ColumnMapping,
        hasHeader: Bool = true,
        mode: CSVImportMode = .skipDuplicates,
        progress: @Sendable (Int, Int) -> Void
    ) async throws -> CSVImportResult {
        let preamble = try CSVImportService.prepare(modelContext: modelContext, data: data)
        var result = CSVImportResult()
        guard !preamble.rows.isEmpty else { return result }

        var categoryCache = preamble.categoryCache
        var sourceCache = preamble.sourceCache
        var seenUUIDs = preamble.existingUUIDs
        var seenHeuristics = preamble.existingHeuristics
        let defaultCurrency = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "USD"

        let start = hasHeader ? 1 : 0
        let activeMapping = CSVImportService.resolveDecimalStyle(mapping, rows: preamble.rows, startIndex: start)
        let total = max(0, preamble.rows.count - start)
        var processed = 0

        var i = start
        while i < preamble.rows.count {
            CSVImportService.processMappedRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                mapping: activeMapping,
                defaultCurrency: defaultCurrency,
                mode: mode,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                seenUUIDs: &seenUUIDs,
                seenHeuristics: &seenHeuristics,
                result: &result
            )
            processed += 1
            progress(processed, total)

            if processed % Self.batchSize == 0 {
                try modelContext.save()
                await Task.yield()
            }
            i += 1
        }

        try modelContext.save()
        return result
    }
}
