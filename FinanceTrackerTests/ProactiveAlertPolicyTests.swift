//
//  ProactiveAlertPolicyTests.swift
//  FinanceTrackerTests
//
//  The whole feature's judgement lives in one pure function, so every rule in the brief
//  is a test here rather than something you have to observe on a device.
//
//  The five nil-guards all exist for the same reason: on a money app, a notification
//  that is wrong is far worse than a notification that never arrives.
//

import Testing
import Foundation
@testable import FinanceTracker

struct ProactiveAlertPolicyTests {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func settings(
        enabled: Bool = true,
        weekday: Int = 6,      // Friday
        hour: Int = 18,
        minute: Int = 0
    ) -> AlertSettings {
        AlertSettings(isEnabled: enabled, weekday: weekday, hour: hour, minute: minute)
    }

    private func snapshot(
        budget: Int = 100_000,
        spent: Int = 40_000,
        elapsed: Int = 14,
        daysInMonth: Int = 31
    ) -> SafeToSpend.Snapshot {
        SafeToSpend.Snapshot(
            monthlyBudgetCents: budget,
            spentCents: spent,
            elapsedDays: elapsed,
            daysInMonth: daysInMonth,
            priorExpenseCents: 50_000,
            priorSpanDays: 30
        )
    }

    // MARK: - Guard 1: disabled

    @Test func disabledSchedulesNothing() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(enabled: false),
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 2: no budget

    @Test func noBudgetSchedulesNothing() {
        // Without a budget there is no safe-to-spend number, so there is nothing
        // truthful to say. Silence, not a guess.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 0), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 3: degenerate elapsed

    @Test func zeroElapsedDaysSchedulesNothing() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(elapsed: 0), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 4: over budget → silence

    @Test func overBudgetSchedulesNothing() {
        // Every truthful sentence about a negative balance is loss-framed, and
        // loss-framing is forbidden. So we say nothing at all.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 130_000), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    @Test func exactlyOnBudgetSchedulesNothing() {
        // remaining == 0: "You have $0.00 safe to spend" is technically true and
        // emotionally a scolding. The boundary belongs on the silent side.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 100_000), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 5: month rollover

    @Test func aFireDateInNextMonthSchedulesNothing() {
        // Tue 28 July, alert set for Saturday → the next Saturday is 1 August, whose
        // numbers reset. Scheduling it would deliver July's figure in August.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 7),          // Saturday
            now: date(2026, 7, 28), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - The happy paths

    @Test func schedulesTheNextMatchingWeekdayInThisMonth() {
        // Tue 14 July 09:00, alert on Friday 18:00 → Fri 17 July 18:00.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 6, hour: 18, minute: 0),
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan != nil)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: plan!.fireDate)
        #expect(comps.year == 2026)
        #expect(comps.month == 7)
        #expect(comps.day == 17)
        #expect(comps.hour == 18)
        #expect(comps.minute == 0)
    }

    @Test func fireDateIsAlwaysInTheFuture() {
        // Today IS Friday and the time has already passed → next Friday, not today.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 6, hour: 8, minute: 0),
            now: date(2026, 7, 17, 20),      // Fri 17 July, 20:00 — 08:00 is gone
            calendar: cal
        )
        #expect(plan != nil)
        #expect(plan!.fireDate > date(2026, 7, 17, 20))
        #expect(cal.component(.day, from: plan!.fireDate) == 24)   // the following Friday
    }

    // MARK: - Body selection

    @Test func fasterPaceGetsThePaceBody() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 40_000), pace: .faster,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan?.body == .pace(amountCents: 60_000))
    }

    @Test func everyOtherPaceStateGetsTheSafeToSpendBody() {
        for pace: PaceMetric.State in [.onPace, .under, .unavailable] {
            let plan = ProactiveAlertPolicy.plan(
                snapshot: snapshot(budget: 100_000, spent: 40_000), pace: pace,
                settings: settings(), now: date(2026, 7, 14), calendar: cal
            )
            #expect(plan?.body == .safeToSpend(amountCents: 60_000),
                    "pace \(pace) should fall back to the safe-to-spend body")
        }
    }

    @Test func bothBodiesCarryTheMonthRemainder() {
        // Guards the spec's copy correction: the amount is the WHOLE MONTH's remainder,
        // so the copy must be month-scoped. Never a week figure.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 250_000, spent: 100_000), pace: .faster,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan?.body == .pace(amountCents: 150_000))
    }
}
