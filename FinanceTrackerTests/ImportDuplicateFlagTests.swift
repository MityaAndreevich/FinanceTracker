//
//  ImportDuplicateFlagTests.swift
//  FinanceTracker
//
//  The possible-duplicate decision must OUTLIVE the import summary alert.
//
//  Design rule (unchanged): a foreign row (no stable UUID) that content-matches
//  existing data is FLAGGED, never dropped — we cannot tell a re-import apart
//  from two genuinely identical real spends. Before v1.0.2 that flag existed
//  only as a counter in `CSVImportResult`, so the user could never find or
//  resolve the rows it referred to. It is now persisted on the Transaction and
//  resolved through DuplicateReviewService.
//
//  Own-export re-import (rows DO carry a UUID) stays exactly-idempotent and must
//  never flag anything — see testOwnExportReimport_AddsNothingAndFlagsNothing.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class ImportDuplicateFlagTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Category.self, Source.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// A foreign (Mint-style) CSV with no `id` column. Day-only dates.
    private let foreignCSV = """
    date,type,amount,currency,category,source,tax,note,merchant
    2023-11-14,expense,12.34,USD,Food,,0.00,,Cafe
    2023-11-14,expense,40.00,USD,Food,,0.00,,Grocer
    """

    private func flagged(_ ctx: ModelContext) throws -> [Transaction] {
        try ctx.fetch(FetchDescriptor<Transaction>()).filter { $0.isPossibleDuplicate }
    }

    // MARK: - Item 1: the flag is persisted on the transaction

    /// Fresh import into an empty store: nothing content-matches, so nothing is
    /// flagged. Guards against flagging every imported row.
    func testFirstForeignImport_FlagsNothing() throws {
        let ctx = try makeContext()
        let result = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.possibleDuplicates, 0, "Nothing to match against in an empty store")
        XCTAssertEqual(try flagged(ctx).count, 0, "No row may carry the flag on a first import")
    }

    /// THE DEVICE-OBSERVED GAP: re-importing the same foreign file keeps both
    /// copies (correct) — and now every re-imported row carries the persisted
    /// flag, so the list can badge it and the review flow can find it.
    func testForeignReimport_PersistsFlagOnTheImportedRows() throws {
        let ctx = try makeContext()
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        let result = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        XCTAssertEqual(result.imported, 2, "Foreign rows are flagged, never dropped")
        XCTAssertEqual(result.possibleDuplicates, 2)

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(all.count, 4, "Both copies survive — the user decides, not us")

        let flaggedRows = try flagged(ctx)
        XCTAssertEqual(
            flaggedRows.count, result.possibleDuplicates,
            "The badge count must equal the summary count — one source of truth"
        )
        XCTAssertTrue(
            flaggedRows.allSatisfy { $0.isPossibleDuplicate },
            "Only the second (matching) copies are flagged; the originals stay clean"
        )
    }

    /// The Tier-2 mapped importer (Mint/YNAB/Monarch presets) shares the same
    /// dedup identity, so it must persist the flag identically — not just the
    /// generic 9-column path.
    func testMappedForeignReimport_PersistsFlag() throws {
        let ctx = try makeContext()
        let mint = """
        Date,Description,Amount,Category
        11/14/2023,Cafe,-12.34,Food
        """
        let mapping = ColumnMapping(
            date: 0, dateOrder: .mdy, decimal: .period,
            amount: .signed(2), category: 3, merchant: 1, note: nil, account: nil
        )

        _ = try CSVImportService.importMappedCSV(modelContext: ctx, data: Data(mint.utf8), mapping: mapping)
        let result = try CSVImportService.importMappedCSV(modelContext: ctx, data: Data(mint.utf8), mapping: mapping)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.possibleDuplicates, 1)
        XCTAssertEqual(try flagged(ctx).count, 1, "Mapped path must persist the flag too")
    }

    /// THE DEVICE REPORT, reproduced on the real file: outputs/test_import_mint.csv
    /// imported twice through the auto-detected Mint preset. This is the exact
    /// scenario that produced un-findable duplicates on device — the synthetic
    /// fixtures above can't prove the real header/preset/date/amount combination
    /// still lands on the same dedup identity.
    func testRealMintFile_ImportedTwice_FlagsEveryRowOfTheSecondPass() throws {
        let ctx = try makeContext()
        let url = URL(fileURLWithPath: #filePath)      // …/FinanceTrackerTests/ImportDuplicateFlagTests.swift
            .deletingLastPathComponent()               // …/FinanceTrackerTests
            .deletingLastPathComponent()               // repo root
            .appendingPathComponent("outputs/test_import_mint.csv")
        let data = try Data(contentsOf: url)

        let preview = try XCTUnwrap(CSVImportService.parsePreview(data: data))
        XCTAssertEqual(SourcePreset.detect(header: preview.header), .mint, "Header must still auto-detect as Mint")
        let mapping = try XCTUnwrap(SourcePreset.mint.defaultMapping(header: preview.header))

        let first = try CSVImportService.importMappedCSV(modelContext: ctx, data: data, mapping: mapping)
        XCTAssertEqual(first.imported, 6, "All six rows import")
        XCTAssertEqual(first.possibleDuplicates, 0, "Nothing to match on a first import")
        XCTAssertEqual(try flagged(ctx).count, 0)

        let second = try CSVImportService.importMappedCSV(modelContext: ctx, data: data, mapping: mapping)
        XCTAssertEqual(second.imported, 6, "Foreign rows are kept, not dropped")
        XCTAssertEqual(second.possibleDuplicates, 6, "Every row of the re-import content-matches")

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 12)
        XCTAssertEqual(
            try flagged(ctx).count, second.possibleDuplicates,
            "Every row the summary counted must carry the badge — that equality IS the fix"
        )

        // And the review flow puts the store back exactly where it started.
        try DuplicateReviewService.deleteAll(in: ctx)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 6, "Back to the original six")
        XCTAssertEqual(try flagged(ctx).count, 0)
    }

    // MARK: - Item 3: own-export re-import stays idempotent AND unflagged

    /// Our own export carries the stable UUID, so a re-import is an exact match:
    /// zero new rows, and — critically — zero flags. Only foreign rows may ever
    /// be flagged.
    func testOwnExportReimport_AddsNothingAndFlagsNothing() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        ctx.insert(cat)
        for i in 0..<3 {
            ctx.insert(Transaction(
                typeRaw: "expense",
                amountCents: 100 + i,
                currency: "USD",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                category: cat,
                merchant: "Cafe\(i)"
            ))
        }
        try ctx.save()

        let exported = try CSVExportService.makeCSV(modelContext: ctx, scope: .all)
        let result = try CSVImportService.importCSV(modelContext: ctx, data: exported.data)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.duplicatesSkipped, 3, "UUID exact match → idempotent")
        XCTAssertEqual(result.possibleDuplicates, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 3)
        XCTAssertEqual(try flagged(ctx).count, 0, "A UUID-matched re-import must never flag")
    }

    // MARK: - Item 2: review / resolve

    /// Keep = "these are two real spends, stop asking." Clears the flag, keeps
    /// the row.
    func testKeepClearsTheFlagAndKeepsTheRow() throws {
        let ctx = try makeContext()
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        let target = try XCTUnwrap(try flagged(ctx).first)
        try DuplicateReviewService.keep(target, in: ctx)

        XCTAssertFalse(target.isPossibleDuplicate)
        XCTAssertEqual(try flagged(ctx).count, 1, "Only the resolved row leaves the review queue")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 4, "Keep deletes nothing")
    }

    /// Delete = "that was a re-import." Normal delete, row is gone.
    func testDeleteRemovesTheRow() throws {
        let ctx = try makeContext()
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        let target = try XCTUnwrap(try flagged(ctx).first)
        try DuplicateReviewService.delete(target, in: ctx)

        XCTAssertEqual(try flagged(ctx).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 3, "The duplicate copy is gone")
    }

    func testDeleteAllRemovesEveryFlaggedRowAndLeavesTheOriginals() throws {
        let ctx = try makeContext()
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        try DuplicateReviewService.deleteAll(in: ctx)

        XCTAssertEqual(try flagged(ctx).count, 0)
        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<Transaction>()).count, 2,
            "Back to the original two — deleting duplicates must never touch the originals"
        )
    }

    func testKeepAllClearsEveryFlagAndDeletesNothing() throws {
        let ctx = try makeContext()
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))

        try DuplicateReviewService.keepAll(in: ctx)

        XCTAssertEqual(try flagged(ctx).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 4, "Keep all deletes nothing")
    }

    func testFlaggedCountDrivesTheBanner() throws {
        let ctx = try makeContext()
        XCTAssertEqual(try DuplicateReviewService.flaggedCount(in: ctx), 0, "No banner on a clean store")

        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        _ = try CSVImportService.importCSV(modelContext: ctx, data: Data(foreignCSV.utf8))
        XCTAssertEqual(try DuplicateReviewService.flaggedCount(in: ctx), 2)

        try DuplicateReviewService.keepAll(in: ctx)
        XCTAssertEqual(try DuplicateReviewService.flaggedCount(in: ctx), 0, "Banner disappears once resolved")
    }
}
