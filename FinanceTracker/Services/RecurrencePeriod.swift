//
//  RecurrencePeriod.swift
//  FinanceTracker
//
//  The calendar period a recurring charge belongs to, as a string label.
//
//  This is the input to `Transaction.occurrenceID` (1.0.4 auto-post / sync,
//  PLAN_RECURRENCE_SYNC_IDENTITY step 3): two devices independently derive the
//  same occurrence id for the same charge by deriving it from the same label.
//  That makes a concurrent double-post *detectable* — two rows sharing an
//  occurrence id are provably one posting rather than a content coincidence.
//
//  ┌─────────────────────────────────────────────────────────────────────────┐
//  │ FROZEN. Once sync ships, changing anything about how these strings are  │
//  │ built silently re-keys every occurrence and un-collapses everything     │
//  │ already posted. `RecurrencePeriodLabelTests` pins literal expected      │
//  │ values so that a change fails a test instead.                           │
//  └─────────────────────────────────────────────────────────────────────────┘
//
//  Three rules make it deterministic across devices:
//
//  1. **A period LABEL, never an instant.** `Date` is an absolute time; the
//     moment it is rendered through `Calendar.current` the answer depends on the
//     device's time zone, and a user who travels disagrees with themselves. It
//     is also not an index counted from the series anchor — an index puts the
//     template's own `date` into the identity, and during the replication lag
//     this exists to survive, two devices can disagree about which twin is
//     canonical and therefore about the anchor.
//
//  2. **No silent fallback.** Every derivation below traps rather than
//     substituting a placeholder. `dateComponents(_:from:)` always populates the
//     components it was asked for, so these branches are unreachable — but the
//     reachable-looking alternative, `?? 0`, is the worst value in the space: it
//     maps *every* failed derivation onto the same label ("0000-W00"), so under
//     find-or-create all of them collapse into one row and every charge after
//     the first silently disappears. That is precisely the failure rule 3 exists
//     to prevent, arriving through the back door. A crash with the offending
//     instant in the message is diagnosable; a lost charge is not.
//
//  3. **No `DateFormatter` anywhere on this path.** Components are read and the
//     string is built numerically, so no locale-sensitive formatting can reach
//     an identity key. This is not hypothetical caution: the format string this
//     file replaced, `"yyyy-'W'ww"`, was wrong twice over — `y` is the calendar
//     year where ISO needs the week-numbering year `Y`, and a Gregorian
//     calendar under `en_US_POSIX` is firstWeekday = 1 / minimumDaysInFirstWeek
//     = 1, i.e. US weeks, not ISO's 2 and 4. Together those made 2024-01-01 and
//     2024-12-30 — two different weeks — both label "2024-W01", which under
//     find-or-create would collapse two real charges into one row and make one
//     of them silently vanish from the ledger.
//

import Foundation

enum RecurrencePeriod {

    /// Gregorian, UTC, POSIX. Frozen: never `Calendar.current`, never the
    /// user's locale. UTC is chosen for two reasons — it is the same everywhere
    /// a device might be, and it has no daylight-saving transitions, so there is
    /// no hour for a period boundary to gain or lose.
    private static let civil: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// ISO-8601 week rules, stated explicitly rather than inherited.
    /// `Calendar(identifier: .iso8601)` is the right base, but `firstWeekday`
    /// and `minimumDaysInFirstWeek` are settable and locale-influenced, and this
    /// is a frozen identity key — so both are pinned here where a reader can see
    /// them, and cannot be changed by a locale arriving from anywhere else.
    private static let isoWeek: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2              // Monday
        calendar.minimumDaysInFirstWeek = 4    // week 1 contains the first Thursday
        return calendar
    }()

    /// The label for the period `date` falls in, under `cadence`.
    ///
    /// The switch is exhaustive with **no `default:` clause**, deliberately:
    /// `RecurrenceType` has exactly three cases and no `daily`, so the label set
    /// is closed. Adding a fourth cadence must be a compile error here, not a
    /// silent fallback into a wrong label — a wrong label is a lost charge.
    static func label(for date: Date, cadence: RecurrenceType) -> String {
        switch cadence {
        case .weekly:
            let parts = isoWeek.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let weekYear = parts.yearForWeekOfYear, let week = parts.weekOfYear else {
                preconditionFailure(underivable("yearForWeekOfYear/weekOfYear", date))
            }
            return String(format: "%04d-W%02d", weekYear, week)

        case .monthly:
            let parts = civil.dateComponents([.year, .month], from: date)
            guard let year = parts.year, let month = parts.month else {
                preconditionFailure(underivable("year/month", date))
            }
            return String(format: "%04d-%02d", year, month)

        case .yearly:
            let parts = civil.dateComponents([.year], from: date)
            guard let year = parts.year else {
                preconditionFailure(underivable("year", date))
            }
            return String(format: "%04d", year)
        }
    }

    /// Message for the unreachable branches above.
    ///
    /// The instant is reported as a raw `timeIntervalSinceReferenceDate` on
    /// purpose: it is locale-free, it is exactly what a reproduction needs, and
    /// no date *formatter* may run on this path even in a crash message —
    /// the failure being reported is one where the calendar is already suspect.
    private static func underivable(_ components: String, _ date: Date) -> String {
        """
        RecurrencePeriod: calendar returned no \(components) for instant \
        \(date.timeIntervalSinceReferenceDate). Trapping rather than labelling: a \
        placeholder label is an occurrence key collision, and a collision is a \
        charge that silently vanishes from the ledger.
        """
    }
}
