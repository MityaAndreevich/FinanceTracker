//
//  MainThreadStallMonitor.swift
//  FinanceTracker
//
//  DEBUG-only instrument for one question: FOR HOW MUCH OF A GIVEN STRETCH IS THE
//  UI UNABLE TO RESPOND TO A TOUCH?
//
//  Why `HangProbe` cannot answer it. `HangProbe` times spans we chose to wrap, so
//  it can only report what it was pointed at, and its per-span durations invite a
//  "was any single span long?" reading. That question is a false dichotomy: a
//  hundred consecutive 300ms main-thread blocks with no runloop turn between them
//  is, to the person holding the phone, the same frozen app as one 5-second
//  block — and a 5-second bar reports it as fine. Blocked FRACTION is the honest
//  metric, and it needs an instrument that observes the runloop itself rather
//  than any particular code path.
//
//  How it works. A repeating timer is scheduled on the main runloop in
//  `.common` mode. While the main thread is blocked the timer cannot fire, so the
//  gap between consecutive ticks IS the length of time the UI could not have
//  responded to a touch. Nothing needs to be instrumented for this to be seen —
//  including code we never thought to wrap, which is the point.
//
//  A gap is counted as blocked time beyond the nominal interval, with a small
//  tolerance for ordinary scheduling jitter. `longestGapMs` is the longest
//  unbroken stretch with no runloop turn at all.
//
//  Reading a report:
//    * `blockedPct` high (say >50%) => a freeze, regardless of how it decomposes.
//    * `longestGapMs` over ~5000 => watchdog territory on a cold path (0x8badf00d).
//    * many `>250ms` with a small `longestGapMs` => death by a thousand cuts;
//      still a freeze to the user, but a different fix from one long block.
//
//  Privacy: only durations and counts. No ledger content of any kind.
//

#if DEBUG
import Foundation
import OSLog

@MainActor
final class MainThreadStallMonitor {

    static let shared = MainThreadStallMonitor()

    /// Opt-in, so ordinary DEBUG runs pay nothing and the timer cannot perturb
    /// the very measurements other tests take.
    static let argument = "--stall-monitor"
    static var isRequested: Bool { CommandLine.arguments.contains(argument) }

    private let log = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "StallMonitor")

    /// 50ms nominal. Short enough that a 250ms perception-threshold block is
    /// several missed ticks rather than a rounding question, long enough that the
    /// timer itself is not a meaningful main-thread load.
    private let intervalMs: Double = 50
    /// Ordinary scheduling jitter. Below this a late tick is not evidence of
    /// anything and counting it would inflate every report.
    private let toleranceMs: Double = 20

    private var timer: Timer?
    private var lastTick: DispatchTime?
    private var startedAt: DispatchTime?
    private(set) var gapsMs: [Double] = []

    private init() {}

    func startIfRequested() {
        guard Self.isRequested, timer == nil else { return }
        startedAt = DispatchTime.now()
        lastTick = DispatchTime.now()
        let t = Timer(timeInterval: intervalMs / 1000, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` so the monitor keeps observing during scroll and other
        // tracking modes — the states a user is most likely to be in when a
        // freeze is noticed.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        log.info("StallMonitor started interval=\(self.intervalMs, privacy: .public)ms")
    }

    private func tick() {
        let now = DispatchTime.now()
        defer { lastTick = now }
        guard let last = lastTick else { return }
        let gapMs = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000
        gapsMs.append(gapMs)
        if gapMs >= 250 {
            log.info("STALL gapMs=\(String(format: "%.0f", gapMs), privacy: .public)")
            // Also to the file. App stdout and os_log are NOT captured in
            // xcodebuild logs, so a stall recorded only there is a stall nobody
            // can read afterwards — which cost several runs to learn.
            append("STALL gapMs=\(String(format: "%.0f", gapMs))")
        }
    }

    /// Emits the distribution. Call at the end of a measured stretch.
    ///
    /// `blockedMs` sums only the excess beyond the nominal interval, so idle time
    /// is never counted as blocked — a report of 0% on a quiet app is the correct
    /// answer, not a broken instrument.
    func report(_ label: String) {
        guard Self.isRequested, let started = startedAt else { return }
        let now = DispatchTime.now()
        let observedMs = Double(now.uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
        let nominal = intervalMs + toleranceMs

        // The trailing gap, and why omitting it inverts the result.
        //
        // The worst case for this instrument is the main thread being blocked
        // CONTINUOUSLY from start to report: the timer never fires even once,
        // `gapsMs` stays empty, and a naive report says "0% blocked" about a
        // total freeze. Closing the window at report time — treating the stretch
        // since the last tick (or since start, if there was never a tick) as one
        // more gap — is what makes a total freeze read as 100% instead of 0%.
        var gapsMs = self.gapsMs
        let sinceLastTick = Double(now.uptimeNanoseconds - (lastTick ?? started).uptimeNanoseconds) / 1_000_000
        if sinceLastTick > nominal { gapsMs.append(sinceLastTick) }

        let blocked = gapsMs.filter { $0 > nominal }
        let blockedMs = blocked.reduce(0) { $0 + ($1 - intervalMs) }
        let sorted = gapsMs.sorted()
        func pct(_ p: Double) -> Double {
            guard !sorted.isEmpty else { return 0 }
            return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
        }
        let body = """
        STALLREPORT label=\(label) \
        observedMs=\(String(format: "%.0f", observedMs)) \
        blockedMs=\(String(format: "%.0f", blockedMs)) \
        blockedPct=\(String(format: "%.1f", observedMs > 0 ? blockedMs / observedMs * 100 : 0)) \
        ticks=\(gapsMs.count) \
        longestGapMs=\(String(format: "%.0f", sorted.last ?? 0)) \
        p50=\(String(format: "%.0f", pct(0.50))) \
        p90=\(String(format: "%.0f", pct(0.90))) \
        p99=\(String(format: "%.0f", pct(0.99))) \
        over250ms=\(gapsMs.filter { $0 > 250 }.count) \
        over1s=\(gapsMs.filter { $0 > 1000 }.count) \
        over5s=\(gapsMs.filter { $0 > 5000 }.count)
        """
        log.info("\(body, privacy: .public)")
        append(body)
    }

    /// Same /tmp channel HangProbe and MainThreadHangScaleTests already use:
    /// simulator processes share the host filesystem.
    private func append(_ body: String) {
        let url = URL(fileURLWithPath: "/tmp/stall-report.txt")
        let line = body + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func reset() {
        gapsMs.removeAll()
        startedAt = DispatchTime.now()
        lastTick = DispatchTime.now()
    }
}
#endif
