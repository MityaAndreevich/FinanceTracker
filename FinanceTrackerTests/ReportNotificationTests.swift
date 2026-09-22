//
//  ReportNotificationTests.swift
//  FinanceTrackerTests
//
//  DESIGN_REPORTS_1_0_6.md §10.5: fire dates, the closed period, a body with
//  NO figure in it, two identifiers that replace rather than accumulate, a
//  lapsed entitlement cancelling both, and the tap hand-off.
//

import Foundation
import Testing
import UserNotifications
@testable import FinanceTracker

@Suite("Report notifications — policy")
struct ReportNotificationPolicyTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 2
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("nothing enabled → no plans")
    func nothingEnabled() {
        #expect(ReportNotificationPolicy.plan(now: date(2026, 9, 21), settings: .defaults, calendar: cal).isEmpty)
    }

    @Test("weekly on Monday 09:00, evaluated Monday 09:30, fires NEXT Monday and reports the week that will have just closed")
    func weeklyNextOccurrence() throws {
        var s = ReportNotificationPolicy.Settings.defaults
        s.weeklyEnabled = true; s.weeklyWeekday = 2; s.weeklyHour = 9; s.weeklyMinute = 0
        let plans = ReportNotificationPolicy.plan(now: date(2026, 9, 21, 9, 30), settings: s, calendar: cal)   // Mon
        let plan = try #require(plans.first)
        #expect(plans.count == 1)
        #expect(plan.cadence == .weekly)
        #expect(plan.fireDate == date(2026, 9, 28, 9, 0))
        #expect(plan.period.identity(calendar: cal) == "week:2026-09-21")
        #expect(plan.period.range(calendar: cal).upperBound <= plan.fireDate)
    }

    @Test("weekly on Wednesday reports the calendar week that closed the previous Sunday night — never a partial week")
    func weeklyMidweek() throws {
        var s = ReportNotificationPolicy.Settings.defaults
        s.weeklyEnabled = true; s.weeklyWeekday = 4; s.weeklyHour = 8; s.weeklyMinute = 0
        let plan = try #require(ReportNotificationPolicy.plan(now: date(2026, 9, 21), settings: s, calendar: cal).first)
        #expect(plan.fireDate == date(2026, 9, 23, 8, 0))
        #expect(plan.period.identity(calendar: cal) == "week:2026-09-14")
        #expect(plan.period.dayCount(calendar: cal) == 7)
    }

    @Test("monthly always fires on the 1st, across a year boundary, about December")
    func monthlyOnTheFirst() throws {
        var s = ReportNotificationPolicy.Settings.defaults
        s.monthlyEnabled = true; s.monthlyHour = 10; s.monthlyMinute = 15
        let plan = try #require(ReportNotificationPolicy.plan(now: date(2026, 12, 20), settings: s, calendar: cal).first)
        #expect(plan.cadence == .monthly)
        #expect(plan.fireDate == date(2027, 1, 1, 10, 15))
        #expect(plan.period.identity(calendar: cal) == "month:2026-12")
    }

    @Test("both enabled → two plans, one per cadence")
    func both() {
        var s = ReportNotificationPolicy.Settings.defaults
        s.weeklyEnabled = true; s.monthlyEnabled = true
        let plans = ReportNotificationPolicy.plan(now: date(2026, 9, 21), settings: s, calendar: cal)
        #expect(plans.map(\.cadence) == [.weekly, .monthly])
    }

    @Test("settings round-trip through UserDefaults with the documented defaults")
    func settingsRoundTrip() {
        let suite = "ReportNotificationPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ReportNotificationPolicy.Settings.read(defaults) == .defaults)
        defaults.set(true, forKey: ReportNotificationPolicy.Keys.weeklyEnabled)
        defaults.set(6, forKey: ReportNotificationPolicy.Keys.weeklyWeekday)
        defaults.set(18, forKey: ReportNotificationPolicy.Keys.weeklyHour)
        let read = ReportNotificationPolicy.Settings.read(defaults)
        #expect(read.weeklyEnabled && read.weeklyWeekday == 6 && read.weeklyHour == 18 && read.weeklyMinute == 0)
    }
}

@Suite("Report notifications — scheduler", .serialized)
@MainActor
struct ReportNotificationSchedulerTests {

    private var cal: Calendar { Calendar.current }

    private func plan(_ cadence: ReportCadence) -> ReportNotificationPolicy.Plan {
        let fire = Date().addingTimeInterval(3 * 24 * 3600)
        return .init(cadence: cadence, fireDate: fire, period: ReportPeriod.closed(before: fire, cadence: cadence, calendar: cal))
    }

    @Test("the body names the period and carries NO digit that could be an amount")
    func bodyCarriesNoFigure() throws {
        let p = plan(.weekly)
        let request = ReportNotificationScheduler.request(for: p, calendar: cal)
        let label = p.period.label(locale: .current, calendar: cal)
        #expect(request.content.body.contains(label))
        // Strip the label (which legitimately contains day/year digits) and
        // check what is left carries no number at all.
        let rest = request.content.body.replacingOccurrences(of: label, with: "")
        #expect(rest.rangeOfCharacter(from: .decimalDigits) == nil, "the body has a figure in it: \(request.content.body)")
        #expect(!request.content.title.isEmpty)
        #expect(request.content.userInfo[ReportNotificationScheduler.periodUserInfoKey] as? String == p.period.identity(calendar: cal))
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
    }

    @Test("apply replaces both identifiers and schedules one request per plan")
    func applyReplaces() {
        let center = FakeNotificationCenter()
        ReportNotificationScheduler.apply(plans: [plan(.weekly), plan(.monthly)], calendar: cal, center: center)
        #expect(center.removedIdentifiers == ReportNotificationScheduler.identifiers)
        #expect(center.added.map(\.identifier) == [ReportNotificationScheduler.weeklyIdentifier, ReportNotificationScheduler.monthlyIdentifier])
        // A second pass removes first, so there is never more than one per cadence.
        ReportNotificationScheduler.apply(plans: [plan(.weekly)], calendar: cal, center: center)
        #expect(center.removedIdentifiers.count == 4)
        #expect(center.added.count == 3)
    }

    @Test("a lapsed entitlement cancels both and schedules nothing, whatever the settings say")
    func lapseCancels() {
        let suite = "ReportNotificationSchedulerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: ReportNotificationPolicy.Keys.weeklyEnabled)
        defaults.set(true, forKey: ReportNotificationPolicy.Keys.monthlyEnabled)
        let center = FakeNotificationCenter()
        ReportNotificationRefresher.apply(isAllowed: false, defaults: defaults, center: center)
        #expect(center.added.isEmpty)
        #expect(center.removedIdentifiers == ReportNotificationScheduler.identifiers)

        let allowed = FakeNotificationCenter()
        ReportNotificationRefresher.apply(isAllowed: true, defaults: defaults, center: allowed)
        #expect(allowed.added.count == 2)
    }

    @Test("the tap hand-off writes the period identity to the App Group and posts the intent notification")
    func tapHandOff() {
        let defaults = UserDefaults.appGroup
        defaults.removeObject(forKey: AppDelegate.pendingOpenReportKey)
        defer { defaults.removeObject(forKey: AppDelegate.pendingOpenReportKey) }
        var posted = 0
        let token = NotificationCenter.default.addObserver(forName: .budgetCrabPendingIntent, object: nil, queue: nil) { _ in posted += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        AppDelegate.requestOpenReport(identity: "week:2026-09-14")
        #expect(defaults.string(forKey: AppDelegate.pendingOpenReportKey) == "week:2026-09-14")
        #expect(posted == 1)
        #expect(ReportPeriod.from(identity: "week:2026-09-14", calendar: cal) != nil)
    }
}
