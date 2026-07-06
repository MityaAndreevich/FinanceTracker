//
//  ChartGuards.swift
//  FinanceTracker
//
//  Single choke-point that keeps degenerate / non-finite values from ever
//  reaching Swift Charts. Charts traps (EXC_BREAKPOINT, inside its scale/layout
//  compute) on two classes of bad input:
//
//    1. A non-finite mark value or scale bound (NaN, ±inf) — e.g. a fraction
//       computed as `amount / total` when `total == 0`.
//    2. A DEGENERATE scale domain — a zero-width numeric/date range (a single
//       data point fed to an interpolated line/area, whose date domain collapses
//       to one instant and whose `catmullRom` tangent divides by a 0 distance),
//       or a pie/donut whose slice magnitudes sum to 0 (each sector angle is
//       `value / 0` → NaN sweep).
//
//  Every chart's data must pass through here before it is handed to a mark, so no
//  view can independently reintroduce the crash. This is the fix for the device
//  EXC_BREAKPOINT captured inside `Charts` during render (BRIEF: NaN-frame crash).
//
//  NOTE: our money is stored as `Int` cents, which is always finite — so the
//  concrete traps we hit are the *degenerate domain* cases (single-point line,
//  zero-total donut), not literal NaN. `finite(_:)` guards any future
//  Double-valued mark/scale bound.
//

import Foundation

enum ChartGuards {

    /// A continuous chart (an interpolated line/area, or any chart with a time /
    /// numeric x-axis) needs at least two points. With one point the auto-computed
    /// domain is zero-width and Charts recurses on its "nice tick" scale math;
    /// `catmullRom` / `monotone` interpolation additionally divides by the
    /// inter-point distance, which is 0. Callers MUST render a placeholder (never
    /// an empty `Chart`) when this returns `false`.
    static func canRenderContinuous(pointCount: Int) -> Bool {
        pointCount >= 2
    }

    /// Coerce a `Double` mark value / scale bound to a finite number (NaN and ±inf
    /// collapse to 0). Preserves sign — a legitimately negative net stays negative.
    static func finite(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    /// Clamp a computed view dimension (width / height) to a finite value `>= 0`,
    /// so a NaN/negative never reaches SwiftUI's layout (`Invalid frame dimension`).
    static func dimension(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    /// Sanitize pie/donut slice magnitudes for a `SectorMark`.
    ///
    /// Drops slices whose magnitude is not strictly positive (a 0-magnitude sector
    /// contributes nothing but drags the total toward the 0/0 sweep-angle trap),
    /// then returns the survivors **only if their total is positive**. An empty
    /// result is the caller's signal to render a placeholder — NOT an empty
    /// `Chart`, which would still build a degenerate angular domain.
    static func renderableSlices<T>(_ items: [T], magnitude: (T) -> Int) -> [T] {
        let kept = items.filter { magnitude($0) > 0 }
        let total = kept.reduce(0) { $0 + magnitude($1) }
        return total > 0 ? kept : []
    }
}
