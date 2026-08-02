//
//  RecurrenceType.swift
//  FinanceTracker
//
//  Strongly-typed wrapper around Transaction.recurrenceRaw.
//  nil recurrenceRaw == one-time transaction; a non-nil raw maps to a case here.
//
//  ┌─────────────────────────────────────────────────────────────────────────┐
//  │ THE RAW VALUES ARE FROZEN — for TWO reasons, and the second one is       │
//  │ invisible from this file.                                               │
//  │                                                                         │
//  │ 1. `recurrenceRaw` storage. Renaming a case's raw value orphans every    │
//  │    stored row: `from(_:)` returns nil and a recurring series silently    │
//  │    becomes one-time. This one is at least guessable from the file.       │
//  │                                                                         │
//  │ 2. `cadence.rawValue` is the MIDDLE SEGMENT of                           │
//  │    `Transaction.occurrenceKey` — see `RecurrencePeriod.swift`, whose     │
//  │    header carries the full key format and the freeze rationale. Renaming │
//  │    a raw value re-keys every occurrence of that cadence, so rows already │
//  │    posted stop matching rows posted after the rename, and the           │
//  │    duplicate-collapse that key exists for stops collapsing them.         │
//  │                                                                         │
//  │ Neither failure is caught by the compiler and neither is visible at the  │
//  │ rename site. `rawValue` here is persisted data and a wire format, not a  │
//  │ name.                                                                   │
//  └─────────────────────────────────────────────────────────────────────────┘
//
//  ADDING a fourth cadence (e.g. `daily`) is safe — the freeze is on renaming,
//  not on growth:
//
//  - A new raw value is a new key namespace. `occurrenceKey` segments on the
//    cadence, so a `daily` key can never alias a weekly/monthly/yearly one no
//    matter what its period label looks like.
//  - Nothing is re-keyed. Existing rows keep their cadence and therefore their
//    keys; only new series use the new namespace.
//  - The decision that would otherwise be silent is forced at compile time:
//    `RecurrencePeriod.label(for:cadence:)` switches exhaustively with no
//    `default:`, on purpose, so a new case cannot fall through to a wrong label.
//    (`labelKey` and `dateComponent` below are exhaustive for the same reason.)
//
//  So: add cases freely, and answer the compiler where it stops you. Never
//  rename one.
//

import Foundation

enum RecurrenceType: String, CaseIterable, Identifiable, Sendable {
    // Raw values are frozen — see the header. Add, never rename.
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
