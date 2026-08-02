//
//  RecurrencePeriodLabelTests.swift
//  FinanceTrackerTests
//
//  GOLDEN VECTORS. The period label is a segment of `occurrenceKey` (step 3), so
//  it is frozen the moment sync ships: changing it silently re-keys every
//  occurrence and un-collapses everything already posted. These literals exist
//  so that a change is a failing test rather than a silent re-key.
//
//  These are now the ONLY golden vectors the identity needs. The key is the
//  literal string "<template uuid lowercased>|<cadence>|<label>" rather than a
//  UUIDv5 hash of it (PLAN_RECURRENCE_SYNC_IDENTITY Q1, amendment 2026-08-02),
//  so there is no second frozen artifact requiring a vector computed outside
//  this codebase. The vectors below are independent of it: they come from the
//  ISO-8601 week rules, not from what this implementation happens to return.
//
//  The bug they were written against — the reason `DateFormatter` is banned from
//  this path — is that `"yyyy-'W'ww"` on a Gregorian / en_US_POSIX calendar
//  produces neither ISO week-years nor ISO weeks:
//
//    * `y` is the CALENDAR year; the week-numbering year is `Y`
//      (`yearForWeekOfYear`). 2024-12-30 is a Monday in ISO week 2025-W01 but
//      formats as "2024-W01".
//    * Gregorian + en_US_POSIX is firstWeekday = 1, minimumDaysInFirstWeek = 1 —
//      US weeks. ISO needs 2 and 4.
//
//  Which makes 2024-01-01 and 2024-12-30 — two different weeks, eleven months
//  apart — both label "2024-W01". Under find-or-create that collapses two real
//  charges into one row and one of them silently disappears from the ledger. A
//  missing charge is the failure a user notices last, so it gets a named test:
//  `collisionWitness_theTwoWeeksThatUsedToCollide`.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("Recurrence period labels are frozen and calendar-exact")
struct RecurrencePeriodLabelTests {

    /// Builds an instant from a civil UTC date. Midday, so that a naive
    /// implementation drifting by a few hours still lands on the same day and
    /// cannot pass these tests by accident.
    private func utc(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }

    // MARK: - Weekly: the dates where week-year and calendar year disagree

    @Test(
        "weekly golden vectors",
        arguments: [
            // (y, m, d, expected)  — verified against ISO-8601 week numbering
            (2024, 12, 30, "2025-W01"),   // Monday of ISO week 1 of the NEXT year
            (2025, 12, 29, "2026-W01"),   // same shape, one year on
            (2027,  1,  1, "2026-W53"),   // Friday belonging to the PREVIOUS week-year
            (2026,  1,  1, "2026-W01"),   // Thursday — week 1 by the ISO rule
            (2028,  2, 29, "2028-W09"),   // leap day
            (2024,  1,  1, "2024-W01"),   // the collision partner, see below
        ]
    )
    func weeklyGoldenVectors(year: Int, month: Int, day: Int, expected: String) {
        #expect(RecurrencePeriod.label(for: utc(year, month, day), cadence: .weekly) == expected)
    }

    /// The specific pair the broken format string mapped onto one label.
    @Test("collision witness: the two weeks that used to collide")
    func collisionWitness_theTwoWeeksThatUsedToCollide() {
        let januaryWeek = RecurrencePeriod.label(for: utc(2024, 1, 1), cadence: .weekly)
        let decemberWeek = RecurrencePeriod.label(for: utc(2024, 12, 30), cadence: .weekly)

        #expect(januaryWeek == "2024-W01")
        #expect(decemberWeek == "2025-W01")
        #expect(januaryWeek != decemberWeek, "two different weeks must never share an occurrence key")
    }

    // MARK: - Monthly / yearly

    @Test(
        "monthly golden vectors",
        arguments: [
            (2028, 2, 29, "2028-02"),
            (2026, 1,  1, "2026-01"),
            (2024, 12, 30, "2024-12"),
            (2026, 9,  5, "2026-09"),
        ]
    )
    func monthlyGoldenVectors(year: Int, month: Int, day: Int, expected: String) {
        #expect(RecurrencePeriod.label(for: utc(year, month, day), cadence: .monthly) == expected)
    }

    @Test(
        "yearly golden vectors",
        arguments: [
            (2028, 2, 29, "2028"),
            (2027, 1, 1, "2027"),
            (2024, 12, 30, "2024"),
        ]
    )
    func yearlyGoldenVectors(year: Int, month: Int, day: Int, expected: String) {
        #expect(RecurrencePeriod.label(for: utc(year, month, day), cadence: .yearly) == expected)
    }

    /// A yearly series anchored on a leap day keeps one label per year — the
    /// identity never touches the day, so Feb 29 needs no special case here.
    /// (Clamping Feb 29 -> Feb 28 is a POSTING-DATE concern, not an identity one.)
    @Test("a leap-day anchor produces one label per year, not a gap")
    func leapDayAnchorLabelsEveryYear() {
        let labels = [2024, 2025, 2026, 2027, 2028].map { year -> String in
            let day = (year == 2024 || year == 2028) ? 29 : 28
            return RecurrencePeriod.label(for: utc(year, 2, day), cadence: .yearly)
        }
        #expect(labels == ["2024", "2025", "2026", "2027", "2028"])
        #expect(Set(labels).count == 5, "no two years may share a label")
    }

    // MARK: - The things that must not be able to influence a label

    /// Timezone. The label is computed in UTC, never in `Calendar.current`, so a
    /// user who travels cannot disagree with themselves. This instant is
    /// 2026-01-01 in UTC and still 2025-12-31 in every American zone: the label
    /// must be the UTC one.
    @Test("an instant that straddles the year boundary labels by UTC, not by locale")
    func labelIsComputedInUTC() {
        let justAfterMidnightUTC = utc(2026, 1, 1, hour: 0)

        #expect(RecurrencePeriod.label(for: justAfterMidnightUTC, cadence: .yearly) == "2026")
        #expect(RecurrencePeriod.label(for: justAfterMidnightUTC, cadence: .monthly) == "2026-01")
    }

    /// DST. Structurally impossible to affect the label — UTC has no DST, and a
    /// civil period label is not an instant, so there is no hour to gain or
    /// lose. Pinned across both US transitions of 2026 anyway, because "it
    /// cannot happen" is exactly the claim that stops being true after a
    /// refactor.
    @Test("DST transitions in both directions do not move a label")
    func dstTransitionsDoNotMoveLabels() {
        // Spring forward: 2026-03-08, 02:00 local (America/New_York).
        let beforeSpring = utc(2026, 3, 8, hour: 6)
        let afterSpring = utc(2026, 3, 8, hour: 7)
        #expect(RecurrencePeriod.label(for: beforeSpring, cadence: .monthly) == "2026-03")
        #expect(RecurrencePeriod.label(for: afterSpring, cadence: .monthly) == "2026-03")
        #expect(
            RecurrencePeriod.label(for: beforeSpring, cadence: .weekly)
                == RecurrencePeriod.label(for: afterSpring, cadence: .weekly)
        )

        // Fall back: 2026-11-01, 02:00 local.
        let beforeFall = utc(2026, 11, 1, hour: 5)
        let afterFall = utc(2026, 11, 1, hour: 6)
        #expect(RecurrencePeriod.label(for: beforeFall, cadence: .monthly) == "2026-11")
        #expect(RecurrencePeriod.label(for: afterFall, cadence: .monthly) == "2026-11")
        #expect(
            RecurrencePeriod.label(for: beforeFall, cadence: .weekly)
                == RecurrencePeriod.label(for: afterFall, cadence: .weekly)
        )
    }

    // MARK: - The label set is closed

    /// `RecurrenceType` has exactly three cases and no `daily`. The label switch
    /// is exhaustive with no `default:`, so a fourth cadence is a compile error
    /// rather than a silent fallback into a wrong label — but a compile error
    /// cannot be asserted, so this stands in for it: adding a case fails here
    /// and points at the thing that needs a label.
    @Test("the cadence set is closed at three")
    func cadenceSetIsClosed() {
        #expect(RecurrenceType.allCases.count == 3)
        #expect(Set(RecurrenceType.allCases.map(\.rawValue)) == ["weekly", "monthly", "yearly"])
    }

    @Test("every cadence yields a distinct label shape for one instant")
    func cadencesDoNotAlias() {
        let date = utc(2026, 9, 5)
        let labels = RecurrenceType.allCases.map { RecurrencePeriod.label(for: date, cadence: $0) }
        #expect(Set(labels).count == RecurrenceType.allCases.count)
    }

    @Test("labels are stable across repeated calls")
    func labelsAreStable() {
        let date = utc(2026, 9, 5)
        for cadence in RecurrenceType.allCases {
            let first = RecurrencePeriod.label(for: date, cadence: cadence)
            let second = RecurrencePeriod.label(for: date, cadence: cadence)
            #expect(first == second)
        }
    }
}
