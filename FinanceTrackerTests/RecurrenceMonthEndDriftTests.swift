//
//  RecurrenceMonthEndDriftTests.swift
//  FinanceTrackerTests
//
//  A month-end series must not drift off month-end permanently.
//
//  The bug: `RecurrenceType.nextDate(after:)` is `calendar.date(byAdding: .month,
//  value: 1)`, which CLAMPS into short months — and the old `nextDueDate` fed it the
//  previous RESULT, so the clamp compounded. Jan 31 → Feb 28 → Mar 28 → Apr 28,
//  forever. One February moved a month-end subscription to the 28th for the rest of
//  its life. Same shape for a yearly series anchored Feb 29: it clamped to Feb 28 in
//  2025 and never came back in 2028.
//
//  These tests also pin the FORWARD-ONLY decision (2026-08-12), which is a product
//  choice and not an implementation detail: a series that has ALREADY drifted keeps
//  the day it drifted to. `alreadyDriftedSeries_isNotReAnchored` is the test that
//  fails if someone "improves" this by back-filling — which is the change the
//  decision exists to prevent. Re-anchoring would move posting dates on live series
//  users may have reconciled against a bank statement, and we cannot know which
//  dates were already acted on.
//
//  Fixed dates only, and a fixed Gregorian calendar in UTC — a test that reads the
//  process calendar or locale would pass or fail on the machine, not the code.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("Month-end recurrence drift")
struct RecurrenceMonthEndDriftTests {

    /// Fixed so the assertions describe the code, never the runner's region.
    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private static func parts(_ date: Date) -> (y: Int, m: Int, d: Int) {
        let c = utc.dateComponents([.year, .month, .day], from: date)
        return (c.year!, c.month!, c.day!)
    }

    private static func next(
        _ type: RecurrenceType, after last: Date, anchor: Date
    ) -> (y: Int, m: Int, d: Int) {
        parts(type.nextDate(after: last, anchor: anchor, calendar: utc))
    }

    // MARK: - The regression itself

    /// THE bug, in one assertion: the step AFTER the legitimate February clamp must
    /// return to month-end. This is what the old code got wrong.
    @Test func januaryThirtyFirst_returnsToMonthEndAfterFebruary() {
        let anchor = Self.date(2026, 1, 31)

        let feb = Self.next(.monthly, after: anchor, anchor: anchor)
        #expect(feb == (2026, 2, 28), "February must clamp — 2026 is not a leap year")

        let mar = Self.next(.monthly, after: Self.date(2026, 2, 28), anchor: anchor)
        #expect(mar == (2026, 3, 31), "March has 31 days; the clamp must not persist")
    }

    /// The old math produced 28 here. Pinned explicitly so the two are never confused.
    @Test func theOldAnchorBlindMathStillDrifts_documentingWhyTheAnchorIsNeeded() {
        let drifted = RecurrenceType.monthly.nextDate(
            after: Self.date(2026, 2, 28), calendar: Self.utc
        )
        #expect(Self.parts(drifted) == (2026, 3, 28),
                "anchor-blind overload is expected to drift — that is why it is deprecated")
    }

    /// A full 14-month walk. A single step can look right while the series still
    /// creeps, so this asserts every month lands on the last day.
    @Test func monthEndSeries_doesNotAccumulateDriftOverFourteenMonths() {
        let anchor = Self.date(2026, 1, 31)
        let expectedLastDay = [
            (2026, 2, 28), (2026, 3, 31), (2026, 4, 30), (2026, 5, 31), (2026, 6, 30),
            (2026, 7, 31), (2026, 8, 31), (2026, 9, 30), (2026, 10, 31), (2026, 11, 30),
            (2026, 12, 31), (2027, 1, 31), (2027, 2, 28), (2027, 3, 31),
        ]

        var cursor = anchor
        for expected in expectedLastDay {
            let step = RecurrenceType.monthly.nextDate(
                after: cursor, anchor: anchor, calendar: Self.utc
            )
            #expect(Self.parts(step) == expected)
            cursor = step
        }
    }

    // MARK: - Per cadence

    @Test func weekly_isExactAndUnaffectedByMonthLength() {
        let anchor = Self.date(2026, 1, 29)
        #expect(Self.next(.weekly, after: anchor, anchor: anchor) == (2026, 2, 5))
        // Straddling a short month must still be exactly 7 days.
        #expect(Self.next(.weekly, after: Self.date(2026, 2, 26), anchor: anchor) == (2026, 3, 5))
    }

    @Test func monthly_ordinaryDayIsUnchanged() {
        let anchor = Self.date(2026, 3, 15)
        #expect(Self.next(.monthly, after: anchor, anchor: anchor) == (2026, 4, 15))
    }

    @Test func yearly_ordinaryDayIsUnchanged() {
        let anchor = Self.date(2026, 6, 10)
        #expect(Self.next(.yearly, after: anchor, anchor: anchor) == (2027, 6, 10))
    }

    /// The leap-year case named in the brief: Feb 29 must come back in 2028.
    @Test func yearlyFebruaryTwentyNinth_returnsIn2028() {
        let anchor = Self.date(2024, 2, 29)

        var cursor = anchor
        for expected in [(2025, 2, 28), (2026, 2, 28), (2027, 2, 28), (2028, 2, 29)] {
            let step = RecurrenceType.yearly.nextDate(
                after: cursor, anchor: anchor, calendar: Self.utc
            )
            #expect(Self.parts(step) == expected)
            cursor = step
        }
    }

    /// A 30th-of-the-month series: clamps to 28 in February, back to 30 in March.
    @Test func thirtiethOfMonth_clampsOnlyInFebruary() {
        let anchor = Self.date(2026, 1, 30)
        #expect(Self.next(.monthly, after: anchor, anchor: anchor) == (2026, 2, 28))
        #expect(Self.next(.monthly, after: Self.date(2026, 2, 28), anchor: anchor) == (2026, 3, 30))
    }

    // MARK: - Forward-only (the product decision)

    /// THE pin on the decision. A series already sitting on Mar 28 with a day-31
    /// anchor was moved there by the OLD code — 28 is not the clamp of 31 into a
    /// 31-day March — so it must stay on the 28th rather than snap back.
    ///
    /// If this test fails, someone has back-filled drifted series. That is the change
    /// the forward-only decision exists to prevent; do not "fix" this test.
    @Test func alreadyDriftedSeries_isNotReAnchored() {
        let anchor = Self.date(2026, 1, 31)
        let drifted = Self.date(2026, 3, 28)   // only reachable via the old math

        #expect(Self.next(.monthly, after: drifted, anchor: anchor) == (2026, 4, 28),
                "a drifted series keeps its day; a stable wrong date beats a moving one")
    }

    /// And it must stay put, not creep further, once preserved.
    @Test func alreadyDriftedSeries_staysStableAndDoesNotDriftAgain() {
        let anchor = Self.date(2026, 1, 31)
        var cursor = Self.date(2026, 3, 28)

        for expected in [(2026, 4, 28), (2026, 5, 28), (2026, 6, 28)] {
            cursor = RecurrenceType.monthly.nextDate(
                after: cursor, anchor: anchor, calendar: Self.utc
            )
            #expect(Self.parts(cursor) == expected)
        }
    }

    /// The boundary that makes the fix reachable at all: Feb 28 IS the correct clamp
    /// of a day-31 anchor, so a series there is still ON-anchor and gets the fixed
    /// math — it is not mistaken for drift.
    @Test func legitimateFebruaryClamp_isNotMistakenForDrift() {
        let anchor = Self.date(2026, 1, 31)
        #expect(Self.next(.monthly, after: Self.date(2026, 2, 28), anchor: anchor) == (2026, 3, 31))
    }

    /// Time of day rides along, so a prompt does not wander across the day.
    @Test func timeOfDayIsPreserved() {
        let anchor = Self.utc.date(from: DateComponents(
            year: 2026, month: 1, day: 31, hour: 9, minute: 30
        ))!
        let step = RecurrenceType.monthly.nextDate(after: anchor, anchor: anchor, calendar: Self.utc)
        let c = Self.utc.dateComponents([.hour, .minute], from: step)
        #expect(c.hour == 9 && c.minute == 30)
    }
}
