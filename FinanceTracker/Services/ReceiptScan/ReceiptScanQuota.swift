//
//  ReceiptScanQuota.swift
//  FinanceTracker
//
//  S1 (founder's decision 2026-09-21): five scans per calendar month free,
//  then the paywall. The count is the number of scans STARTED (a capture that
//  reached recognition), not saved — a free user who scans five receipts and
//  saves none has used the feature five times.
//
//  Stored per month in UserDefaults under one key per month, so the cap resets
//  by construction and old months need no cleanup logic to be correct.
//

import Foundation

enum ReceiptScanQuota {

    static let keyPrefix = "receiptScan.count."

    /// `"2026-09"` in the user's calendar — a month identity, built numerically.
    static func monthKey(now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%@%04d-%02d", keyPrefix, c.year ?? 0, c.month ?? 0)
    }

    static func count(defaults: UserDefaults = .standard, now: Date = Date(), calendar: Calendar = .current) -> Int {
        defaults.integer(forKey: monthKey(now: now, calendar: calendar))
    }

    /// Called when a capture reaches recognition. Returns the new count.
    @discardableResult
    static func recordScan(defaults: UserDefaults = .standard, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let key = monthKey(now: now, calendar: calendar)
        let next = defaults.integer(forKey: key) + 1
        defaults.set(next, forKey: key)
        return next
    }
}
