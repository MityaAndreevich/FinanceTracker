//
//  ChartDebug.swift
//  FinanceTracker
//
//  On-device bisection harness for the Charts EXC_BREAKPOINT.
//
//  WHY THIS EXISTS: the simulator has never reproduced this crash — not with
//  degenerate data (ChartGuardsTests), not with a degenerate frame
//  (ChartDegenerateFrameTests), and not with a degenerate continuous DOMAIN
//  (ChartDegenerateDomainTests, which renders the real Pulse/Horizon with an
//  all-equal Y series in a valid box and passes clean). Charts is also
//  unsymbolicatable, so the device report gives us an address, not a line. That
//  leaves on-device bisection as the only deterministic way to attribute it.
//
//  The toggles are persisted in UserDefaults and driven from Settings → Debug,
//  so ONE build covers every bisection position. Flipping a switch and hammering
//  QuickAdd is a two-second experiment instead of a rebuild-and-reinstall cycle.
//
//  Protocol:
//    0. Baseline. Domain guard OFF, all charts ON → confirm the build still
//       crashes. If it does NOT, nothing below means anything.
//    1. Domain guard ON, all charts ON → crash gone? Root cause is the degenerate
//       continuous domain; we are done and no bisection is needed.
//    2. Still crashing → Hide all charts. No crash ⇒ it IS a chart: re-enable one
//       at a time to find which. Still crashing ⇒ it is NOT a chart; report.
//
//  In RELEASE every accessor below is a compile-time constant (`true`), so the
//  charts and the domain guard behave exactly as shipped and none of this
//  machinery survives into the store build.
//

import Foundation
import SwiftUI

/// The charts that can independently be switched off on device.
enum BisectableChart: String, CaseIterable, Identifiable {
    case dashboardDonut
    case pulse
    case horizon
    case breakdownDonut
    case daySpending

    var id: String { rawValue }

    /// Deliberately un-localized: this is a debug surface, not product UI.
    var title: String {
        switch self {
        case .dashboardDonut: return "Dashboard donut"
        case .pulse:          return "Analytics · Pulse (area/line)"
        case .horizon:        return "Analytics · Horizon (line/area)"
        case .breakdownDonut: return "Analytics · Breakdown donut"
        case .daySpending:    return "Day spending sheet (bars)"
        }
    }

    /// Whether this chart has a continuous (numeric/date) scale — the class the
    /// device stack points at. The donuts are angular; they are in the list only
    /// so "hide all" really means all.
    var isContinuous: Bool {
        switch self {
        case .pulse, .horizon, .daySpending: return true
        case .dashboardDonut, .breakdownDonut: return false
        }
    }
}

#if DEBUG

/// Observable so a toggle flipped in Settings re-renders the charts on the other
/// tabs without an app restart.
final class ChartDebug: ObservableObject {
    static let shared = ChartDebug()

    private static let hiddenKey = "debug_charts_hidden"
    private static let domainGuardKey = "debug_chart_domain_guard"

    private let defaults = UserDefaults.standard

    private init() {
        // The domain guard ships ON. It defaults ON here too, so a DEBUG build
        // behaves like the real one until someone deliberately turns it off to
        // establish the crashing baseline.
        if defaults.object(forKey: Self.domainGuardKey) == nil {
            defaults.set(true, forKey: Self.domainGuardKey)
        }
    }

    // MARK: - Per-chart visibility

    @Published private var revision = 0

    private var hiddenIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.hiddenKey) ?? []) }
        set {
            defaults.set(Array(newValue), forKey: Self.hiddenKey)
            revision &+= 1
        }
    }

    func isEnabled(_ chart: BisectableChart) -> Bool {
        !hiddenIDs.contains(chart.rawValue)
    }

    func setEnabled(_ chart: BisectableChart, _ enabled: Bool) {
        var ids = hiddenIDs
        if enabled { ids.remove(chart.rawValue) } else { ids.insert(chart.rawValue) }
        hiddenIDs = ids
    }

    func hideAllCharts() {
        hiddenIDs = Set(BisectableChart.allCases.map(\.rawValue))
    }

    func showAllCharts() {
        hiddenIDs = []
    }

    var allChartsHidden: Bool {
        hiddenIDs.count == BisectableChart.allCases.count
    }

    // MARK: - Domain guard

    /// When OFF, continuous charts fall back to the old count-only check
    /// (`pointCount >= 2`) — i.e. the pre-fix behaviour, which hands Charts a
    /// zero-width domain. This is the switch that tests the hypothesis directly.
    var domainGuardEnabled: Bool {
        get { defaults.bool(forKey: Self.domainGuardKey) }
        set {
            defaults.set(newValue, forKey: Self.domainGuardKey)
            revision &+= 1
        }
    }
}

#endif

// MARK: - Call sites
//
// The charts call these two functions and nothing else, so RELEASE compiles the
// whole harness away.

enum ChartBisection {

    /// Whether a given chart should be built at all.
    static func isEnabled(_ chart: BisectableChart) -> Bool {
        #if DEBUG
        return ChartDebug.shared.isEnabled(chart)
        #else
        return true
        #endif
    }

    /// Whether the degenerate-domain guard is active. Always true in RELEASE.
    static var domainGuardEnabled: Bool {
        #if DEBUG
        return ChartDebug.shared.domainGuardEnabled
        #else
        return true
        #endif
    }

    /// The single question every continuous chart asks before it draws: is this
    /// series safe to hand to a Swift Charts scale?
    ///
    /// With the guard on, that means a real, finite, non-zero-width domain. With
    /// it off (DEBUG bisection only) it degrades to the old count-only check, which
    /// is what lets the founder reproduce the crashing baseline on demand.
    static func canRenderSeries(cents: [Int]) -> Bool {
        guard domainGuardEnabled else {
            return ChartGuards.canRenderContinuous(pointCount: cents.count)
        }
        return ChartGuards.canRenderContinuous(cents: cents)
    }
}
