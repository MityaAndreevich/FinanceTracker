//
//  ReportPeriodTests.swift
//  FinanceTrackerTests
//
//  DESIGN_REPORTS_1_0_6.md §10.1. Every calendar here is constructed explicitly
//  — first weekday, time zone — because the process calendar is whatever the
//  simulator happens to be, and a period boundary that depends on it is a test
//  that passes on one machine.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("ReportPeriod")
struct ReportPeriodTests {

    private func cal(firstWeekday: Int = 2, tz: String = "America/New_York") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: tz)!
        c.firstWeekday = firstWeekday
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func ymd(_ date: Date, _ c: Calendar) -> (Int, Int, Int) {
        let x = c.dateComponents([.year, .month, .day], from: date)
        return (x.year!, x.month!, x.day!)
    }

    // MARK: - Ranges

    @Test("a Monday-first week containing a Wednesday runs Mon..<next Mon")
    func weekMondayFirst() {
        let c = cal(firstWeekday: 2)
        let r = ReportPeriod.week(containing: date(2026, 9, 16, calendar: c)).range(calendar: c)   // Wed
        #expect(ymd(r.lowerBound, c) == (2026, 9, 14))
        #expect(ymd(r.upperBound, c) == (2026, 9, 21))
        #expect(c.component(.hour, from: r.lowerBound) == 0)
    }

    @Test("a Sunday-first week containing the same Wednesday runs Sun..<next Sun")
    func weekSundayFirst() {
        let c = cal(firstWeekday: 1)
        let r = ReportPeriod.week(containing: date(2026, 9, 16, calendar: c)).range(calendar: c)
        #expect(ymd(r.lowerBound, c) == (2026, 9, 13))
        #expect(ymd(r.upperBound, c) == (2026, 9, 20))
    }

    @Test("month and year snap to their first day and the next period's first day")
    func monthAndYear() {
        let c = cal()
        let m = ReportPeriod.month(containing: date(2026, 2, 17, calendar: c)).range(calendar: c)
        #expect(ymd(m.lowerBound, c) == (2026, 2, 1))
        #expect(ymd(m.upperBound, c) == (2026, 3, 1))
        let y = ReportPeriod.year(containing: date(2026, 7, 4, calendar: c)).range(calendar: c)
        #expect(ymd(y.lowerBound, c) == (2026, 1, 1))
        #expect(ymd(y.upperBound, c) == (2027, 1, 1))
    }

    @Test("custom is inclusive of both days and tolerates reversed arguments")
    func customInclusive() {
        let c = cal()
        let p = ReportPeriod.custom(start: date(2026, 4, 20, 23, calendar: c), end: date(2026, 3, 10, 1, calendar: c))
        let r = p.range(calendar: c)
        #expect(ymd(r.lowerBound, c) == (2026, 3, 10))
        #expect(ymd(r.upperBound, c) == (2026, 4, 21))
        #expect(p.dayCount(calendar: c) == 42)
        #expect(p.contains(date(2026, 4, 20, 23, calendar: c), calendar: c))
        #expect(!p.contains(date(2026, 4, 21, 0, calendar: c), calendar: c))
    }

    @Test("a week across a DST transition still has seven days and midnight bounds")
    func dstWeek() {
        for tz in ["America/New_York", "Europe/Kyiv"] {
            let c = cal(firstWeekday: 2, tz: tz)
            // 2026-03-08 (US) and 2026-03-29 (EU) are spring-forward Sundays.
            for probe in [date(2026, 3, 9, calendar: c), date(2026, 3, 30, calendar: c)] {
                let p = ReportPeriod.week(containing: probe)
                #expect(p.dayCount(calendar: c) == 7, "\(tz)")
                let r = p.range(calendar: c)
                #expect(c.component(.hour, from: r.lowerBound) == 0, "\(tz)")
                #expect(c.component(.hour, from: r.upperBound) == 0, "\(tz)")
            }
        }
    }

    @Test("February in a leap year has 29 days")
    func leapYear() {
        let c = cal()
        #expect(ReportPeriod.month(containing: date(2024, 2, 10, calendar: c)).dayCount(calendar: c) == 29)
        #expect(ReportPeriod.year(containing: date(2024, 6, 1, calendar: c)).dayCount(calendar: c) == 366)
    }

    // MARK: - Previous / shifting

    @Test("previous week, month and year are the adjacent ones")
    func previousStandard() {
        let c = cal()
        let w = ReportPeriod.week(containing: date(2026, 1, 1, calendar: c)).previous(calendar: c)
        #expect(ymd(w.range(calendar: c).lowerBound, c) == (2025, 12, 22))
        let m = ReportPeriod.month(containing: date(2026, 1, 15, calendar: c)).previous(calendar: c)
        #expect(m.identity(calendar: c) == "month:2025-12")
        let y = ReportPeriod.year(containing: date(2026, 1, 15, calendar: c)).previous(calendar: c)
        #expect(y.identity(calendar: c) == "year:2025")
    }

    @Test("previous custom range has the same day count and ends the day before start")
    func previousCustomEqualLength() {
        let c = cal()
        let p = ReportPeriod.custom(start: date(2026, 3, 10, calendar: c), end: date(2026, 4, 20, calendar: c))
        let prev = p.previous(calendar: c)
        #expect(prev.dayCount(calendar: c) == p.dayCount(calendar: c))
        #expect(prev.range(calendar: c).upperBound == p.range(calendar: c).lowerBound)
        #expect(prev.identity(calendar: c) == "custom:2026-01-27..2026-03-09")
        #expect(prev.shifted(by: 1, calendar: c).range(calendar: c) == p.range(calendar: c))
    }

    @Test("forward navigation stops at the period containing now")
    func forwardStop() {
        let c = cal()
        let now = date(2026, 9, 21, 15, calendar: c)
        #expect(ReportPeriod.month(containing: date(2026, 8, 3, calendar: c)).canShiftForward(now: now, calendar: c))
        #expect(!ReportPeriod.month(containing: now).canShiftForward(now: now, calendar: c))
        #expect(ReportPeriod.month(containing: now).isOpen(now: now, calendar: c))
        #expect(!ReportPeriod.week(containing: date(2026, 9, 7, calendar: c)).isOpen(now: now, calendar: c))
    }

    // MARK: - The closed period an automatic report is about

    @Test("weekly fired on a Wednesday reports the week that ended on the last week boundary")
    func closedWeeklyMidweek() {
        let c = cal(firstWeekday: 2)
        let fire = date(2026, 9, 16, 9, calendar: c)   // Wednesday
        let p = ReportPeriod.closed(before: fire, cadence: .weekly, calendar: c)
        #expect(p.identity(calendar: c) == "week:2026-09-07")
        #expect(p.range(calendar: c).upperBound <= fire)
    }

    @Test("weekly fired exactly at the week boundary reports the week that just ended")
    func closedWeeklyOnBoundary() {
        let c = cal(firstWeekday: 2)
        let fire = date(2026, 9, 14, 0, calendar: c)   // Monday 00:00
        #expect(ReportPeriod.closed(before: fire, cadence: .weekly, calendar: c).identity(calendar: c) == "week:2026-09-07")
        let nine = date(2026, 9, 14, 9, calendar: c)
        #expect(ReportPeriod.closed(before: nine, cadence: .weekly, calendar: c).identity(calendar: c) == "week:2026-09-07")
    }

    @Test("monthly fired on the 1st across a year boundary reports December of the previous year")
    func closedMonthlyYearBoundary() {
        let c = cal()
        let fire = date(2027, 1, 1, 9, calendar: c)
        #expect(ReportPeriod.closed(before: fire, cadence: .monthly, calendar: c).identity(calendar: c) == "month:2026-12")
    }

    // MARK: - Identity

    @Test("identity is ASCII-only and round-trips for every kind",
          arguments: ["week:2026-09-14", "month:2026-02", "year:2024", "custom:2026-03-10..2026-04-20"])
    func identityRoundTrip(id: String) throws {
        let c = cal()
        let p = try #require(ReportPeriod.from(identity: id, calendar: c))
        #expect(p.identity(calendar: c) == id)
        #expect(id.allSatisfy { $0.isASCII })
    }

    @Test("identity rejects garbage", arguments: ["", "week", "month:2026", "custom:2026-04-20..2026-03-10", "decade:2020", "year:abc"])
    func identityRejects(id: String) {
        #expect(ReportPeriod.from(identity: id, calendar: cal()) == nil)
    }

    @Test("a week identity names the week's first day under the calendar used")
    func weekIdentityUsesFirstWeekday() {
        let d = date(2026, 9, 16, calendar: cal())
        #expect(ReportPeriod.week(containing: d).identity(calendar: cal(firstWeekday: 2)) == "week:2026-09-14")
        #expect(ReportPeriod.week(containing: d).identity(calendar: cal(firstWeekday: 1)) == "week:2026-09-13")
    }

    // MARK: - Labels

    @Test("labels are produced for every kind in every shipped locale, non-empty and containing the year")
    func labels() {
        let c = cal()
        let d = date(2026, 9, 16, calendar: c)
        let periods: [ReportPeriod] = [.week(containing: d), .month(containing: d), .year(containing: d),
                                       .custom(start: date(2026, 3, 10, calendar: c), end: date(2026, 4, 20, calendar: c))]
        for id in ["en_US", "ru_RU", "es_MX", "pt_BR", "uk_UA"] {
            for p in periods {
                let s = p.label(locale: Locale(identifier: id), calendar: c)
                #expect(!s.isEmpty, "\(id) \(p)")
                #expect(s.contains("2026"), "\(id) \(p) → \(s)")
            }
        }
    }

    @Test("only a month bridges to PeriodScope")
    func scopeBridge() {
        let c = cal()
        let d = date(2026, 9, 16, calendar: c)
        #expect(ReportPeriod.month(containing: d).scope == .month(d))
        #expect(ReportPeriod.week(containing: d).scope == nil)
        #expect(ReportPeriod.year(containing: d).scope == nil)
    }
}
