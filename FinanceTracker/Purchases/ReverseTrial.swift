//
//  ReverseTrial.swift
//  FinanceTracker
//
//  The reverse trial: on first launch of 1.0.2 the user silently gets 14 days of
//  FULL premium with no card and no subscription. When it lapses they fall back
//  to the free tier (keeping every byte they created) and the paywall makes its
//  case against a concrete sense of loss.
//
//  This is NOT Apple's StoreKit introductory offer, and as of 1.0.2 there is no
//  longer one to confuse it with: the 30-day StoreKit trial was removed in App
//  Store Connect, because stacking it on top of these 14 days handed out 44 free
//  days and blunted the very loss this trial exists to create. The reverse trial
//  is ours, is local, needs no card, and grants no entitlement.
//
//  In user-facing copy this is a "preview", never a "trial" — the word trial is
//  reserved for a StoreKit offer, and we only say it when StoreKit reports one
//  (see IntroductoryOffer.swift). Never conflate them, never double-grant.
//

import Foundation

/// Persistence seam for the trial. Injected so the state machine can be tested
/// without touching real user defaults.
protocol ReverseTrialStore: AnyObject {
    var reverseTrialStartDate: Date? { get set }

    /// The latest date this install has ever observed — a monotonic high-water mark
    /// of time. Advanced on launch and foreground only; never moves backwards.
    /// `nil` before the first observation.
    ///
    /// Lives in the SAME store as `reverseTrialStartDate` (App Group defaults), not
    /// in the Keychain. Two mechanisms that can disagree about the same fact are
    /// worse than one imperfect mechanism: a Keychain watermark would survive a
    /// delete that clears the start date, and the pair would then describe a trial
    /// that never began. Consistency beats marginal robustness here.
    var observedTimeWatermark: Date? { get set }

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

    /// The time this install is willing to believe it is: never earlier than the
    /// latest date it has ever seen.
    ///
    /// STRICT `max`, with no tolerance window, and that is deliberate. A device
    /// crossing a time zone or taking a backward NTP correction of a few seconds
    /// simply fails to advance the watermark, which is harmless. A tolerance window
    /// would be a second parameter to get wrong, guarding against nothing.
    static func effectiveNow(now: Date, watermark: Date?) -> Date {
        guard let watermark else { return now }
        return max(now, watermark)
    }

    /// THE GATE. `AccessLogic.isPremium` is this, ORed with a paid entitlement.
    ///
    /// ## The clock-rewind hole, and what actually closed it
    ///
    /// This used to compare RAW `now` against expiry, so setting the device clock
    /// back restored premium for as long as the clock stayed back — unbounded, not
    /// one extra fortnight. Meanwhile the badge kept reporting at most 14 days,
    /// because `daysRemaining` clamped and this did not. The two disagreed, and the
    /// entitlement was the one that mattered.
    ///
    /// **The obvious repair does not work and was tried.** Adding `max(now, start)`
    /// only forbids `now` PRECEDING the start; a clock rewound to a date *inside*
    /// the window still reports active. Demonstrated 2026-08-08 — the pin in
    /// `AccessManagerTests` passed with that clamp applied.
    ///
    /// What closes it is a persisted monotonic high-water mark of observed time,
    /// which is what `watermark` is. Expiry is compared against `max(now,
    /// watermark)`, so winding the clock back to any point the install has already
    /// seen past changes nothing.
    ///
    /// **A reinstall still resets everything**, and that is unchanged and accepted:
    /// the abuse ceiling stays one extra fortnight, exactly as it was for
    /// `reverseTrialStartDate`. The alternative (Keychain, which survives deletion)
    /// would silently deny the trial to a legitimate user restoring a device, which
    /// is the worse failure.
    ///
    /// Fixed before sync rather than after, because `AppCapability.iCloudSync` is
    /// `requiresPremium` — the moment sync ships, a wrong free/premium answer stops
    /// being a local display question and starts deciding whether data leaves the
    /// device.
    static func isActive(start: Date?, now: Date, watermark: Date? = nil) -> Bool {
        guard let start else { return false }
        return effectiveNow(now: now, watermark: watermark) < expiryDate(start: start)
    }

    /// Whole days left, rounded up, clamped to 0...durationDays.
    ///
    /// Takes the SAME `watermark` as `isActive`, and that is the point. Between
    /// 2026-08-08 and 2026-08-13 the clamp lived only here — on the DISPLAYED day
    /// count — while the gate compared raw `now`. The badge said at most 14 days
    /// while the entitlement was unbounded, and the entitlement is the one that
    /// matters. Both now read time through `effectiveNow`, so they cannot disagree.
    ///
    /// A forward jump simply expires the trial, which is correct on both paths.
    static func daysRemaining(start: Date?, now: Date, watermark: Date? = nil) -> Int {
        guard let start else { return 0 }

        let remaining = expiryDate(start: start)
            .timeIntervalSince(effectiveNow(now: now, watermark: watermark))
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
    private let watermarkKey = "observedTimeWatermark"
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

    /// Same App Group defaults as the start date, deliberately — see the protocol.
    var observedTimeWatermark: Date? {
        get { defaults.object(forKey: watermarkKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: watermarkKey)
            } else {
                defaults.removeObject(forKey: watermarkKey)
            }
        }
    }
}
