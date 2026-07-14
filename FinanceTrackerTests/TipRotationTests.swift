//
//  TipRotationTests.swift
//  FinanceTrackerTests
//
//  The rotation is a contract with ContentStudio (it derives the social calendar
//  from the same index), so determinism is a correctness property, not a nicety.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipRotationTests {

    private func utc(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        ))!
    }

    private let utcZone = TimeZone(identifier: "UTC")!

    // MARK: - dayIndex

    @Test func epochIsDayZero() {
        #expect(TipRotation.dayIndex(for: utc(2026, 1, 1), in: utcZone) == 0)
    }

    @Test func dayIndexCountsWholeDaysFromEpoch() {
        #expect(TipRotation.dayIndex(for: utc(2026, 1, 2), in: utcZone) == 1)
        #expect(TipRotation.dayIndex(for: utc(2026, 2, 1), in: utcZone) == 31)
    }

    @Test func datesBeforeEpochAreNegative() {
        #expect(TipRotation.dayIndex(for: utc(2025, 12, 31), in: utcZone) == -1)
    }

    @Test func dayIndexIgnoresTimeOfDay() {
        // Any instant within the same local day maps to the same index — the tip
        // must not change at noon.
        let earlyDay = TipRotation.dayIndex(for: utc(2026, 3, 5, hour: 0), in: utcZone)
        let lateDay = TipRotation.dayIndex(for: utc(2026, 3, 5, hour: 23), in: utcZone)
        #expect(earlyDay == lateDay)
    }

    @Test func rollsOverAtLocalMidnightNotUTC() {
        // 2026-03-05 23:00 UTC is already 2026-03-06 in UTC+2, so a user there is
        // one day ahead. This is the deliberate local-midnight rollover.
        let instant = utc(2026, 3, 5, hour: 23)
        let inUTC = TipRotation.dayIndex(for: instant, in: utcZone)
        let inPlusTwo = TipRotation.dayIndex(for: instant, in: TimeZone(secondsFromGMT: 2 * 3600)!)
        #expect(inPlusTwo == inUTC + 1)
    }

    // MARK: - tipIndex

    @Test func tipIndexIsDeterministic() {
        // Same day + same count → same index, always.
        #expect(TipRotation.tipIndex(dayIndex: 42, canonicalCount: 5)
                == TipRotation.tipIndex(dayIndex: 42, canonicalCount: 5))
    }

    @Test func fullCycleVisitsEveryTipExactlyOnceBeforeRepeating() {
        let count = 7
        let cycle = (0..<count).compactMap {
            TipRotation.tipIndex(dayIndex: $0, canonicalCount: count)
        }
        #expect(Set(cycle).count == count)          // no repeats within a cycle
        #expect(Set(cycle) == Set(0..<count))       // every tip is used
        // The day after a full cycle wraps back to the start.
        #expect(TipRotation.tipIndex(dayIndex: count, canonicalCount: count) == 0)
    }

    @Test func negativeDayIndexStaysInRange() {
        // Swift's % yields negative results for negative operands; a raw modulo
        // would index out of bounds for a user whose clock predates the epoch.
        for day in -10 ... -1 {
            let index = TipRotation.tipIndex(dayIndex: day, canonicalCount: 5)
            #expect(index != nil)
            #expect((0..<5).contains(index!))
        }
        #expect(TipRotation.tipIndex(dayIndex: -1, canonicalCount: 5) == 4)
    }

    @Test func emptyLibraryYieldsNoIndex() {
        #expect(TipRotation.tipIndex(dayIndex: 0, canonicalCount: 0) == nil)
    }
}
