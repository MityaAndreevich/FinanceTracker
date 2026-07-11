//
//  ReverseTrial.swift
//  FinanceTracker
//
//  The reverse trial: on first launch of 1.0.2 the user silently gets 14 days of
//  FULL premium with no card and no subscription. When it lapses they fall back
//  to the free tier (keeping every byte they created) and the paywall makes its
//  case against a concrete sense of loss.
//
//  This is NOT Apple's StoreKit introductory offer. The 30-day StoreKit free
//  trial is an offer attached to the subscription and is granted by Apple at
//  purchase time; it surfaces as a real entitlement. The reverse trial is ours,
//  is local, and grants no entitlement. Never conflate them, never double-grant.
//

import Foundation

/// Persistence seam for the trial. Injected so the state machine can be tested
/// without touching real user defaults.
protocol ReverseTrialStore: AnyObject {
    var reverseTrialStartDate: Date? { get set }

    /// Set once, when we've shown the "your trial ended" paywall. We ask exactly
    /// one time. Re-raising it on every launch would be nagware, and the gates
    /// already make the case whenever the user actually reaches for something.
    var hasShownTrialEndPaywall: Bool { get set }
}

/// Pure, date-injectable trial math. No storage, no StoreKit, no UI.
enum ReverseTrial {

    /// 14 days. Long enough to live a pay cycle inside the app, short enough
    /// that the loss lands while the habit is still forming.
    static let durationDays = 14

    static let duration: TimeInterval = TimeInterval(durationDays) * 24 * 60 * 60

    static func expiryDate(start: Date) -> Date {
        start.addingTimeInterval(duration)
    }

    static func isActive(start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        return now < expiryDate(start: start)
    }

    /// Whole days left, rounded up, clamped to 0...durationDays.
    ///
    /// The clamp is the clock guard. If the device clock runs backwards past the
    /// start date the raw remainder exceeds the trial length; we clamp rather
    /// than trust it, so the worst a rewound clock buys is the trial the user
    /// already had. A forward jump simply expires them, which is correct.
    static func daysRemaining(start: Date?, now: Date) -> Int {
        guard let start else { return 0 }

        let remaining = expiryDate(start: start).timeIntervalSince(now)
        guard remaining.isFinite else { return 0 }

        let clamped = min(max(remaining, 0), duration)
        return Int(ceil(clamped / (24 * 60 * 60)))
    }
}

/// Production store: App Group defaults, already shared with the widget.
/// A full app reinstall resets this. That is accepted for now — the abuse
/// ceiling is one extra fortnight and the alternative (Keychain, which survives
/// deletion) would silently deny the trial to a legitimate user restoring a
/// device, which is the worse failure.
final class AppGroupReverseTrialStore: ReverseTrialStore {

    static let shared = AppGroupReverseTrialStore()

    private let startKey = "reverseTrialStartDate"
    private let shownKey = "reverseTrialEndPaywallShown"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .appGroup) {
        self.defaults = defaults
    }

    var reverseTrialStartDate: Date? {
        get { defaults.object(forKey: startKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: startKey)
            } else {
                defaults.removeObject(forKey: startKey)
            }
        }
    }

    var hasShownTrialEndPaywall: Bool {
        get { defaults.bool(forKey: shownKey) }
        set { defaults.set(newValue, forKey: shownKey) }
    }
}
