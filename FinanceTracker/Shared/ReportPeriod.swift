//
//  ReportPeriod.swift
//  FinanceTracker
//
//  The period a report is about. Pure value: no SwiftData, no clock of its own.
//
//  Distinct from `PeriodScope` on purpose. `PeriodScope` is navigation state for
//  three screens and carries `.all`; a report is never "all" — it is one closed
//  span with a well-defined previous span, which is what makes period-over-period
//  arithmetic honest. `.month` bridges to `PeriodScope.month` (see `scope`).
//
//  Weeks follow the USER's calendar (`calendar.firstWeekday`), not the frozen
//  ISO calendar in `RecurrencePeriod` — those are identity keys for recurring
//  charges; this is what the user sees on screen. Do not unify them.
//
//  Design: outputs/DESIGN_REPORTS_1_0_6.md §2, §5.1.
//

import Foundation

enum ReportCadence: String, Sendable {
    case weekly, monthly
}

enum ReportPeriod: Equatable, Hashable, Sendable {
    /// The week / month / year containing `Date`, in the supplied calendar.
    case week(containing: Date)
    case month(containing: Date)
    case year(containing: Date)
    /// Inclusive day range. `start` and `end` are any instants inside the first
    /// and last day; `range(calendar:)` snaps both to day boundaries.
    case custom(start: Date, end: Date)

    /// A custom range longer than this is refused by the UI.
    static let maxCustomYears = 5

    enum Kind: String, CaseIterable, Sendable {
        case week, month, year, custom
    }

    var kind: Kind {
        switch self {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        case .custom: return .custom
        }
    }

    // MARK: - Range

    /// Half-open `[start, end)` at day precision in `calendar`'s time zone.
    func range(calendar: Calendar) -> Range<Date> {
        switch self {
        case .week(let d):
            return Self.interval(.weekOfYear, containing: d, calendar: calendar)
        case .month(let d):
            return Self.interval(.month, containing: d, calendar: calendar)
        case .year(let d):
            return Self.interval(.year, containing: d, calendar: calendar)
        case .custom(let start, let end):
            let lo = calendar.startOfDay(for: min(start, end))
            let hiDay = calendar.startOfDay(for: max(start, end))
            // `date(byAdding:)` returns nil only for unrepresentable dates; the
            // day after `hiDay` is representable for any date a user can pick.
            let hi = calendar.date(byAdding: .day, value: 1, to: hiDay) ?? hiDay
            return lo..<hi
        }
    }

    private static func interval(_ component: Calendar.Component, containing d: Date, calendar: Calendar) -> Range<Date> {
        // `dateInterval(of:for:)` is nil only outside the calendar's range.
        guard let interval = calendar.dateInterval(of: component, for: d) else {
            let day = calendar.startOfDay(for: d)
            return day..<day
        }
        return interval.start..<interval.end
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        range(calendar: calendar).contains(date)
    }

    /// Whole days in the period (custom periods are defined by this).
    func dayCount(calendar: Calendar) -> Int {
        let r = range(calendar: calendar)
        return calendar.dateComponents([.day], from: r.lowerBound, to: r.upperBound).day ?? 0
    }

    // MARK: - Navigation

    /// The period immediately before this one. For `.custom`, the range of the
    /// SAME number of days ending the day before `start` — the only definition
    /// under which a comparison of two custom ranges compares like with like.
    func previous(calendar: Calendar) -> ReportPeriod {
        shifted(by: -1, calendar: calendar)
    }

    func shifted(by n: Int, calendar: Calendar) -> ReportPeriod {
        switch self {
        case .week(let d):
            let r = range(calendar: calendar)
            return .week(containing: calendar.date(byAdding: .weekOfYear, value: n, to: r.lowerBound) ?? d)
        case .month(let d):
            let r = range(calendar: calendar)
            return .month(containing: calendar.date(byAdding: .month, value: n, to: r.lowerBound) ?? d)
        case .year(let d):
            let r = range(calendar: calendar)
            return .year(containing: calendar.date(byAdding: .year, value: n, to: r.lowerBound) ?? d)
        case .custom:
            let days = dayCount(calendar: calendar)
            let r = range(calendar: calendar)
            guard let newStart = calendar.date(byAdding: .day, value: n * days, to: r.lowerBound),
                  let newEndExclusive = calendar.date(byAdding: .day, value: days, to: newStart),
                  let newEnd = calendar.date(byAdding: .day, value: -1, to: newEndExclusive)
            else { return self }
            return .custom(start: newStart, end: newEnd)
        }
    }

    /// Forward navigation stops at the period containing `now`.
    func canShiftForward(now: Date, calendar: Calendar) -> Bool {
        range(calendar: calendar).upperBound <= now
    }

    /// True when `now` falls inside the period (the period is still open).
    func isOpen(now: Date, calendar: Calendar) -> Bool {
        contains(now, calendar: calendar)
    }

    // MARK: - The period an automatic report is about

    /// The last period of `cadence` that ended at or before `fire`. A weekly
    /// report set to fire on Wednesday reports on the week that ended the
    /// previous week-end, never on a partial week.
    static func closed(before fire: Date, cadence: ReportCadence, calendar: Calendar) -> ReportPeriod {
        let current: ReportPeriod
        switch cadence {
        case .weekly: current = .week(containing: fire)
        case .monthly: current = .month(containing: fire)
        }
        // If `fire` is exactly on a boundary the current period starts there and
        // the one before it has just closed; if `fire` is inside a period, that
        // period is open and the previous one is the closed one. Same answer.
        return current.previous(calendar: calendar)
    }

    // MARK: - Identity and labels

    /// Stable, ASCII-only, locale-free. Used in notification `userInfo`, file
    /// names and the App-Group hand-off. Built from numeric components in
    /// `calendar` — never through a `DateFormatter`, for the reasons recorded at
    /// `RecurrencePeriod.swift:50–60`.
    func identity(calendar: Calendar) -> String {
        let r = range(calendar: calendar)
        let c = calendar.dateComponents([.year, .month, .day], from: r.lowerBound)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        switch self {
        case .week:
            return String(format: "week:%04d-%02d-%02d", y, m, d)
        case .month:
            return String(format: "month:%04d-%02d", y, m)
        case .year:
            return String(format: "year:%04d", y)
        case .custom:
            let last = calendar.date(byAdding: .day, value: -1, to: r.upperBound) ?? r.lowerBound
            let e = calendar.dateComponents([.year, .month, .day], from: last)
            return String(format: "custom:%04d-%02d-%02d..%04d-%02d-%02d",
                          y, m, d, e.year ?? 0, e.month ?? 0, e.day ?? 0)
        }
    }

    /// Inverse of `identity(calendar:)`. Nil for anything it did not produce.
    static func from(identity: String, calendar: Calendar) -> ReportPeriod? {
        let parts = identity.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        func day(_ s: String) -> Date? {
            let n = s.split(separator: "-").compactMap { Int($0) }
            guard n.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: n[0], month: n[1], day: n[2], hour: 12))
        }
        switch parts[0] {
        case "week":
            return day(parts[1]).map { .week(containing: $0) }
        case "month":
            let n = parts[1].split(separator: "-").compactMap { Int($0) }
            guard n.count == 2,
                  let d = calendar.date(from: DateComponents(year: n[0], month: n[1], day: 1, hour: 12))
            else { return nil }
            return .month(containing: d)
        case "year":
            guard let y = Int(parts[1]),
                  let d = calendar.date(from: DateComponents(year: y, month: 1, day: 1, hour: 12))
            else { return nil }
            return .year(containing: d)
        case "custom":
            let ends = parts[1].components(separatedBy: "..")
            guard ends.count == 2, let s = day(ends[0]), let e = day(ends[1]), s <= e else { return nil }
            return .custom(start: s, end: e)
        default:
            return nil
        }
    }

    /// Human label in `locale`: "Sep 14 – 20, 2026" · "September 2026" · "2026" ·
    /// "Mar 10 – Apr 20, 2026".
    func label(locale: Locale, calendar: Calendar) -> String {
        let r = range(calendar: calendar)
        let last = calendar.date(byAdding: .day, value: -1, to: r.upperBound) ?? r.lowerBound
        switch self {
        case .month(let d):
            let df = DateFormatter()
            df.locale = locale
            df.calendar = calendar
            df.setLocalizedDateFormatFromTemplate("MMMM y")
            return df.string(from: d)
        case .year(let d):
            let df = DateFormatter()
            df.locale = locale
            df.calendar = calendar
            df.setLocalizedDateFormatFromTemplate("y")
            return df.string(from: d)
        case .week, .custom:
            let f = DateIntervalFormatter()
            f.locale = locale
            f.calendar = calendar
            f.dateTemplate = "MMM d y"
            return f.string(from: r.lowerBound, to: last)
        }
    }

    /// Bridge for screens that are month-scoped (`CategoryDetailView`).
    var scope: PeriodScope? {
        guard case .month(let d) = self else { return nil }
        return .month(d)
    }
}

extension ReportPeriod: Identifiable {
    /// For `.sheet(item:)`. The user's calendar is the only one a presentation
    /// can mean, so this is the one place `Calendar.current` appears here.
    var id: String { identity(calendar: .current) }
}
