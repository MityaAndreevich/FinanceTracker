//
//  BulkDeleteCostMeasurementTests.swift
//  FinanceTrackerTests
//
//  MEASUREMENT, not opinion: what does a bulk delete cost as a function of row
//  count? Replaces the UI-test vehicle (BulkDeleteStallMeasurementTests), which
//  spent four runs producing an unattributable stall distribution.
//
//  Why a unit test is sufficient here, and why the number it prints IS the
//  main-thread-blocked duration:
//
//    * `TransactionResetService` is `@MainActor` and `reset(in:)` is a plain
//      synchronous func — fetch, a `for` loop of `context.delete`, one `save()`.
//      No `await`, no continuation, no dispatch. Its call site
//      (GeneralSettingView.resetTransactions) calls it inline from a SwiftUI
//      button action, i.e. on the main actor, and does not `Task`-hop.
//    * `DuplicateReviewService.deleteAll(in:)` has the identical shape and is
//      likewise called inline (DuplicateReviewView.deleteAll → perform → try).
//      Its work is ONE synchronous pass; nothing is interleaved with UI, which
//      is why it does not need the UI vehicle either.
//
//  For an operation with that shape there is nothing else the main thread could
//  be doing while it runs, so wall-clock == blocked. The stopwatch is the
//  measurement.
//
//  CAVEAT, stated here because it belongs next to the numbers: this is a scratch
//  on-disk SQLite store in the test host's temp directory, not the real
//  app-group store on a device (different filesystem, different I/O scheduler,
//  no other process holding the store open, faster CPU than an A-series under
//  thermal load). ABSOLUTE numbers may differ on device. The SHAPE of the curve
//  — linear vs quadratic, and roughly where it crosses a few seconds — is what
//  decides severity, and shape survives the difference.
//
//  Three deliberate fidelity choices:
//   1. ON-DISK, never in-memory: an in-memory store never reaches sqlite3_step,
//      which is where the device evidence put the cost.
//   2. COLD CONTEXT: the store is seeded through one container, that container
//      is dropped, and a NEW container + context is opened over the same file to
//      measure. Measuring through the seeding context would time a fully warm
//      row cache — the user's context has almost none of those rows
//      materialized when they tap Reset.
//   3. Both the real service call (authoritative) and a phase-split replica of
//      its body (attribution: fetch vs delete-loop vs save) are timed, on
//      separate freshly-seeded stores. The replica is labeled as such; for the
//      duplicate path the fetch phase IS the real `flagged(in:)`.
//
//  These print numbers. The only assertion is that the work actually happened.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Bulk-delete cost at scale", .serialized)
@MainActor
struct BulkDeleteCostMeasurementTests {

    // Sizes span 8×. Linear ⇒ the 8k/1k ratio lands near 8; quadratic ⇒ near 64.
    private static let sizes = [1_000, 2_000, 4_000, 8_000]

    // MARK: - Store construction

    /// Seeds an on-disk store and returns its URL, having released the seeding
    /// container so the measurement opens cold.
    ///
    /// - Parameters:
    ///   - plain: unflagged rows (the ledger the user already had).
    ///   - flagged: rows with `isPossibleDuplicate == true` (the re-import).
    private func seedStore(plain: Int, flagged: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bulkdelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("measure.sqlite")

        // Scoped so the container is deallocated before the measurement opens
        // its own — otherwise the measured fetch reads a warm coordinator cache.
        try autoreleasepool {
            let container = try makeContainer(at: url)
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false

            var categories: [FinanceTracker.Category] = []
            for (i, name) in ["Food", "Transport", "Home", "Fun", "Health", "Other"].enumerated() {
                let c = FinanceTracker.Category(name: name, kindRaw: "expense", order: i)
                ctx.insert(c)
                categories.append(c)
            }
            let income = FinanceTracker.Category(name: "Income", kindRaw: "income", order: 99)
            ctx.insert(income)

            let daySeconds: TimeInterval = 24 * 60 * 60
            let start = Date().addingTimeInterval(-730 * daySeconds) // ~24 months back

            var inserted = 0
            func insertRows(_ count: Int, isFlagged: Bool) throws {
                for i in 0..<count {
                    let isIncome = i % 20 == 0
                    let tx = Transaction(
                        typeRaw: isIncome ? "income" : "expense",
                        amountCents: 500 + (i % 300) * 37,
                        currency: "USD",
                        date: start.addingTimeInterval(Double(i % 730) * daySeconds),
                        category: isIncome ? income : categories[i % categories.count],
                        source: nil, taxCents: nil, note: nil,
                        merchant: "Merchant \(i % 40)", recurrenceRaw: nil,
                        isPossibleDuplicate: isFlagged
                    )
                    ctx.insert(tx)
                    inserted += 1
                    if inserted % 500 == 0 { try ctx.save() }   // keep the pending set bounded
                }
            }
            try insertRows(plain, isFlagged: false)
            try insertRows(flagged, isFlagged: true)
            try ctx.save()
        }
        return url
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        // Same model set the real synced store uses — TransactionSplit included,
        // because Transaction.splits is a `.cascade` relationship and a schema
        // without it would not exercise the same delete machinery.
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    /// Opens a cold container + context over an already-seeded store.
    private func openCold(_ url: URL) throws -> (ModelContainer, ModelContext) {
        let container = try makeContainer(at: url)
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return (container, ctx)   // container returned so the caller holds it alive
    }

    private func discard(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func ms(_ body: () throws -> Void) rethrows -> Double {
        let t0 = CFAbsoluteTimeGetCurrent()
        try body()
        return (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }

    /// Prints a size→duration curve with the growth exponent, so linear vs
    /// quadratic is readable directly off the output instead of by eyeballing.
    private func report(_ label: String, _ points: [(rows: Int, ms: Double)]) {
        print("\n=== \(label) ===")
        guard let base = points.first else { return }
        for p in points {
            let perRow = p.ms / Double(p.rows) * 1000   // µs/row
            let sizeRatio = Double(p.rows) / Double(base.rows)
            let timeRatio = p.ms / base.ms
            // exponent k such that timeRatio == sizeRatio^k  → 1 linear, 2 quadratic
            let k = sizeRatio > 1 ? log(timeRatio) / log(sizeRatio) : 1
            print(String(
                format: "rows=%5d  total=%9.1f ms  perRow=%7.1f µs  ×rows=%.1f  ×time=%6.1f  k=%.2f",
                p.rows, p.ms, perRow, sizeRatio, timeRatio, k
            ))
        }
    }

    // MARK: - 1. DuplicateReviewService.deleteAll  (measured FIRST: it sits on the
    //            import/acquisition path and is hit by a NEW user unprepared)

    @Test("Measure: DuplicateReviewService.deleteAll vs flagged-row count")
    func measureDuplicateDeleteAll() throws {
        var endToEnd: [(rows: Int, ms: Double)] = []
        var fetchPhase: [(rows: Int, ms: Double)] = []
        var loopPhase: [(rows: Int, ms: Double)] = []
        var savePhase: [(rows: Int, ms: Double)] = []

        for n in Self.sizes {
            // Realistic import shape: the user already had n rows; the re-import
            // added n more, all flagged. Table = 2n, deleted = n.
            let e2eURL = try seedStore(plain: n, flagged: n)
            defer { discard(e2eURL) }
            let elapsed: Double = try {
                let (container, ctx) = try openCold(e2eURL)
                defer { _ = container }
                let t = try ms { try DuplicateReviewService.deleteAll(in: ctx) }
                let remaining = try DuplicateReviewService.flaggedCount(in: ctx)
                #expect(remaining == 0)
                let total = try ctx.fetchCount(FetchDescriptor<Transaction>())
                #expect(total == n)   // only the flagged copies went
                return t
            }()
            endToEnd.append((n, elapsed))

            // Phase attribution on a second, identically seeded, cold store.
            let phaseURL = try seedStore(plain: n, flagged: n)
            defer { discard(phaseURL) }
            let (container, ctx) = try openCold(phaseURL)
            defer { _ = container }
            var rows: [Transaction] = []
            let tFetch = try ms { rows = try DuplicateReviewService.flagged(in: ctx) }   // the REAL fetch
            let tLoop = ms { for tx in rows { ctx.delete(tx) } }
            let tSave = try ms { try ctx.save() }
            #expect(rows.count == n)
            fetchPhase.append((n, tFetch))
            loopPhase.append((n, tLoop))
            savePhase.append((n, tSave))
        }

        report("DuplicateReviewService.deleteAll — END TO END (real service, cold context)", endToEnd)
        report("  phase: flagged() fetch [real]", fetchPhase)
        report("  phase: delete loop [replica]", loopPhase)
        report("  phase: save() [replica]", savePhase)
    }

    // MARK: - 2. TransactionResetService.reset

    @Test("Measure: TransactionResetService.reset vs ledger size")
    func measureTransactionReset() throws {
        var endToEnd: [(rows: Int, ms: Double)] = []
        var fetchPhase: [(rows: Int, ms: Double)] = []
        var loopPhase: [(rows: Int, ms: Double)] = []
        var savePhase: [(rows: Int, ms: Double)] = []

        for n in Self.sizes {
            let e2eURL = try seedStore(plain: n, flagged: 0)
            defer { discard(e2eURL) }
            let elapsed: Double = try {
                let (container, ctx) = try openCold(e2eURL)
                defer { _ = container }
                var outcome: TransactionResetService.Outcome = .failure(remaining: -1)
                let t = ms { outcome = TransactionResetService.reset(in: ctx) }
                #expect(outcome == .success)
                return t
            }()
            endToEnd.append((n, elapsed))

            // Replica of reset()'s body, phase-split, on a second cold store.
            let phaseURL = try seedStore(plain: n, flagged: 0)
            defer { discard(phaseURL) }
            let (container, ctx) = try openCold(phaseURL)
            defer { _ = container }
            var all: [Transaction] = []
            let tFetch = ms { all = (try? ctx.fetch(FetchDescriptor<Transaction>())) ?? [] }
            let tLoop = ms { for tx in all { ctx.delete(tx) } }
            let tSave = try ms { try ctx.save() }
            #expect(all.count == n)
            fetchPhase.append((n, tFetch))
            loopPhase.append((n, tLoop))
            savePhase.append((n, tSave))
        }

        report("TransactionResetService.reset — END TO END (real service, cold context)", endToEnd)
        report("  phase: full fetch [replica]", fetchPhase)
        report("  phase: delete loop [replica]", loopPhase)
        report("  phase: save() [replica]", savePhase)
    }
}
