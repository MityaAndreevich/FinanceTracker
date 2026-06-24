//
//  PeriodScope.swift
//  FinanceTracker
//
//  Shared scope model used by Dashboard, Transactions and Analytics views.
//  Replaces the previous "month | all" enum that could only show the
//  current month — this one lets the user navigate to any previous month.
//

import Foundation

enum PeriodScope: Equatable {
    /// A specific month, identified by ANY date inside it.
    case month(Date)
    case all

    static var currentMonth: PeriodScope { .month(Date()) }

    var isMonth: Bool {
        if case .month = self { return true }
        return false
    }

    var isAll: Bool { !isMonth }

    /// Returns true if this scope matches "current month".
    var isCurrentMonth: Bool {
        guard case .month(let d) = self else { return false }
        return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Filtering

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .month(let ref):
            return calendar.isDate(date, equalTo: ref, toGranularity: .month)
        }
    }

    func filter(_ transactions: [Transaction], calendar: Calendar = .current) -> [Transaction] {
        switch self {
        case .all:
            return transactions
        case .month(let ref):
            return transactions.filter { calendar.isDate($0.date, equalTo: ref, toGranularity: .month) }
        }
    }

    // MARK: - Month navigation

    /// Shift by N months. No-op for `.all`.
    func shifted(byMonths n: Int, calendar: Calendar = .current) -> PeriodScope {
        guard case .month(let d) = self else { return self }
        let newDate = calendar.date(byAdding: .month, value: n, to: d) ?? d
        return .month(newDate)
    }

    /// Whether the "next month" button should be enabled (don't go into the future).
    func canShiftForward(calendar: Calendar = .current) -> Bool {
        guard case .month(let d) = self else { return false }
        let now = Date()
        // Compare month boundaries — we allow forward navigation until current month.
        return !calendar.isDate(d, equalTo: now, toGranularity: .month)
            && d < now
    }

    /// Display label, e.g. "May 2026". Uses the supplied locale.
    func label(locale: Locale) -> String {
        switch self {
        case .all:
            return NSLocalizedString("scope.all", comment: "")
        case .month(let d):
            let df = DateFormatter()
            df.locale = locale
            df.setLocalizedDateFormatFromTemplate("MMMM y")
            return df.string(from: d)
        }
    }
}
