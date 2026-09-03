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

    func testImportREJECTSAmountsTheUIWouldRefuse() throws {
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

        // BEFORE: imported=2, each stored as 9223372036854775800 — six orders of
        // magnitude above the UI's cap, no error, no flag. That is what bricked
        // the app. Now the rows are rejected with a reason and nothing is stored.
        XCTAssertEqual(txs.count, 0,
            "an amount above the app's ceiling was STORED (\(txs.map(\.amountCents))). "
            + "Rejection is the rule: never clamped, never zeroed.")
        XCTAssertEqual(result.imported, 0, "an out-of-range row was counted as imported")
        XCTAssertEqual(result.skipped, 2, "both out-of-range rows should be skipped")
        XCTAssertNotNil(result.firstError,
            "the row was rejected silently — the user must be told which line and why")
        XCTAssertEqual(uiCap, AmountParsing.maxAmountCents,
            "the import ceiling and the editor's ceiling have drifted apart, which is "
            + "how import came to accept a row the editor could not save")
    }

    // MARK: - (6) What does a 22-digit amount store?

    func testTwentyTwoDigitAmountIsRejectedRatherThanZeroed() throws {
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

        // BEFORE: imported=1 with amountCents = 0 — `Int(intDigits) ?? 0`. The user
        // was told the import succeeded and their ledger silently held a zero.
        XCTAssertEqual(txs.count, 0,
            "a 22-digit amount was stored as \(txs.first?.amountCents ?? -1). A value we "
            + "cannot read is not zero.")
        XCTAssertEqual(result.imported, 0, "an unreadable amount was counted as imported")
        XCTAssertNotNil(result.firstError, "the unreadable row was rejected silently")
    }

    // MARK: - RECOVERY — the six launch-path sums, on a store that is ALREADY poisoned
    //
    // Prevention stops new rows. It does nothing for a user who already has one:
    // the app has been in the store since 10 July. These rows are inserted
    // DIRECTLY, bypassing import, because that is exactly the state such a user
    // is in — a store written by a build that had no ceiling.
    //
    // Each site must REPORT rather than trap. A trap here crashes the process, so
    // if any of these regress the failure is a crashed test run, not a red
    // assertion — which is itself the reason the enumeration of these sites had to
    // be exhaustive.

    private func poisonedStore() throws -> (ModelContainer, ModelContext, [Transaction]) {
        let (container, context) = try makeStore()
        let category = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        context.insert(category)
        // Two rows that individually fit Int and together do not.
        for i in 0..<2 {
            context.insert(
                Transaction(
                    typeRaw: "expense",
                    amountCents: Int.max - 8,
                    currency: "USD",
                    date: Date(),
                    category: category,
                    merchant: "poisoned \(i)"
                )
            )
        }
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        return (container, context, txs)
    }

    /// Sites 1 and 2 — the dashboard's hero.
    func testMonthTotalsReportsOverflowInsteadOfTrapping() throws {
        let (container, _, txs) = try poisonedStore()
        defer { _ = container }
        XCTAssertNil(MonthTotals.expenseCents(txs),
                     "expenseCents returned a number for a sum that cannot be represented")
        // Income is empty here, so it must still produce a real total: the guard
        // must not turn every total into nil.
        XCTAssertEqual(MonthTotals.incomeCents(txs), 0,
                       "incomeCents must still compute when ITS own rows are in range")
    }

    /// Site 3 — the category accumulator that no grep found.
    func testCategorySpendBucketsReportsOverflowInsteadOfTrapping() throws {
        let (container, _, txs) = try poisonedStore()
        defer { _ = container }
        XCTAssertNil(MonthTotals.categorySpendBuckets(txs),
                     "categorySpendBuckets returned buckets for a sum that cannot be represented")
    }

    /// Sites 4 and 5 — the alert path, which runs on every .active transition.
    func testSafeToSpendAndCategoryLimitsBailInsteadOfTrapping() throws {
        let (container, _, txs) = try poisonedStore()
        defer { _ = container }

        let now = Date()
        XCTAssertNil(SafeToSpend.aggregate(entries: SafeToSpend.entries(from: txs), now: now),
                     "SafeToSpend.aggregate returned a total it could not compute")

        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let rows = txs.flatMap { CategoryAttribution.rows(for: $0) }
        XCTAssertNil(
            CategoryLimitPolicy.spentByCategory(rows: rows, monthStart: monthStart,
                                                today: cal.startOfDay(for: now), calendar: cal),
            "spentByCategory returned a spend map it could not compute")
    }

    /// Site 6 — the composition the refresher actually calls. Bailing here is what
    /// stops the launch-time crash, and "no alert" is the entire correct
    /// behaviour: no screen, no state, no string.
    func testLedgerAggregateBailsSoNoAlertIsScheduled() throws {
        let (container, _, txs) = try poisonedStore()
        defer { _ = container }
        XCTAssertNil(
            SafeToSpend.makeAggregate(transactions: txs, limitedCategories: [], now: Date()),
            "makeAggregate returned an aggregate built from a total it could not compute")
    }

    /// The guard must not fire on ordinary data — a recovery that made every
    /// total unavailable would be its own outage.
    func testOrdinaryLedgerStillComputesEveryTotal() throws {
        let (container, context) = try makeStore()
        defer { _ = container }
        let category = Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        context.insert(category)
        context.insert(Transaction(typeRaw: "expense", amountCents: 12_345, currency: "USD",
                                   date: Date(), category: category, merchant: "Lunch"))
        context.insert(Transaction(typeRaw: "income", amountCents: 500_000, currency: "USD",
                                   date: Date(), category: category, merchant: "Salary"))
        let txs = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(MonthTotals.expenseCents(txs), 12_345)
        XCTAssertEqual(MonthTotals.incomeCents(txs), 500_000)
        XCTAssertNotNil(MonthTotals.categorySpendBuckets(txs))
        XCTAssertNotNil(SafeToSpend.aggregate(entries: SafeToSpend.entries(from: txs), now: Date()))
        XCTAssertNotNil(SafeToSpend.makeAggregate(transactions: txs, limitedCategories: [], now: Date()))
    }
}
