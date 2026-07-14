//
//  TipRotation.swift
//  FinanceTracker
//
//  Which tip shows today. Pure math — no I/O, no Bundle, no ambient calendar —
//  so the whole contract is unit-testable.
//

import Foundation

enum TipRotation {

    /// Day 0 of the rotation. Arbitrary, but **fixed by contract**: ContentStudio
    /// derives the social calendar from this same index, so changing the epoch
    /// reshuffles every user's sequence and desynchronizes the calendar.
    static let epoch = DateComponents(year: 2026, month: 1, day: 1)

    /// The zone ContentStudio uses to derive "day N".
    ///
    /// The app itself passes `.current`, so the tip rolls over at the user's local
    /// midnight. That means a user near the dateline can sit ±1 day off the derived
    /// post — pinning this zone removes ambiguity from the derivation, it does not
    /// (and cannot) eliminate that skew. Accepted cost of local rollover.
    static let referenceTimeZone = TimeZone(identifier: "UTC")!

    /// Whole days from the epoch to `date`'s start-of-day in `timeZone`.
    /// Negative for dates before the epoch.
    static func dayIndex(for date: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let epochDate = calendar.date(from: epoch) else { return 0 }
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: epochDate, to: startOfDay).day ?? 0
    }

    /// Index into the canonical tip array, or nil when the library is empty.
    ///
    /// The double-modulo is not superstition: Swift's `%` returns a negative result
    /// for a negative dividend, so a device clock set before the epoch would index
    /// out of bounds.
    static func tipIndex(dayIndex: Int, canonicalCount: Int) -> Int? {
        guard canonicalCount > 0 else { return nil }
        return ((dayIndex % canonicalCount) + canonicalCount) % canonicalCount
    }
}

/// Whether today's tip has been dismissed.
///
/// Stored as the *day index* that was dismissed, not a flag or a timestamp: the
/// card is hidden only while the stored index equals today's, so the dismissal
/// expires by itself at the next local midnight. No timer, no cleanup job.
enum TipDismissal {
    /// `@AppStorage` key. -1 means "nothing dismissed" — no post-epoch day is negative.
    static let storageKey = "tipDismissedDayIndex"
    static let none = -1

    static func isDismissed(dismissedDayIndex: Int, todayIndex: Int) -> Bool {
        dismissedDayIndex == todayIndex
    }
}
