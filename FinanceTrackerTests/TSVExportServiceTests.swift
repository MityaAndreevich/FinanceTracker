//
//  TSVExportServiceTests.swift
//  FinanceTrackerTests
//
//  The premium "Excel export" — a whole-ledger write of every amount the user
//  has — shipped through 1.0.5 with ZERO tests (COVERAGE_MATRIX.md §2 row 1),
//  the same shape as the PDF export that clipped amounts for three versions.
//
//  Every assertion here is a PRESENCE assertion on the bytes the file contains.
//  Commissioned 2026-09-21: two tests were red against the code as shipped
//  (the date formatter followed the device locale; the filename said
//  "FinanceTracker"); the rest were commissioned by mutation — see the Phase 0
//  report for which mutant each one caught.
//

import Foundation
import SwiftData
import Testing
@testable import FinanceTracker

@Suite("TSV export")
@MainActor
struct TSVExportServiceTests {

    // MARK: - Fixture

    /// The container must stay alive for the test's whole body — returning only
    /// a context produces a message-less EXC_BREAKPOINT.
    struct Store {
        let container: ModelContainer
        let context: ModelContext
        let food: FinanceTracker.Category
        let home: FinanceTracker.Category
    }

    private func makeStore() throws -> Store {
        let schema = Schema([Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let food = FinanceTracker.Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        let home = FinanceTracker.Category(name: "Home", kindRaw: "expense", icon: nil, order: 2)
        context.insert(food)
        context.insert(home)
        try context.save()
        return Store(container: container, context: context, food: food, home: home)
    }

    /// A date on a known Gregorian calendar day in the current time zone, so the
    /// expected day string is derived independently of the formatter under test.
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @discardableResult
    private func insert(
        _ store: Store, cents: Int, type: String = "expense", date: Date = Date(),
        category: FinanceTracker.Category? = nil, source: Source? = nil,
        merchant: String? = nil, note: String? = nil
    ) throws -> Transaction {
        let tx = Transaction(
            typeRaw: type, amountCents: cents, currency: "USD", date: date,
            category: category ?? store.food, source: source, taxCents: nil,
            note: note, merchant: merchant
        )
        store.context.insert(tx)
        try store.context.save()
        return tx
    }

    private func rows(_ result: TSVExportResult) throws -> [[String]] {
        let text = try #require(String(data: result.data, encoding: .utf8))
        return text.components(separatedBy: "\n").map { $0.components(separatedBy: "\t") }
    }

    private static let header = ["Date", "Type", "Amount", "Currency", "Category", "Source", "Merchant", "Note", "Split", "Transaction ID"]

    // MARK: - Shape

    @Test("an empty ledger exports exactly the ten-column header and nothing else")
    func emptyLedgerIsHeaderOnly() throws {
        let store = try makeStore()
        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(rows == [Self.header])
    }

    @Test("every row has exactly ten cells, in header order; an unsplit row has an empty Split cell and its own ID")
    func everyRowHasTenCells() throws {
        let store = try makeStore()
        let card = Source(name: "Visa")
        store.context.insert(card)
        let tx = try insert(store, cents: 1_234, date: day(2026, 3, 5), source: card, merchant: "Cafe", note: "Lunch")
        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(rows.count == 2)
        #expect(rows[0] == Self.header)
        #expect(rows[1] == ["2026-03-05", "expense", "12.34", "USD", "Food", "Visa", "Cafe", "Lunch", "", tx.uuid.uuidString])
    }

    // MARK: - Money

    @Test("amounts are plain decimals with a point, no grouping, sign preserved, no truncation at the extremes",
          arguments: [
            (1_234, "12.34"), (100, "1"), (5, "0.05"), (0, "0"), (-1_234, "-12.34"),
            (123_456_789, "1234567.89"),
            (Int.max, "92233720368547758.07"),
            (Int.min, "-92233720368547758.08"),
          ])
    func amountFormatting(cents: Int, expected: String) throws {
        let store = try makeStore()
        try insert(store, cents: cents, type: cents < 0 ? "expense" : "income")
        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(rows[1][2] == expected)
    }

    @Test("the amount cell is what Shared/Money.swift produces — one formatting path, not a private twin")
    func amountsGoThroughMoney() throws {
        let store = try makeStore()
        for cents in [1, 99, 1_000, -250_075, Int.max] {
            try insert(store, cents: cents)
        }
        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        let amounts = Set(rows.dropFirst().map { $0[2] })
        let viaMoney = Set([1, 99, 1_000, -250_075, Int.max].map { Money.plainDecimalString(cents: $0) })
        #expect(amounts == viaMoney)
    }

    @Test("the Amount column sums to the ledger — a split transaction is one row PER PART, under the part's category (D47)")
    func amountColumnSumsToTheLedger() throws {
        let store = try makeStore()
        let order = try insert(store, cents: 5_800, merchant: "Amazon")
        let s1 = TransactionSplit(amountCents: 4_000, category: store.home, note: "cable", order: 0)
        let s2 = TransactionSplit(amountCents: 1_800, category: store.food, note: "vitamins", order: 1)
        store.context.insert(s1)
        store.context.insert(s2)
        s1.parent = order
        s2.parent = order
        try insert(store, cents: 700, merchant: "Kiosk")
        try store.context.save()

        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(rows.count == 4)   // header + 2 parts + 1 unsplit
        let amounts = rows.dropFirst().map { $0[2] }
        #expect(amounts.sorted() == ["18", "40", "7"])
        let parts = rows.filter { $0[6] == "Amazon" }
        #expect(parts.map { $0[4] } == ["Home", "Food"])           // the part's category, in split order
        #expect(parts.map { $0[8] } == ["1 of 2", "2 of 2"])
        #expect(Set(parts.map { $0[9] }) == [order.uuid.uuidString])   // one purchase, one ID
        let kiosk = try #require(rows.first { $0[6] == "Kiosk" })
        #expect(kiosk[8] == "")
    }

    // MARK: - Locale

    @Test("the date is a Gregorian yyyy-MM-dd day, whatever the device locale's calendar or digits")
    func dateIsGregorianISODay() throws {
        let store = try makeStore()
        try insert(store, cents: 1, date: day(2026, 12, 31))
        try insert(store, cents: 2, date: day(2024, 2, 29))
        let rows = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(rows.dropFirst().map { $0[0] }.sorted() == ["2024-02-29", "2026-12-31"])

        // The device locale cannot be changed inside a unit test, so the property
        // that makes the assertion above hold on a th_TH (Buddhist calendar) or
        // ar_EG (Arabic-Indic digits) device is pinned directly.
        let formatter = TSVExportService.dateFormatter
        #expect(formatter.locale.identifier == "en_US_POSIX")
        #expect(formatter.calendar.identifier == .gregorian)
    }

    // MARK: - Delimiter collisions

    @Test("tabs and newlines inside merchant, note, category and account never add a column or a row")
    func delimiterCollisionsAreNeutralised() throws {
        let store = try makeStore()
        let odd = FinanceTracker.Category(name: "Eating\tout\nlate", kindRaw: "expense", icon: nil, order: 9)
        store.context.insert(odd)
        let account = Source(name: "Card\ttwo\r\nline")
        store.context.insert(account)
        try insert(store, cents: 100, category: odd, source: account,
                   merchant: "Joe's\t\"Diner\", downtown", note: "line one\nline two\r\nline three")
        try insert(store, cents: 200, merchant: "plain")

        let result = try TSVExportService.makeTSV(modelContext: store.context, scope: .all)
        let rows = try rows(result)
        #expect(rows.count == 3, "a newline in a cell became a row")
        for row in rows { #expect(row.count == 10, "a tab in a cell became a column: \(row)") }

        // `count > 6` so a mutant that lets a newline split a row fails by
        // assertion, not by an index trap (host crash report 2026-09-21 17:14).
        let joe = try #require(rows.first { $0.count > 6 && $0[6].hasPrefix("Joe") })
        #expect(joe[6] == "Joe's \"Diner\", downtown")   // quotes and commas are NOT special in TSV
        #expect(joe[7] == "line one line two  line three")
        #expect(joe[4] == "Eating out late")
        #expect(joe[5] == "Card two  line")
    }

    // MARK: - Scope

    @Test("month scope keeps this month's rows and drops last month's")
    func monthScopeFilters() throws {
        let store = try makeStore()
        let now = Date()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        try insert(store, cents: 111, date: now, merchant: "now")
        try insert(store, cents: 222, date: lastMonth, merchant: "then")

        let month = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .month))
        #expect(month.dropFirst().map { $0[6] } == ["now"])
        let all = try rows(TSVExportService.makeTSV(modelContext: store.context, scope: .all))
        #expect(Set(all.dropFirst().map { $0[6] }) == ["now", "then"])
    }

    @Test("the shared file carries the product's name, and the scope")
    func filenameIsBranded() throws {
        let store = try makeStore()
        #expect(try TSVExportService.makeTSV(modelContext: store.context, scope: .all).filename == "BudgetCrab_All.tsv")
        #expect(try TSVExportService.makeTSV(modelContext: store.context, scope: .month).filename == "BudgetCrab_ThisMonth.tsv")
    }

    // MARK: - Round trip

    @Test("the importer does not read TSV: it sees the file as one column and recognises no header — so it cannot mis-import it")
    func importerDoesNotReadTSV() throws {
        let store = try makeStore()
        try insert(store, cents: 1_234, merchant: "Cafe")
        let result = try TSVExportService.makeTSV(modelContext: store.context, scope: .all)

        let preview = try #require(CSVImportService.parsePreview(data: result.data))
        #expect(preview.header.count == 1, "the CSV parser split on tabs — TSV round-trip behaviour changed")
        #expect(preview.header[0].hasPrefix("Date\tType\tAmount"))
        // `prepare` only skips a header it recognises as ours; a TSV header is not.
        let preamble = try CSVImportService.prepare(modelContext: store.context, data: result.data)
        #expect(preamble.startIndex == 0)
    }
}

// MARK: - D47 — category totals derived from the file equal the app's (split-heavy fixture)

/// The founder's approval condition for 1.0.6 (BRIEF_MASTER_2026-09-21.md, Phase 1
/// addendum): "TSV-derived category totals == Analytics == report PDF, for the
/// same period. Commission it red against today's TSV first — it should fail
/// exactly on D47."
///
/// COMMISSIONED RED 2026-09-21 against the one-row-per-transaction TSV: Food read
/// 12 700 from the file against 9 400 in the app — the split parts' money was
/// filed under the parent's category. See the commit that closed D47.
@Suite("TSV export — category totals equal the app's (D47)")
@MainActor
struct TSVSplitEqualityTests {

    private func rows(_ data: Data) throws -> (header: [String], rows: [[String]]) {
        let text = try #require(String(data: data, encoding: .utf8))
        let lines = text.components(separatedBy: "\n").map { $0.components(separatedBy: "\t") }
        return (lines[0], Array(lines.dropFirst()))
    }

    /// Σ Amount per Category name, from the FILE — what a user computes in Excel.
    private func fileCategoryTotals(_ data: Data) throws -> [String: Int] {
        let (header, rows) = try rows(data)
        let amountCol = try #require(header.firstIndex(of: "Amount"))
        let categoryCol = try #require(header.firstIndex(of: "Category"))
        let typeCol = try #require(header.firstIndex(of: "Type"))
        var totals: [String: Int] = [:]
        for r in rows where r[typeCol] == "expense" {
            let cents = try #require(Money.parseCents(from: r[amountCol]), "unparseable amount cell \(r[amountCol])")
            totals[r[categoryCol], default: 0] += cents
        }
        return totals
    }

    @Test("Σ Amount by Category in the file == CategoryBreakdown == the report's category table")
    func fileTotalsEqualAppTotals() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        #expect(f.hasSplits)
        let period = ReportPeriod.month(containing: f.now)
        let cal = Calendar.current

        let tsv = try TSVExportService.makeTSV(modelContext: f.container.mainContext, period: period)
        let fromFile = try fileCategoryTotals(tsv.data)

        // Analytics' fold, by display name (the fixture's categories are custom names).
        let monthTxs = try f.monthTransactions()
        let analytics = try #require(CategoryBreakdown.buckets(transactions: monthTxs, includeIncome: false))
        let analyticsByName = Dictionary(uniqueKeysWithValues: analytics.map { ($0.value.category.displayNameOrFallback(), $0.value.cents) })

        // The report's table, same period.
        let categories = try f.container.mainContext.fetch(FetchDescriptor<FinanceTracker.Category>())
        let input = LedgerAggregator.makeReportInput(transactions: try f.allTransactions(), categories: categories,
                                                     period: period, calendar: cal, bundle: .main)
        let snapshot = try #require(ReportBuilder.build(input: input, period: period, calendar: cal, monthlyBudgetCents: 0))
        let reportByName = Dictionary(uniqueKeysWithValues: snapshot.expenseCategories.map { ($0.label.name, $0.cents) })

        #expect(fromFile == analyticsByName)
        #expect(fromFile == reportByName)
        #expect(fromFile == ["Food": 9_400, "Home": 6_500, "Health": 4_800])   // the hand sums
    }

    @Test("Σ Amount over the whole file still equals the ledger — splitting moves money, never creates it")
    func fileSumEqualsLedger() throws {
        let f = try SplitMirrorFixture.make(applySplitsToStore: true)
        let period = ReportPeriod.month(containing: f.now)
        let tsv = try TSVExportService.makeTSV(modelContext: f.container.mainContext, period: period)
        let (header, rows) = try rows(tsv.data)
        let amountCol = try #require(header.firstIndex(of: "Amount"))
        let typeCol = try #require(header.firstIndex(of: "Type"))
        let expense = try rows.filter { $0[typeCol] == "expense" }.map { try #require(Money.parseCents(from: $0[amountCol])) }.reduce(0, +)
        #expect(expense == f.expectedMonthExpenseCents)
    }
}
