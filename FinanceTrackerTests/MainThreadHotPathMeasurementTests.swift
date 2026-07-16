//
//  MainThreadHotPathMeasurementTests.swift
//  FinanceTrackerTests
//
//  MEASUREMENT, not opinion (BRIEF_1_0_2_QA_BLOCKERS item 2, step 0.3): how much
//  synchronous main-thread work do the hot paths cost against a LARGE ON-DISK
//  store? The device evidence (performBlockAndWait / sqlite3_step on
//  com.apple.main-thread, firing on every save) scales with row count, which is
//  why a fresh simulator can't see it — so this seeds thousands of rows across
//  many months into a real SQLite store (NOT in-memory: in-memory never touches
//  sqlite3_step and would measure nothing).
//
//  Paths timed, chosen from the code, on @MainActor:
//   * ProactiveAlertRefresher.refresh — wired to EVERY ModelContext.didSave
//     (FinanceTrackerApp), fetches the ENTIRE Transaction table unfiltered.
//     Each QuickAdd fires didSave TWICE (transaction save + merchant-learning
//     save), so a keystroke-speed entry pays this cost ×2 per entry.
//   * The full sorted fetch @Query performs for Dashboard/Transactions.
//   * QuickAddSaveService.save end-to-end (the write itself).
//
//  These print numbers; the only assertion is that the measurement ran. The
//  budget judgment (16ms frame / 250ms hang thresholds) belongs in the report.
//

import Foundation
import Testing
import SwiftData
import UserNotifications
@testable import FinanceTracker

@Suite("Main-thread hot-path cost at scale", .serialized)
@MainActor
struct MainThreadHotPathMeasurementTests {

    private final class SilentCenter: NotificationScheduling, @unchecked Sendable {
        func removePending(identifiers: [String]) {}
        func schedule(_ request: UNNotificationRequest) {}
    }

    /// On-disk container in a scratch location, seeded with `count` transactions
    /// spread across ~24 months and a realistic category set.
    private func makeSeededDiskContext(count: Int) throws -> (ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotpath-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("measure.sqlite")
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        var categories: [FinanceTracker.Category] = []
        for (i, name) in ["Food", "Transport", "Home", "Fun", "Health", "Other"].enumerated() {
            let c = FinanceTracker.Category(name: name, kindRaw: "expense", order: i)
            ctx.insert(c); categories.append(c)
        }
        let income = FinanceTracker.Category(name: "Income", kindRaw: "income", order: 99)
        ctx.insert(income)

        let daySeconds: TimeInterval = 24 * 60 * 60
        let start = Date().addingTimeInterval(-730 * daySeconds) // ~24 months back
        for i in 0..<count {
            let isIncome = i % 20 == 0
            let tx = Transaction(
                typeRaw: isIncome ? "income" : "expense",
                amountCents: 500 + (i % 300) * 37,
                currency: "USD",
                date: start.addingTimeInterval(Double(i % 730) * daySeconds),
                category: isIncome ? income : categories[i % categories.count],
                source: nil, taxCents: nil, note: nil,
                merchant: "Merchant \(i % 40)", recurrenceRaw: nil
            )
            ctx.insert(tx)
            if i % 500 == 0 { try ctx.save() }   // keep the pending set bounded
        }
        try ctx.save()
        return (ctx, url)
    }

    private func timeMS(_ runs: Int = 5, _ body: () throws -> Void) rethrows -> (avg: Double, worst: Double) {
        var samples: [Double] = []
        for _ in 0..<runs {
            let t0 = CFAbsoluteTimeGetCurrent()
            try body()
            samples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        }
        return (samples.reduce(0, +) / Double(samples.count), samples.max() ?? 0)
    }

    @Test("Measure: refresher (per didSave), full sorted fetch (per @Query), save e2e",
          arguments: [2_000, 6_000, 12_000])
    func measureHotPaths(rows: Int) throws {
        let (ctx, url) = try makeSeededDiskContext(count: rows)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let center = SilentCenter()
        let defaults = UserDefaults(suiteName: "hotpath-measure")!
        defaults.set(true, forKey: "alertsEnabled")
        defaults.set(400_000, forKey: "monthlyBudgetCents")

        // 1. The per-didSave cost: ProactiveAlertRefresher (full unfiltered fetch
        //    + aggregation). Fires TWICE per QuickAdd entry.
        let refresher = try timeMS {
            ProactiveAlertRefresher.refresh(
                modelContext: ctx, isAllowed: true, defaults: defaults, center: center
            )
        }

        // 2. What @Query does for Dashboard/Transactions: full sorted fetch.
        let sortedFetch = try timeMS {
            _ = try ctx.fetch(FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]))
        }

        // 3. One QuickAdd write end-to-end (resolveCategory fetch + insert + save
        //    + merchant learning). In the app each of its TWO saves then also
        //    triggers (1) via didSave.
        let save = try timeMS(3) {
            _ = try QuickAddSaveService.save(
                parsed: QuickAddParsedInput(
                    amountCents: 1234, typeRaw: "expense",
                    merchant: "Measure Coffee", suggestedCategoryName: nil),
                modelContext: ctx, defaultCurrencyCode: "USD"
            )
        }

        let summary = """
        ⏱ HOTPATH rows=\(rows)
           refresher(per didSave):   avg \(String(format: "%.1f", refresher.avg))ms  worst \(String(format: "%.1f", refresher.worst))ms
           sortedFetch(per @Query):  avg \(String(format: "%.1f", sortedFetch.avg))ms  worst \(String(format: "%.1f", sortedFetch.worst))ms
           quickAddSave(e2e write):  avg \(String(format: "%.1f", save.avg))ms  worst \(String(format: "%.1f", save.worst))ms
           ≈ main-thread cost of ONE QuickAdd entry = save + 2×refresher + @Query re-fetch = \(String(format: "%.0f", save.avg + 2 * refresher.avg + sortedFetch.avg))ms

        """
        print(summary)
        // Simulator test processes share the host filesystem; a plain results
        // file is the reliable way to get numbers out of a Swift Testing run.
        if let data = summary.data(using: .utf8) {
            let out = URL(fileURLWithPath: "/tmp/hotpath-measure.txt")
            if let handle = try? FileHandle(forWritingTo: out) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: out)
            }
        }

        #expect(refresher.avg > 0 && sortedFetch.avg > 0 && save.avg > 0)
    }
}
