//
//  ProactiveAlertPolicy.swift
//  FinanceTracker
//
//  Whether to send a weekly alert, when, and what it says. Pure — no notification
//  centre, no Bundle, no ambient clock — so every rule is unit-testable.
//
//  The five nil-guards below all exist for one reason: on a money app, an alert that is
//  wrong is far worse than an alert that never arrives. When we cannot say something
//  both true and gain-framed, we say nothing.
//

import Foundation

/// The user's alert preferences, mirrored out of `@AppStorage` so the policy stays pure.
struct AlertSettings: Equatable, Sendable {
    let isEnabled: Bool
    /// `Calendar` numbering: 1 = Sunday … 7 = Saturday.
    let weekday: Int
    let hour: Int
    let minute: Int
}

enum ProactiveAlertPolicy {

    /// What the notification says. Both bodies carry the **whole month's** remainder,
    /// which is why the copy is month-scoped — presenting this as a week figure would
    /// overstate what is safe to spend and encourage overspending.
    enum Body: Equatable, Sendable {
        case safeToSpend(amountCents: Int)
        case pace(amountCents: Int)
    }

    struct Plan: Equatable, Sendable {
        let fireDate: Date
        let body: Body
    }

    static func plan(
        snapshot: SafeToSpend.Snapshot,
        pace: PaceMetric.State,
        settings: AlertSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Plan? {
        // 1. The user turned alerts off.
        guard settings.isEnabled else { return nil }

        // 2. No budget ⇒ no safe-to-spend number ⇒ nothing truthful to say.
        guard snapshot.isBudgetSet else { return nil }

        // 3. Degenerate period — the same guard PaceMetric applies to itself.
        guard snapshot.elapsedDays > 0 else { return nil }

        // 4. Over budget (or exactly on it). Every honest sentence about a negative
        //    balance is loss-framed, and loss-framing is forbidden — it is the anxiety
        //    trigger the research says to avoid. The dashboard still shows the truth to
        //    anyone who opens the app; we are declining to *push* bad news, not hiding it.
        guard snapshot.remainingCents > 0 else { return nil }

        guard let fireDate = nextFireDate(settings: settings, now: now, calendar: calendar)
        else { return nil }

        // 5. Month rollover: the numbers reset on the 1st, so an alert computed in July
        //    must never be delivered in August still carrying July's figure.
        guard calendar.isDate(fireDate, equalTo: now, toGranularity: .month) else { return nil }

        let amount = snapshot.remainingCents
        let body: Body = (pace == .faster)
            ? .pace(amountCents: amount)
            : .safeToSpend(amountCents: amount)

        return Plan(fireDate: fireDate, body: body)
    }

    /// The next occurrence of the chosen weekday-and-time strictly after `now` — so an
    /// alert set for 08:00 on a Friday, evaluated at 20:00 on that Friday, lands next
    /// Friday rather than in the past.
    private static func nextFireDate(
        settings: AlertSettings,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.weekday = settings.weekday
        components.hour = settings.hour
        components.minute = settings.minute

        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }
}
