//
//  CategoryLimitPolicy.swift
//  FinanceTracker
//
//  Category limits (1.0.3 Item 3): warn BEFORE the limit — "X left in Dining"
//  — never after. An after-the-fact "you exceeded" is a guilt notification
//  that drives abandonment, so at/over the limit this policy says NOTHING
//  (the same silence rule as ProactiveAlertPolicy guard 4).
//
//  Pure — no UserDefaults, no clock, no SwiftData — so every rule is
//  unit-testable. The refresher owns the impure edges (latch storage, clock).
//

import Foundation

enum CategoryLimitPolicy {

    /// Warn when spend crosses this fraction of the limit, from below.
    /// ~70% is a TUNABLE STARTING GUESS, not a research finding (feature-pack
    /// Item 3) — which is exactly why it lives here and ONLY here. Every
    /// consumer (selection, tests, any future UI hint) reads this symbol;
    /// changing the guess is a one-line diff.
    static let warnThresholdFraction: Double = 0.70

    /// The one comparison, in one place (same discipline as
    /// SafeToSpend.remainingCents). Warn iff
    ///   spent ≥ ceil(threshold × limit)  AND  spent < limit.
    /// The second clause is the gain-framing guard: at/over the limit there is
    /// no honest gain-framed sentence, so we say nothing.
    static func shouldWarn(spentCents: Int, limitCents: Int) -> Bool {
        guard limitCents > 0 else { return false }
        let threshold = Int((Double(limitCents) * warnThresholdFraction).rounded(.up))
        return spentCents >= threshold && spentCents < limitCents
    }

    /// One limited category's month-to-date position — Sendable, so it can
    /// cross the LedgerAggregator actor boundary as plain data.
    struct Status: Equatable, Sendable {
        let categoryUUID: UUID
        let displayName: String
        let limitCents: Int
        let spentCents: Int

        var remainingCents: Int { limitCents - spentCents }
        var usedFraction: Double {
            guard limitCents > 0 else { return 0 }
            return Double(spentCents) / Double(limitCents)
        }
        var shouldWarn: Bool {
            CategoryLimitPolicy.shouldWarn(spentCents: spentCents, limitCents: limitCents)
        }
    }

    /// The single most urgent warnable, unlatched category — closest to its
    /// limit wins, because one notification carries one number (the existing
    /// copy discipline). nil = nothing to say.
    static func pickWarnable(
        statuses: [Status],
        isLatched: (UUID) -> Bool
    ) -> Status? {
        statuses
            .filter { $0.shouldWarn && !isLatched($0.categoryUUID) }
            .max { $0.usedFraction < $1.usedFraction }
    }

    /// Month-to-date spend per category over ATTRIBUTION rows (design §6.3) —
    /// a split purchase's money counts toward the SPLITS' categories. Uses the
    /// identical month window as SafeToSpend.aggregate (day ≤ today,
    /// future-dated excluded) so the limit alert can never disagree with the
    /// dashboard about what "this month" means. The nil-category bucket can
    /// hold no limit, so it is skipped.
    static func spentByCategory(
        rows: [CategoryAttribution.Row],
        monthStart: Date,
        today: Date,
        calendar: Calendar = .current
    ///
    /// Returns nil when a category's spend cannot be summed in `Int`. Like
    /// `SafeToSpend.aggregate`, the caller's correct response is to schedule no
    /// limit warning at all — a warning computed from a number we could not
    /// compute would be worse than silence.
    ) -> [UUID: Int]? {
        var spent: [UUID: Int] = [:]
        for row in rows where !row.isIncome {
            let day = calendar.startOfDay(for: row.date)
            guard day >= monthStart, day <= today else { continue }
            guard let categoryUUID = row.categoryUUID else { continue }
            let (sum, overflow) = (spent[categoryUUID] ?? 0).addingReportingOverflow(row.amountCents)
            guard !overflow else { return nil }
            spent[categoryUUID] = sum
        }
        return spent
    }

    /// Per-category-per-month latch key ("fires once, crossing from below").
    /// The month component auto-expires the latch on rollover.
    static func latchKey(categoryUUID: UUID, month: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: month)
        return "limitWarned.\(categoryUUID.uuidString).\(comps.year ?? 0)-\(comps.month ?? 0)"
    }
}
