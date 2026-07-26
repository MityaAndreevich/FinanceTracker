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
import SwiftUI

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

    /// Whether a continuous series spans a domain a scale can actually be mapped
    /// onto: at least two points, every value finite, and a **strictly positive
    /// spread** (`min < max`).
    ///
    /// The count check above is necessary but NOT sufficient, and that gap is the
    /// second half of this crash. No chart in this app sets an explicit
    /// `.chartYScale(domain:)`, so Charts derives the domain from the data — and N
    /// *identical* points collapse it to `[v, v]`, zero height. Charts then
    /// subdivides a zero extent hunting for "nice" ticks and traps inside its own
    /// scale math, with no app frame on the stack.
    ///
    /// This is an ordinary state, not an exotic one, because both real series are
    /// dense and zero-filled: Pulse is every day of the month (0 on quiet days),
    /// Horizon is 12 months (0 on quiet months). A user who only logs expenses has
    /// a flat-zero *income* series; a day whose expense is cancelled by an equal
    /// income nets the whole Pulse series to zero.
    static func canRenderContinuous(values: [Double]) -> Bool {
        guard values.count >= 2 else { return false }
        guard values.allSatisfy({ $0.isFinite }) else { return false }
        guard let lo = values.min(), let hi = values.max() else { return false }
        return lo < hi
    }

    /// `Int`-cents form — our money is stored as `Int`, so this is what every real
    /// caller passes. Deliberately a distinct argument label rather than an
    /// overload on `values:`: an `[0, 0, 0]` literal is ambiguous between `[Int]`
    /// and `[Double]`, and a guard this load-bearing must never fail to compile
    /// for a reason that has nothing to do with charts.
    static func canRenderContinuous(cents: [Int]) -> Bool {
        canRenderContinuous(values: cents.map(Double.init))
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

    /// The angular inset a donut can safely ask for, given the magnitudes it is
    /// about to plot.
    ///
    /// `angularInset` is a LINEAR inset in points, taken off BOTH angular edges
    /// of every sector. At the inner radius it therefore costs an angle of
    /// `inset / innerRadius` per edge — for the Dashboard donut (side 150,
    /// innerRadius ratio 0.64 → 48pt) that is 2 × 1.5 / 48 = 0.0625 rad, about
    /// 1% of a full turn. Any slice holding less than that much of the total is
    /// asked to draw a sector whose width after insetting is NEGATIVE. A $3
    /// coffee in a $2500 month is 0.12%, so ordinary data reaches it.
    ///
    /// `renderableSlices` does not catch this: it only drops non-positive
    /// magnitudes and requires a positive total, both of which a sub-1% slice
    /// satisfies. Returns 0 — visually acceptable, and provably safe because a
    /// zero inset cannot consume any sector's width — whenever the default would
    /// not survive the smallest sector; otherwise the default.
    static func safeAngularInset(
        cents: [Int],
        defaultInset: CGFloat,
        innerRadiusRatio: CGFloat,
        frameSide: CGFloat
    ) -> CGFloat {
        let innerRadius = frameSide / 2 * innerRadiusRatio
        guard innerRadius.isFinite, innerRadius > 0,
              defaultInset.isFinite, defaultInset > 0 else { return 0 }

        let total = cents.reduce(0, +)
        guard total > 0, let smallest = cents.min(), smallest > 0 else { return 0 }

        // Angle consumed by the inset across both edges of a sector.
        let insetAngle = 2 * defaultInset / innerRadius
        let smallestSweep = 2 * CGFloat.pi * CGFloat(smallest) / CGFloat(total)
        return smallestSweep > insetAngle ? defaultInset : 0
    }

    /// A box Swift Charts can actually map a scale onto: both dimensions finite
    /// and strictly positive.
    ///
    /// The data guards above are not sufficient, because a chart's *geometry* is
    /// a second, independent input. Every chart in this app pins only its height
    /// and inherits its width from the parent, so a parent that transiently
    /// collapses (a keyboard/toolbar layout pass — device logs show a
    /// `_UIButtonBarButton` width == 0 constraint break alongside SwiftUI's
    /// "Invalid frame dimension (negative or non-finite)") proposes a degenerate
    /// box to a chart holding perfectly valid data. Charts then divides by a zero
    /// plot extent inside its own scale/layout math, which is why the resulting
    /// trap has no app frame on the stack and is not deterministic by row count.
    ///
    /// `.infinity` is excluded deliberately: an unbounded proposal is not a box a
    /// scale can be mapped onto either.
    static func canRenderInBox(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }
}

// MARK: - Frame guard

/// Renders a chart only when the box it is offered is finite and positive,
/// substituting a placeholder when it is not.
///
/// This is the geometry half of the choke-point. Charts must never be *asked* to
/// lay out in a degenerate box, so the check happens where the proposed size
/// arrives, not after the fact — by the time an invalid frame reaches Charts, the
/// trap is already inside a framework we cannot guard from the outside.
private struct ChartFrameGuard<Placeholder: View>: ViewModifier {
    let placeholder: Placeholder

    func body(content: Content) -> some View {
        GeometryReader { geo in
            if ChartGuards.canRenderInBox(geo.size) {
                content.frame(width: geo.size.width, height: geo.size.height)
            } else {
                placeholder.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

extension View {
    /// Gate this chart on a renderable box. Apply it directly around the `Chart`,
    /// *inside* whatever fixed height the view already pins:
    ///
    ///     Chart { … }
    ///         .guardedChartFrame()
    ///         .frame(height: 240)
    ///
    /// so the GeometryReader is handed a definite height and only the width — the
    /// dimension the parent can collapse — is actually in question.
    func guardedChartFrame<P: View>(
        @ViewBuilder placeholder: () -> P = { Color.clear }
    ) -> some View {
        modifier(ChartFrameGuard(placeholder: placeholder()))
    }
}
