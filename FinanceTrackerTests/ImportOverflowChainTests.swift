//
//  ImportOverflowChainTests.swift
//  FinanceTrackerTests
//
//  Closes the gap between a filed defect and a bricking bug. The chain, as
//  assembled from separate measurements, is:
//
//      CSV import has no magnitude cap (CSVImportService.swift:710)
//        → a value the UI would refuse (AddTransactionView.swift:502) is stored
//        → MonthTotals sums amountCents in Int (MonthTotals.swift:20,25)
//        → Int overflow TRAPS
//        → MonthTotals feeds DashboardView (DashboardView.swift:130,134)
//        → the dashboard is the first tab (ContentView.swift:113-115)
//
//  Each link was measured on its own. NONE of that establishes that a real import
//  completes the chain end to end, that the state survives a relaunch, or that
//  the user has any way out. This file measures those, and nothing here fixes
//  anything.
//
//  ── THE FILE SHAPE, AND WHY IT IS PLAUSIBLE ─────────────────────────────────
//  Not a hostile file. The app ships FLEXIBLE COLUMN MAPPING with presets for
//  Mint / YNAB / Monarch, so the user chooses which column is the amount. Bank
//  exports routinely carry 16–18 digit reference or account numbers. Mapping
//  "Reference" to "Amount" by mistake is an ordinary user error with an ordinary
//  file, and it produces exactly the digits used below.
//
//  Two regimes are exercised, both reachable that way:
//    • 17 digits  — stores successfully, near Int.max cents. TWO such rows are
//      what a monthly sum cannot hold.
//    • ≥20 digits — `Int(intDigits) ?? 0` in AmountParsing.parseCents:63 yields
//      ZERO, so the row imports as a zero-value transaction.
//

import XCTest
import SwiftData
@testable import FinanceTracker

final class ImportOverflowChainTests: XCTestCase {

    /// A 17-digit "amount" — the shape of a mis-mapped reference column.
    /// 92_233_720_368_547_758 × 100 + 7 is exactly Int.max, so this is the widest
    /// value that stores rather than trapping inside the parser.
    private static let seventeenDigits = "92233720368547758"
    /// A 22-digit reference number, the other common mis-map.
    private static let twentyTwoDigits = "1234567890123456789012"

    private func csv(amounts: [String]) -> Data {
        var lines = ["date,type,amount,currency,category,source,tax,note,merchant"]
        for (i, a) in amounts.enumerated() {
            lines.append("2026-08-0\(i + 1),expense,\(a),USD,Food & Drink,,,,Merchant \(i)")
        }
        return lines.joined(separator: "\n").data(using: .utf8)!
    }

    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([Transaction.self, Category.self, Source.self, TransactionSplit.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (container, ModelContext(container))
    }

    // MARK: - (1)(2) Does a real import store what the UI would refuse?

    func testImportStoresAmountsTheUIWouldRefuse() throws {
        let (container, context) = try makeStore()
        defer { _ = container }

        let result = try CSVImportService.importCSV(
            modelContext: context,
            data: csv(amounts: [Self.seventeenDigits, Self.seventeenDigits])
        )
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        let uiCap = 10_000_000_000_000        // AddTransactionView.swift:502
        var report: [String] = []
        report.append("")
        report.append("IMPORTED ROWS — UI cap is \(uiCap) cents")
        report.append(String(repeating: "═", count: 88))
        report.append("  imported=\(result.imported)  skipped=\(result.skipped)  rows in store=\(txs.count)")
        for tx in txs {
            report.append("    amountCents = \(tx.amountCents)"
                          + "  (\(tx.amountCents > uiCap ? "ABOVE the UI cap — the UI would refuse this" : "within the cap"))")
        }
        report.append(String(repeating: "═", count: 88))
        print(report.joined(separator: "\n"))

        XCTAssertEqual(txs.count, 2, "the import did not store both rows")
        for tx in txs {
            XCTAssertGreaterThan(tx.amountCents, uiCap,
                "row stored as \(tx.amountCents), which the UI cap would have allowed — "
                + "the fixture no longer exercises the asymmetry")
        }
    }

    // MARK: - (3) Would the dashboard's own sum overflow?

    /// Proves the trap WITHOUT taking it: `addingReportingOverflow` is the same
    /// addition `MonthTotals.expenseCents` performs via `reduce(0, +)`, minus the
    /// trap. A crashing test cannot report its own findings, so the finding is
    /// made here and the crash is observed separately (see the probe below).
    func testTheSumTheDashboardComputesOverflows() throws {
        let (container, context) = try makeStore()
        defer { _ = container }

        _ = try CSVImportService.importCSV(
            modelContext: context,
            data: csv(amounts: [Self.seventeenDigits, Self.seventeenDigits])
        )
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        let expenses = txs.filter { !$0.isIncome }

        var acc = 0
        var overflowedAt: Int?
        for (i, tx) in expenses.enumerated() {
            let (sum, overflow) = acc.addingReportingOverflow(tx.amountCents)
            if overflow { overflowedAt = i; break }
            acc = sum
        }

        print("""

        THE DASHBOARD'S SUM — MonthTotals.expenseCents, DashboardView.swift:130
        \(String(repeating: "═", count: 88))
          expense rows            : \(expenses.count)
          running total before it : \(acc)
          overflow at row index   : \(overflowedAt.map(String.init) ?? "none")
          Int.max                 : \(Int.max)
        \(String(repeating: "═", count: 88))
        """)

        XCTAssertNotNil(overflowedAt,
            "the sum did NOT overflow — the chain does not complete with this fixture, "
            + "and the bricking hypothesis is not established")
    }

    // MARK: - (4) Does it survive a relaunch?

    /// A relaunch is a new container over the SAME file. If the rows are there and
    /// the sum still overflows, every launch recomputes the same trap.
    func testTheRowsSurviveAReopenOfTheStore() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("overflow-chain-\(UUID().uuidString).store")
        let schema = Schema([Transaction.self, Category.self, Source.self, TransactionSplit.self])

        do {   // "first launch": import, then let the container go
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            _ = try CSVImportService.importCSV(
                modelContext: context,
                data: csv(amounts: [Self.seventeenDigits, Self.seventeenDigits])
            )
            try context.save()
        }

        do {   // "relaunch": a fresh container over the same file
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let txs = try context.fetch(FetchDescriptor<Transaction>())

            var acc = 0
            var overflowed = false
            for tx in txs where !tx.isIncome {
                let (sum, o) = acc.addingReportingOverflow(tx.amountCents)
                if o { overflowed = true; break }
                acc = sum
            }
            print("""

            AFTER A REOPEN OF THE SAME STORE FILE
            \(String(repeating: "═", count: 88))
              rows still present : \(txs.count)
              sum still overflows: \(overflowed)
            \(String(repeating: "═", count: 88))
            """)
            XCTAssertEqual(txs.count, 2, "the rows did not persist across the reopen")
            XCTAssertTrue(overflowed, "the overflow did not survive the reopen")
            _ = container
        }
    }

    // MARK: - (6) What does a 22-digit amount store?

    func testTwentyTwoDigitAmountImportsAsZero() throws {
        let (container, context) = try makeStore()
        defer { _ = container }

        let result = try CSVImportService.importCSV(
            modelContext: context,
            data: csv(amounts: [Self.twentyTwoDigits])
        )
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        print("""

        A 22-DIGIT AMOUNT — "\(Self.twentyTwoDigits)"
        \(String(repeating: "═", count: 88))
          imported=\(result.imported)  skipped=\(result.skipped)
          stored amountCents: \(txs.map { String($0.amountCents) }.joined(separator: ", "))
          skipped / duplicates: \(result.skipped) / \(result.duplicatesSkipped)
        \(String(repeating: "═", count: 88))
        """)

        XCTAssertEqual(txs.count, 1, "the row was not stored at all")
        XCTAssertEqual(txs.first?.amountCents, 0,
            "expected the documented silent zero; got \(txs.first?.amountCents ?? -1)")
    }

    // MARK: - (3, definitively) The trap itself

    /// Takes the real trap by calling the real `MonthTotals.expenseCents`. It
    /// CRASHES THE PROCESS when the chain completes — which is the finding, and
    /// also why it is opt-in: an aborting test takes its whole phase down with it
    /// (that is how 415 tests vanished from a run on 2026-08-26).
    ///
    ///     OVERFLOW_TRAP_PROBE=1 xcodebuild … \
    ///       -only-testing:FinanceTrackerTests/ImportOverflowChainTests/testProbe_realMonthTotalsTraps
    func testProbe_realMonthTotalsTraps() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["OVERFLOW_TRAP_PROBE"] == "1",
            "Opt-in: this test is expected to abort the process. Run it ALONE."
        )
        let (container, context) = try makeStore()
        defer { _ = container }

        _ = try CSVImportService.importCSV(
            modelContext: context,
            data: csv(amounts: [Self.seventeenDigits, Self.seventeenDigits])
        )
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        print("PROBE: about to call MonthTotals.expenseCents on \(txs.count) rows")
        let total = MonthTotals.expenseCents(txs)
        XCTFail("MonthTotals returned \(total) instead of trapping — the chain is broken "
                + "somewhere, and the bricking hypothesis needs re-deriving")
    }
}
