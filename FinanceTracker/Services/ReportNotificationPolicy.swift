//
//  ReportNotificationPolicy.swift
//  FinanceTracker
//
//  When the automatic weekly / monthly report notifications fire, and which
//  period each one is about. Pure: no clock, no notification center.
//
//  THE BODY CARRIES NO FIGURES — by design, twice over. The period a
//  notification announces has only just closed when it fires, so its figures
//  did not exist when the notification was scheduled; and a lock-screen banner
//  is not a private surface. The body names the period; the report is built
//  when the user opens it. Design: outputs/DESIGN_REPORTS_1_0_6.md §6.
//

import Foundation

enum ReportNotificationPolicy {

    struct Settings: Equatable, Sendable {
        var weeklyEnabled: Bool
        /// 1 = Sunday … 7 = Saturday (Calendar numbering).
        var weeklyWeekday: Int
        var weeklyHour: Int
        var weeklyMinute: Int
        var monthlyEnabled: Bool
        var monthlyHour: Int
        var monthlyMinute: Int

        static let defaults = Settings(weeklyEnabled: false, weeklyWeekday: 2, weeklyHour: 9, weeklyMinute: 0,
                                       monthlyEnabled: false, monthlyHour: 9, monthlyMinute: 0)

        static func read(_ defaults: UserDefaults) -> Settings {
            Settings(
                weeklyEnabled: defaults.bool(forKey: Keys.weeklyEnabled),
                weeklyWeekday: defaults.object(forKey: Keys.weeklyWeekday) as? Int ?? Settings.defaults.weeklyWeekday,
                weeklyHour: defaults.object(forKey: Keys.weeklyHour) as? Int ?? Settings.defaults.weeklyHour,
                weeklyMinute: defaults.object(forKey: Keys.weeklyMinute) as? Int ?? Settings.defaults.weeklyMinute,
                monthlyEnabled: defaults.bool(forKey: Keys.monthlyEnabled),
                monthlyHour: defaults.object(forKey: Keys.monthlyHour) as? Int ?? Settings.defaults.monthlyHour,
                monthlyMinute: defaults.object(forKey: Keys.monthlyMinute) as? Int ?? Settings.defaults.monthlyMinute
            )
        }
    }

    /// The `@AppStorage` keys `ReportsSettingsView` writes and `Settings.read` reads.
    enum Keys {
        static let weeklyEnabled = "reportWeeklyEnabled"
        static let weeklyWeekday = "reportWeeklyWeekday"
        static let weeklyHour = "reportWeeklyHour"
        static let weeklyMinute = "reportWeeklyMinute"
        static let monthlyEnabled = "reportMonthlyEnabled"
        static let monthlyHour = "reportMonthlyHour"
        static let monthlyMinute = "reportMonthlyMinute"
    }

    struct Plan: Equatable, Sendable {
        let cadence: ReportCadence
        let fireDate: Date
        /// The period that will have just closed when `fireDate` arrives.
        let period: ReportPeriod
    }

    /// One plan per enabled cadence. The monthly report always fires on the
    /// 1st (founder's decision 2026-09-21: no day picker — a report "for
    /// August" delivered on the 15th of September is not a monthly report).
    static func plan(now: Date, settings: Settings, calendar: Calendar) -> [Plan] {
        var plans: [Plan] = []
        if settings.weeklyEnabled {
            var c = DateComponents()
            c.weekday = settings.weeklyWeekday
            c.hour = settings.weeklyHour
            c.minute = settings.weeklyMinute
            if let fire = calendar.nextDate(after: now, matching: c, matchingPolicy: .nextTime, direction: .forward) {
                plans.append(Plan(cadence: .weekly, fireDate: fire,
                                  period: ReportPeriod.closed(before: fire, cadence: .weekly, calendar: calendar)))
            }
        }
        if settings.monthlyEnabled {
            var c = DateComponents()
            c.day = 1
            c.hour = settings.monthlyHour
            c.minute = settings.monthlyMinute
            if let fire = calendar.nextDate(after: now, matching: c, matchingPolicy: .nextTime, direction: .forward) {
                plans.append(Plan(cadence: .monthly, fireDate: fire,
                                  period: ReportPeriod.closed(before: fire, cadence: .monthly, calendar: calendar)))
            }
        }
        return plans
    }
}
