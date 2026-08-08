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

    /// THE GATE. `AccessLogic.isPremium` is this, ORed with a paid entitlement.
    ///
    /// **There is no clock clamp here, and that is a real gap — see the note on
    /// `daysRemaining` below.** Raw `now` against raw expiry.
    static func isActive(start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        return now < expiryDate(start: start)
    }

    /// Whole days left, rounded up, clamped to 0...durationDays.
    ///
    /// ────────────────────────────────────────────────────────────────────────
    /// CORRECTED 2026-08-08. This comment previously read: *"the worst a rewound
    /// clock buys is the trial the user already had."* **That is true of the
    /// number on this screen and FALSE of the entitlement**, and stating it here
    /// without that distinction described a protection the product does not have.
    ///
    /// WHERE THE CLAMP LIVES:      `daysRemaining` — the DISPLAYED day count.
    /// WHERE IT DOES NOT:          `isActive` — the gate, and therefore
    ///                             `AccessLogic.isPremium`, which is what every
    ///                             paid capability actually consults.
    ///
    /// So: set the device clock back and premium is restored for as long as the
    /// clock stays back. Unbounded — not one extra fortnight. Meanwhile the badge
    /// keeps reporting at most 14 days, because that is the clamped path. The two
    /// disagree, and the entitlement is the one that matters.
    ///
    /// AND THE CLAMP WOULD NOT HAVE HELPED ANYWAY. Worth stating, because the
    /// obvious repair is wrong and was tried: adding `max(now, start)` to
    /// `isActive` changes nothing. It only forbids `now` PRECEDING the start; a
    /// clock rewound to a date *inside* the window still reports active.
    /// (Demonstrated 2026-08-08 — the pin in `AccessManagerTests` passes with the
    /// clamp applied.) The same is true of the clamp here: it caps the DISPLAYED
    /// number at 14, it does not stop the window being re-entered.
    ///
    /// A real fix needs a persisted monotonic high-water mark of observed time —
    /// "the latest date this install has ever seen" — and expiry compared against
    /// `max(now, watermark)`. That is a stored value with its own migration,
    /// sync and reinstall semantics, not a one-liner.
    ///
    /// NOT FIXED, and that is a decision rather than an oversight: rolling a
    /// device clock back is self-punishing (it breaks every other app, and iOS
    /// re-syncs time), and every locally-stored trial has this property. The
    /// reason it is written down now instead of later is that 1.0.4 hangs iCloud
    /// sync on this same gate — a bad free/premium answer stops being a local
    /// display question the moment it decides whether data leaves the device.
    ///
    /// Recorded rather than silently corrected because this project has now been
    /// misled three times by a comment that outlived the code beneath it (the
    /// `.deny` delete rule, the `@Attribute(.unique)` claim in CSV import, and
    /// the "Vela" privacy policy). A comment claiming a guarantee is worse than
    /// no comment at all.
    /// ────────────────────────────────────────────────────────────────────────
    ///
    /// A forward jump simply expires the trial, which is correct on both paths.
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
