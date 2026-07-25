//
//  HangProbe.swift
//  FinanceTracker
//
//  DEBUG-only instrumentation for the 2026-07-25 report: the app froze once and
//  self-recovered during split/analytics testing — the main-thread-hang
//  signature that the 1.0.2 hang brief was supposed to have closed.
//
//  Two candidate paths survived the code read, and they are NOT distinguishable
//  by reasoning — only by measurement:
//
//    A. `AnalyticsView.recompute()` — the screen holds an UNSCOPED @Query over
//       the whole table and recomputes synchronously on the main actor from
//       `.onChange(of: transactions)`, i.e. on EVERY save. The 1.0.2 hang fix
//       scoped DashboardView's queries and moved its full-table pass onto
//       `LedgerAggregator`; AnalyticsView was never touched.
//
//    B. `TransactionsView.filtered` — a non-cached computed property that
//       `grouped` (also non-cached) re-derives, and which BOTH `daySection` and
//       `dayHeader` index into. One body pass therefore recomputes the whole
//       filter many times over, and with a non-empty query each pass touches
//       `tx.splits` per row (a SwiftData to-many fault).
//
//  Do NOT infer which one fired from the code shape. Capture it. Open Console.app
//  (or `log stream`) filtered by subsystem "com.dmitrylogachev.budgetcrab",
//  category "HangProbe", reproduce the freeze, and read the emitted lines:
//
//    PASS name=<span> ms=<duration> main=<yes|no> n=<call index> rows=<count>
//
//  How to read a capture:
//    * `name=Analytics.recompute` with a large ms and `main=yes` → path A. The
//      sub-spans (pulse / breakdown / horizon / pace) say which quarter of it.
//    * `name=Transactions.filtered` lines arriving in long bursts with a fast
//      climbing `n` → path B: the multiplication, not one slow pass, is the cost.
//      The per-call ms may look harmless; SUM the burst before judging it.
//    * Both quiet while the UI is stuck → neither. Widen the probe rather than
//      assuming; a simulator-clean or probe-clean run is NOT an exoneration
//      (2026-07-17 taught this the expensive way).
//
//  `rows` is the size of the collection the span walked, so a duration can be
//  read per-row rather than in the abstract.
//
//  Privacy: only span names, durations, thread-ness, and integer counts are
//  recorded. No merchant, amount, note, or category values are logged.
//

import Foundation

#if DEBUG
import os

enum HangProbe {

    private static let log = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "HangProbe")
    private static let signposter = OSSignposter(
        subsystem: "com.dmitrylogachev.budgetcrab", category: "HangProbe"
    )

    /// Per-span call counters. A climbing index on a span that should fire once
    /// per user action is itself the finding (path B is a multiplication bug,
    /// not a slow-single-pass bug), so the count has to be visible in the log.
    ///
    /// Guarded by a lock rather than assumed main-actor: `filtered` is a View
    /// computed property today, but a probe that traps when someone measures an
    /// off-main span later is a probe that gets deleted instead of used.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [String: Int] = [:]

    private static func nextIndex(for name: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let next = (counts[name] ?? 0) + 1
        counts[name] = next
        return next
    }

    /// Times `body`, logs the span, and returns the value untouched.
    ///
    /// - Parameters:
    ///   - name: stable span name (e.g. "Analytics.recompute").
    ///   - rows: size of the collection walked, or nil when it isn't a walk.
    @discardableResult
    static func measure<T>(_ name: String, rows: Int? = nil, _ body: () throws -> T) rethrows -> T {
        let index = nextIndex(for: name)
        let state = signposter.beginInterval("pass", id: signposter.makeSignpostID())
        let start = DispatchTime.now().uptimeNanoseconds

        // `defer` deliberately not used for the emit: a span that THREW has no
        // meaningful duration to compare against the healthy ones, and logging
        // it anyway would put a fast failure path in the same column as a slow
        // success path. A thrown body is simply not measured.
        let result = try body()

        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        signposter.endInterval("pass", state)

        log.info(
            """
            PASS name=\(name, privacy: .public) \
            ms=\(String(format: "%.2f", elapsedMs), privacy: .public) \
            main=\(Thread.isMainThread ? "yes" : "no", privacy: .public) \
            n=\(index, privacy: .public) \
            rows=\(rows.map(String.init) ?? "-", privacy: .public)
            """
        )
        return result
    }

    /// Resets the call counters so a fresh reproduction starts from n=1.
    static func resetCounts() {
        lock.lock()
        defer { lock.unlock() }
        counts.removeAll()
    }
}
#endif

/// Call-site shim so instrumented code reads the same in both configurations.
/// In Release this is `body()` with no wrapper left behind — the probe cannot
/// cost a shipping build anything, which is what makes it safe to leave the
/// call sites in place after the investigation closes.
@inline(__always)
@discardableResult
func hangProbe<T>(_ name: String, rows: Int? = nil, _ body: () throws -> T) rethrows -> T {
    #if DEBUG
    return try HangProbe.measure(name, rows: rows, body)
    #else
    return try body()
    #endif
}
