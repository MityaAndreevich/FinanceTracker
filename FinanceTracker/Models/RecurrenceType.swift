//
//  RecurrenceType.swift
//  FinanceTracker
//
//  Strongly-typed wrapper around Transaction.recurrenceRaw.
//  nil recurrenceRaw == one-time transaction; a non-nil raw maps to a case here.
//

import Foundation

enum RecurrenceType: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// The raw storage value used in SwiftData (`recurrenceRaw`).
    var raw: String { rawValue }

    /// Best-effort parse; returns nil for unknown / empty values so callers can
    /// treat them as one-time transactions.
    static func from(_ raw: String?) -> RecurrenceType? {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return nil }
        return RecurrenceType(rawValue: raw)
    }

    /// Localization key for the picker / labels.
    var labelKey: String {
        switch self {
        case .weekly:  return "addtx.recurring.weekly"
        case .monthly: return "addtx.recurring.monthly"
        case .yearly:  return "addtx.recurring.yearly"
        }
    }

    /// The `Calendar` component step used to advance one period.
    var dateComponent: Calendar.Component {
        switch self {
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }

    /// Advance a date by exactly one period of this recurrence.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: dateComponent, value: 1, to: date) ?? date
    }
}
