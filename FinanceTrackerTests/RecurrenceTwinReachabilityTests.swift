//
//  RecurrenceTwinReachabilityTests.swift
//  FinanceTrackerTests
//
//  Answers one question, empirically rather than by argument: **is the recurring
//  double-prompt reachable in a build WITHOUT sync?**
//
//  It matters because the fix for it (`9b5679e`) was almost put in the 1.0.4
//  What's New as a user-facing bugfix. If twins can only arise from a first-sync
//  union — and sync ships in 1.0.5 — then it is 1.0.5 *preparation*, and telling
//  users we fixed a bug they could not have hit is a false claim about the
//  binary under review. `RecurrenceTwinFixture` builds the twin state by hand,
//  which proves the COLLAPSE works; it says nothing about whether a real
//  no-sync install can ever get there. That is what this file measures.
//
//  A double prompt needs BOTH of:
//    (A) two Transaction rows sharing one `uuid`  — `dueRecurring` groups by uuid;
//    (B) both of them carrying `recurrenceRaw != nil` — the fetch predicate.
//
//  Each test below closes one of those against the only non-sync write paths
//  that take a caller-supplied uuid: the two CSV import routes. Every other
//  Transaction construction site in the app target (DemoSeeder, DemoDataController,
//  LargeDatasetDebugSeed, AddTransactionView, QuickAddSaveService,
//  RecurrenceService's instance) mints a fresh `UUID()` and cannot collide by
//  construction.
//

import Foundation
import SwiftData
import XCTest
@testable import FinanceTracker

final class RecurrenceTwinReachabilityTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // Held for the test's lifetime — returning only the context yields a
        // message-less EXC_BREAKPOINT once the container drops.
        (container, context) = try RecurrenceTwinFixture.makeStore()
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    private func allTransactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    // MARK: - (A) can any non-sync path mint two rows sharing a uuid?

    /// Re-importing our own export in `.skipDuplicates` must skip, not twin.
    ///
    /// The load-bearing detail is that `seenUUIDs` starts from
    /// `preamble.existingUUIDs` — the uuids already ON DISK, not merely the ones
    /// seen earlier in this file. A within-file-only set would skip nothing on a
    /// SECOND import run and would mint a twin per row.
    func test_reimportingOurOwnExport_skipDuplicates_mintsNoTwin() throws {
        RecurrenceTwinFixture.insertTemplate(in: context, anchor: Date())
        try context.save()

        let export = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        _ = try CSVImportService.importCSV(modelContext: context, data: export.data, mode: .skipDuplicates)
        try context.save()

        let rows = try allTransactions()
        XCTAssertEqual(rows.count, 1, "a re-import in skipDuplicates mode must add nothing")
        assertNoTwins(rows)
    }

    /// `.importAll` deliberately keeps both copies — but the new row must carry a
    /// FRESH uuid. Reusing the file's id would no longer upsert (V2 dropped
    /// `@Attribute(.unique)` for CloudKit); it would mint exactly the twin that
    /// every fetch-by-uuid site cannot resolve.
    func test_reimportingOurOwnExport_importAll_duplicatesTheRowButNotTheUUID() throws {
        RecurrenceTwinFixture.insertTemplate(in: context, anchor: Date())
        try context.save()

        let export = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        _ = try CSVImportService.importCSV(modelContext: context, data: export.data, mode: .importAll)
        try context.save()

        let rows = try allTransactions()
        XCTAssertEqual(rows.count, 2, "importAll keeps both copies — that is its contract")
        assertNoTwins(rows)   // ...but they are two identities, not one identity twice
    }

    /// The same file imported repeatedly, alternating modes — the shape a user
    /// actually produces by tapping Import more than once.
    func test_repeatedMixedModeImports_neverMintATwin() throws {
        RecurrenceTwinFixture.insertTemplate(in: context, anchor: Date())
        try context.save()

        for mode in [CSVImportMode.skipDuplicates, .importAll, .skipDuplicates, .importAll] {
            let export = try CSVExportService.makeCSV(modelContext: context, scope: .all)
            _ = try CSVImportService.importCSV(modelContext: context, data: export.data, mode: mode)
            try context.save()
            assertNoTwins(try allTransactions())
        }
    }

    // MARK: - (B) can an imported row be a recurring template at all?

    /// Independent of (A): the export/import format carries no recurrence column,
    /// so an imported row can never satisfy `dueRecurring`'s predicate. Even a
    /// hypothetical uuid collision could not produce a second prompt.
    ///
    /// This is the stronger of the two guarantees, because it does not depend on
    /// the importer's dedup logic staying correct.
    func test_importedRowsAreNeverRecurringTemplates() throws {
        let template = RecurrenceTwinFixture.insertTemplate(in: context, anchor: Date())
        let templateUUID = template.uuid
        try context.save()

        let export = try CSVExportService.makeCSV(modelContext: context, scope: .all)
        _ = try CSVImportService.importCSV(modelContext: context, data: export.data, mode: .importAll)
        try context.save()

        let recurring = try allTransactions().filter { $0.recurrenceRaw != nil }
        XCTAssertEqual(recurring.count, 1, "import must not create a recurring template")
        XCTAssertEqual(recurring.first?.uuid, templateUUID, "the only template is the original")
    }

    // MARK: - the question as the user would feel it

    /// The end-to-end statement: after every no-sync path that could plausibly
    /// duplicate a recurring series, the user is asked exactly once.
    func test_afterEveryNoSyncDuplicationPath_theUserIsPromptedOnce() throws {
        // Anchor a month back so the series is genuinely due now.
        let anchor = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        RecurrenceTwinFixture.insertTemplate(in: context, anchor: anchor)
        try context.save()

        for mode in [CSVImportMode.skipDuplicates, .importAll] {
            let export = try CSVExportService.makeCSV(modelContext: context, scope: .all)
            _ = try CSVImportService.importCSV(modelContext: context, data: export.data, mode: mode)
            try context.save()
        }

        let prompts = RecurrenceService.dueRecurring(modelContext: context)
        XCTAssertEqual(prompts.count, 1, "one series must ask once, not once per row")
    }

    // MARK: - Negative control: prove the detector can fail

    /// Every assertion above is of the form "no twins were found", which passes
    /// identically when the detector is broken and when the store is genuinely
    /// clean. This test builds the twin state BY HAND — the shape a first-sync
    /// union produces — and proves the detector sees it.
    ///
    /// Without this, the four tests above would be exactly the vacuous shape
    /// this codebase has now been bitten by three times.
    func test_control_theTwinDetectorActuallyDetectsTwins() throws {
        let twins = RecurrenceTwinFixture.insertTwins(in: context, anchor: Date())
        try context.save()

        let rows = try allTransactions()
        XCTAssertEqual(rows.count, 2)

        let uuids = rows.map(\.uuid)
        let duplicated = Set(uuids.filter { uuid in uuids.filter { $0 == uuid }.count > 1 })
        XCTAssertEqual(
            duplicated, [twins.uuid],
            "the detector used by every test above must see a hand-built twin — if this is empty, those tests prove nothing"
        )
    }

    /// And the other half of the control: with twins present, the collapse still
    /// asks once. This is what `9b5679e` fixed, and it stays true — it is simply
    /// unreachable in a no-sync build, which is the point of this file.
    func test_control_handBuiltTwinsStillCollapseToOnePrompt() throws {
        let anchor = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        RecurrenceTwinFixture.insertTwins(in: context, anchor: anchor)
        try context.save()

        XCTAssertEqual(try allTransactions().count, 2, "two rows, one series")
        XCTAssertEqual(
            RecurrenceService.dueRecurring(modelContext: context).count, 1,
            "the collapse is what makes twins survivable once sync ships"
        )
    }

    // MARK: -

    private func assertNoTwins(
        _ rows: [Transaction],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let uuids = rows.map(\.uuid)
        let duplicated = Set(uuids.filter { uuid in uuids.filter { $0 == uuid }.count > 1 })
        XCTAssertTrue(
            duplicated.isEmpty,
            "twin uuid(s) reachable without sync: \(duplicated.map(\.uuidString).sorted())",
            file: file, line: line
        )
        // Guard the guard: a scan over zero rows proves nothing.
        XCTAssertGreaterThan(rows.count, 0, "no rows examined", file: file, line: line)
    }
}
