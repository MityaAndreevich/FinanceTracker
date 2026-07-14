//
//  IntroductoryOffer.swift
//  FinanceTracker
//
//  The paywall is allowed to promise a StoreKit free trial only when StoreKit
//  itself reports one on the product. Nothing here is hardcoded: not the length
//  of the trial, not the renewal price. If the offer is removed in App Store
//  Connect, `Product.freeTrialOffer` goes nil, every trial string disappears
//  with it, and the paywall cannot be left promising something Apple won't
//  honour.
//
//  This is deliberately NOT the 14-day reverse trial (see ReverseTrial.swift).
//  That one is ours, is local, needs no card, and is described as a "preview".
//

import Foundation
import StoreKit

/// A subscription's introductory offer, reduced to the facts the paywall needs
/// to speak about it truthfully. Kept free of StoreKit types so the copy rules
/// below are pure and unit-testable without a live App Store connection.
struct IntroductoryOffer: Equatable {
    enum Unit: Equatable {
        case day, week, month, year
    }

    let unit: Unit
    let value: Int

    /// Only a *free* offer licenses the words "free trial". A paid introductory
    /// price ("first month for $0.99") is an offer, but it is not a free trial,
    /// and the paywall stays silent about it rather than overclaiming.
    let isFree: Bool
}

enum PaywallTrialCopy {

    /// A localized, correctly pluralized description of the free-trial period —
    /// "30 days", "1 month", "30 дней" — or nil when there is no free trial to
    /// describe. Nil is the expected answer in production: the annual product
    /// carries no introductory offer, because the reverse trial IS the trial.
    ///
    /// Pluralization is delegated to `DateComponentsFormatter` rather than a
    /// stringsdict so that all five locales get their own plural rules for free.
    static func freeTrialPeriodText(for offer: IntroductoryOffer?,
                                    locale: Locale = .autoupdatingCurrent) -> String? {
        guard let offer, offer.isFree, offer.value > 0 else { return nil }

        var components = DateComponents()
        let allowedUnit: NSCalendar.Unit
        switch offer.unit {
        case .day:   components.day = offer.value;         allowedUnit = .day
        case .week:  components.weekOfMonth = offer.value; allowedUnit = .weekOfMonth
        case .month: components.month = offer.value;       allowedUnit = .month
        case .year:  components.year = offer.value;        allowedUnit = .year
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        // Only the offer's own unit is allowed. Offering the formatter a choice of
        // units lets it "helpfully" re-normalize — a 30-day trial came out as
        // "4 weeks", which is a *different and shorter* promise (28 days) than the
        // one Apple would honour. The offer's unit is the contract; keep it.
        formatter.allowedUnits = [allowedUnit]
        formatter.maximumUnitCount = 1

        let text = formatter.string(from: components)
        return text?.isEmpty == false ? text : nil
    }
}

// MARK: - StoreKit bridge

extension Product {

    /// The product's free introductory offer, if it currently has one.
    ///
    /// Nil for the lifetime non-consumable (no subscription info), nil when App
    /// Store Connect defines no introductory offer, and nil when the offer is a
    /// paid intro price rather than a free trial.
    var freeTrialOffer: IntroductoryOffer? {
        guard let offer = subscription?.introductoryOffer else { return nil }

        let unit: IntroductoryOffer.Unit
        switch offer.period.unit {
        case .day:   unit = .day
        case .week:  unit = .week
        case .month: unit = .month
        case .year:  unit = .year
        @unknown default: return nil
        }

        return IntroductoryOffer(
            unit: unit,
            value: offer.period.value,
            isFree: offer.paymentMode == .freeTrial
        )
    }
}
