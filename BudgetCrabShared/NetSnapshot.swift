//
//  NetSnapshot.swift
//  Budget Crab — shared by the app target and the BudgetCrabWidget extension.
//
//  A tiny, display-ready, Codable snapshot of the current period that the app
//  writes to the shared App Group on data changes and the widget reads. The
//  widget never opens SwiftData — it only renders these pre-computed strings and
//  guarded fractions, so no model code, store access, or String(localized:)
//  lookup lives in the extension (its bundle has no .strings table — the app
//  bakes every localized string in here). Fully on-device: the App Group
//  container never leaves the phone.
//
//  v1.0.1 redesign: the widget leads with **Safe to spend** (gain-framed
//  remaining budget) + a progress ring, not a raw net dump. All the display
//  logic — hero copy, ring fraction, compact amounts, per-category fractions —
//  is decided in NetSnapshotBuilder (app target) and frozen into these fields.
//

import Foundation

/// Constants shared between the app and the widget extension.
enum WidgetSharing {
    /// App Group identifier — must match the entitlement on both targets.
    static let appGroupID = "group.com.dmitrylogachev.budgetcrab"
    /// Bumped v1→v2 with the redesigned contract so a stale v1 blob is ignored.
    static let snapshotKey = "net_snapshot_v2"
    /// Deep-link opened when the widget is tapped.
    static let widgetURL = URL(string: "budgetcrab://dashboard")!
}

struct NetSnapshot: Codable {
    var monthLabel: String          // localized, e.g. "June 2026"
    var currencyCode: String        // defaultCurrencyCode at build time

    // MARK: Hero — safe-to-spend, gain-framed
    /// Localized label: "Safe to spend" / "Over budget" / "Spent" (no-budget).
    var heroLabel: String
    /// Compact, localized magnitude, e.g. "$1,240" or "$12.3K".
    var heroAmount: String
    /// Localized subline, e.g. "of $2,000" — empty when there's nothing to add.
    var heroSubtitle: String
    /// True only when actually over budget → the widget tints the hero in danger.
    var heroIsAlert: Bool

    // MARK: Ring — spent vs budget (or vs income when budget-less)
    /// Progress 0…1. Already guarded at build time; re-guarded on read.
    var ringFraction: Double
    /// True → render the track only (no meaningful denominator to fill against).
    var ringIsNeutral: Bool

    // MARK: Period totals (localized, compact)
    var spentText: String           // e.g. "Spent $567"
    var earnedText: String          // e.g. "Earned $801"

    // MARK: Top categories by spend (≤3, sorted desc)
    var topCategories: [Item]

    // MARK: Ambient spend curve (Direction B)
    /// Cumulative daily spend for the current month, normalized 0…1 by the period's
    /// total spend — one value per elapsed day. Drives the ambient area+line
    /// sparkline. Its *shape* conveys spend pace; the spent-vs-budget magnitude is
    /// the ring/hero's job, so the scale is intentionally self-relative.
    ///
    /// **Additive & optional**: absent (`nil`) on an old v2 blob or when the period
    /// can't form an honest continuous curve (no spend, or <2 elapsed days). The
    /// widget then draws NO chart — never a fabricated or degenerate one.
    var spendSeries: [Double]? = nil

    /// False on a fresh install / empty period with no budget — the widget then
    /// shows a calm seeded state instead of a broken zero.
    var hasData: Bool
    var generatedAt: Date

    struct Item: Codable, Identifiable {
        var id: String { name }
        var name: String            // localized category name
        var symbol: String          // SF Symbol
        var amount: String          // compact, localized
        var fraction: Double        // share of this period's spend, 0…1
    }

    /// Ring value the widget can trust no matter what was encoded (guards a
    /// corrupt/NaN blob the same way ChartGuards does — never a negative or
    /// oversized ring).
    var safeRingFraction: Double {
        guard ringFraction.isFinite else { return 0 }
        return min(max(ringFraction, 0), 1)
    }

    /// Ambient-curve points the widget can trust no matter what was encoded: every
    /// value coerced finite and clamped 0…1 (a corrupt/NaN blob can never feed a
    /// non-finite mark into Charts). Empty when there's no series.
    var safeSpendSeries: [Double] {
        guard let s = spendSeries else { return [] }
        return s.map { $0.isFinite ? min(max($0, 0), 1) : 0 }
    }

    /// Whether the ambient spend chart is renderable. A continuous line/area needs
    /// ≥2 points; one point is a zero-width domain that traps Charts (same rule as
    /// ChartGuards.canRenderContinuous, restated here since the app-target guard
    /// isn't visible to the extension). The widget MUST draw no chart when false.
    var canRenderSpendChart: Bool { safeSpendSeries.count >= 2 }
}

extension NetSnapshot.Item {
    /// Guarded bar width for the mini category bars.
    var safeFraction: Double {
        guard fraction.isFinite else { return 0 }
        return min(max(fraction, 0), 1)
    }
}

// MARK: - Shared App Group persistence

extension NetSnapshot {
    static func load() -> NetSnapshot? {
        guard let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
              let data = defaults.data(forKey: WidgetSharing.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(NetSnapshot.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: WidgetSharing.snapshotKey)
    }

    /// Neutral placeholder for the widget gallery / before the first write.
    /// Uses no `String(localized:)` — the widget bundle has no strings table, so
    /// a placeholder must stay glyph/neutral, never a half-localized string.
    static func placeholder() -> NetSnapshot {
        NetSnapshot(
            monthLabel: "—",
            currencyCode: "USD",
            heroLabel: "—",
            heroAmount: "—",
            heroSubtitle: "",
            heroIsAlert: false,
            ringFraction: 0,
            ringIsNeutral: true,
            spentText: "",
            earnedText: "",
            topCategories: [],
            hasData: false,
            generatedAt: Date()
        )
    }
}
