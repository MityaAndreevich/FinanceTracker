//
//  RecurrenceType.swift
//  FinanceTracker
//
//  Strongly-typed wrapper around Transaction.recurrenceRaw.
//  nil recurrenceRaw == one-time transaction; a non-nil raw maps to a case here.
//
//  ┌─────────────────────────────────────────────────────────────────────────┐
//  │ THE RAW VALUES ARE FROZEN — for TWO reasons, and the second one is       │
//  │ invisible from this file.                                               │
//  │                                                                         │
//  │ 1. `recurrenceRaw` storage. Renaming a case's raw value orphans every    │
//  │    stored row: `from(_:)` returns nil and a recurring series silently    │
//  │    becomes one-time. This one is at least guessable from the file.       │
//  │                                                                         │
//  │ 2. `cadence.rawValue` is the MIDDLE SEGMENT of                           │
//  │    `Transaction.occurrenceKey` — see `RecurrencePeriod.swift`, whose     │
//  │    header carries the full key format and the freeze rationale. Renaming │
//  │    a raw value re-keys every occurrence of that cadence, so rows already │
//  │    posted stop matching rows posted after the rename, and the           │
//  │    duplicate-collapse that key exists for stops collapsing them.         │
//  │                                                                         │
//  │ Neither failure is caught by the compiler and neither is visible at the  │
//  │ rename site. `rawValue` here is persisted data and a wire format, not a  │
//  │ name.                                                                   │
//  └─────────────────────────────────────────────────────────────────────────┘
//
//  ADDING a fourth cadence (e.g. `daily`) is safe — the freeze is on renaming,
//  not on growth:
//
//  - A new raw value is a new key namespace. `occurrenceKey` segments on the
//    cadence, so a `daily` key can never alias a weekly/monthly/yearly one no
//    matter what its period label looks like.
//  - Nothing is re-keyed. Existing rows keep their cadence and therefore their
//    keys; only new series use the new namespace.
//  - The decision that would otherwise be silent is forced at compile time:
//    `RecurrencePeriod.label(for:cadence:)` switches exhaustively with no
//    `default:`, on purpose, so a new case cannot fall through to a wrong label.
//    (`labelKey` and `dateComponent` below are exhaustive for the same reason.)
//
//  So: add cases freely, and answer the compiler where it stops you. Never
//  rename one.
//

import Foundation

enum RecurrenceType: String, CaseIterable, Identifiable, Sendable {
    // Raw values are frozen — see the header. Add, never rename.
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// The raw storage value used in SwiftData (`recurrenceRaw`).
    var raw: String { rawValue }

    /// Best-effort parse; returns nil for unknown / empty values so callers can
    /// treat them as one-time transactions.
    static func from(_ raw: String?) -> RecurrenceType? {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return nil }
        return RecurrenceType(rawValue: raw)
    }

    /// Localization key for the picker / labels.
    var labelKey: String {
        switch self {
        case .weekly:  return "addtx.recurring.weekly"
        case .monthly: return "addtx.recurring.monthly"
        case .yearly:  return "addtx.recurring.yearly"
        }
    }

    /// The `Calendar` component step used to advance one period.
    var dateComponent: Calendar.Component {
        switch self {
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }

    /// Advance a date by exactly one period of this recurrence.
    ///
    /// ⚠️ **Anchor-blind, and that is a month-end bug** — prefer
    /// `nextDate(after:anchor:)`. `Calendar.date(byAdding: .month, value: 1)` CLAMPS
    /// into short months, and because this function's only input is the previous
    /// result, the clamp compounds: Jan 31 → Feb 28 → **Mar 28** → Apr 28, forever.
    /// One February permanently moves a month-end subscription to the 28th.
    ///
    /// Kept for `.weekly`, where there is nothing to clamp, and for callers that
    /// genuinely have no anchor.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: dateComponent, value: 1, to: date) ?? date
    }

    /// Advance one period, clamping the **series anchor's** day-of-month into the
    /// target month instead of the previous result's. Jan 31 → Feb 28 → **Mar 31**.
    /// A yearly series anchored Feb 29 2024 clamps to Feb 28 in 2025/26/27 and
    /// returns to **Feb 29 in 2028**.
    ///
    /// ## Forward-only, deliberately (founder decision, 2026-08-12)
    ///
    /// A series that has ALREADY drifted under the old math keeps the day it drifted
    /// to. It is not re-anchored. Re-anchoring would move posting dates on live
    /// series that users may already have reconciled against a bank statement, and
    /// **we cannot know which dates were already acted on** — so a stable wrong date
    /// beats a date that changes underneath someone.
    ///
    /// **Do not "improve" this later by back-filling drifted series.** That is the
    /// change this rule exists to prevent, not an oversight.
    ///
    /// The drift test is the `expected != lastDay` branch below: if `last` is exactly
    /// what clamping the anchor into `last`'s own month produces, the series is still
    /// on-anchor and gets the corrected math; if it is not, the old code already
    /// moved it and we preserve where it landed. This is what makes Jan 31 → Feb 28
    /// recoverable — Feb 28 IS the correct clamp for February, so the series is still
    /// on-anchor there and the very next step is the fixed Mar 31.
    func nextDate(after last: Date, anchor: Date, calendar: Calendar = .current) -> Date {
        // Weeks have no short-month problem: every step is exactly 7 days.
        guard self != .weekly else { return nextDate(after: last, calendar: calendar) }

        let anchorDay = calendar.component(.day, from: anchor)
        let lastDay = calendar.component(.day, from: last)

        // Was `last` produced by clamping the anchor into its own month?
        let expected = min(anchorDay, Self.daysInMonth(of: last, calendar: calendar))
        let effectiveDay = (lastDay == expected) ? anchorDay : lastDay

        guard let target = calendar.date(byAdding: dateComponent, value: 1, to: last) else {
            return last
        }
        let day = min(effectiveDay, Self.daysInMonth(of: target, calendar: calendar))

        // Rebuild from the target's month, preserving `last`'s time of day so a
        // prompt does not wander across the day as the series advances.
        var comps = calendar.dateComponents([.year, .month], from: target)
        comps.day = day
        let time = calendar.dateComponents([.hour, .minute, .second], from: last)
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = time.second
        return calendar.date(from: comps) ?? target
    }

    private static func daysInMonth(of date: Date, calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 28
    }
}
