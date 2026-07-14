//
//  TipDismissalTests.swift
//  FinanceTrackerTests
//
//  Dismissal rides the day index rather than a timestamp + cleanup job: "dismissed
//  for today" is just `dismissedDayIndex == todayIndex`, so tomorrow resets itself.
//

import Testing
@testable import FinanceTracker

struct TipDismissalTests {

    @Test func aFreshInstallHasNothingDismissed() {
        // -1 is the sentinel: no real day index is negative for any post-epoch date.
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: TipDismissal.none, todayIndex: 0))
    }

    @Test func dismissingHidesTheCardForThatDay() {
        #expect(TipDismissal.isDismissed(dismissedDayIndex: 12, todayIndex: 12))
    }

    @Test func dismissalExpiresOnTheNextDay() {
        // The whole point: no timer, no cleanup — the index simply stops matching.
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: 12, todayIndex: 13))
    }

    @Test func aStaleDismissalFromLongAgoDoesNotHideToday() {
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: 3, todayIndex: 400))
    }
}
