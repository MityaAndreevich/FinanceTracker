//
//  PaywallPriceCopy.swift
//  FinanceTracker
//
//  Every number the paywall says about the annual plan is DERIVED from the live
//  StoreKit products. Nothing about a price is hardcoded — not the per-month
//  figure, not the savings percent, not the currency symbol.
//
//  The hardcoded strings this replaces ("$2.92/month", "Save 42%") were correct
//  in exactly one storefront. Everywhere else they lied: a Brazilian user is
//  billed in BRL, a German in EUR, and both were shown a dollar figure that had
//  no relationship to what Apple would actually charge them — the pt-BR string
//  went as far as spelling it "US$ 2,92". Same class of bug as the free trial we
//  promised but no longer sold (0f67862): the paywall must only claim what the
//  store will honour, so it now asks the store.
//
//  Same rule as IntroductoryOffer: when the facts are missing, the claim
//  disappears. A hidden line is always better than a confident wrong number.
//

import Foundation
import StoreKit

enum PaywallPriceCopy {

    /// The annual plan's price expressed per month, formatted in the storefront's
    /// own currency and locale — "$2.92", "2,92 €", "R$ 18,99".
    ///
    /// The caller passes the product's own `priceFormatStyle`, so the currency,
    /// symbol placement, decimal separator and fraction-digit count are all Apple's
    /// answer for that storefront rather than ours. Nil when there is no positive
    /// price to divide, which is the honest answer when StoreKit hasn't loaded.
    static func perMonthText(annualPrice: Decimal,
                             format: Decimal.FormatStyle.Currency) -> String? {
        guard annualPrice > 0 else { return nil }
        return (annualPrice / 12).formatted(format)
    }

    /// How much cheaper a year on the annual plan is than twelve monthly renewals,
    /// as a whole percent: 1 − (annual ÷ (monthly × 12)).
    ///
    /// Nil — meaning "say nothing" — whenever a saving cannot be PROVEN:
    ///   • the monthly product didn't load, so there is nothing to compare against;
    ///   • either price is non-positive;
    ///   • the annual plan is not actually cheaper, so there is no saving to boast
    ///     about and inventing one would be a straight lie to the user.
    ///
    /// Prices are compared as `Decimal` throughout. Binary floating point would
    /// round money, and this number ends up on screen as a promise.
    static func savingsPercent(annualPrice: Decimal, monthlyPrice: Decimal?) -> Int? {
        guard let monthlyPrice, monthlyPrice > 0, annualPrice > 0 else { return nil }

        let yearOfMonthlyRenewals = monthlyPrice * 12
        guard annualPrice < yearOfMonthlyRenewals else { return nil }

        let fraction = (yearOfMonthlyRenewals - annualPrice) / yearOfMonthlyRenewals * 100

        var rounded = Decimal()
        var input = fraction
        NSDecimalRound(&rounded, &input, 0, .plain)

        let percent = (rounded as NSDecimalNumber).intValue
        return percent > 0 ? percent : nil
    }
}

// MARK: - StoreKit bridge

extension Product {

    /// This product's price divided across twelve months, in its own currency.
    /// Only meaningful on the annual subscription.
    var perMonthText: String? {
        PaywallPriceCopy.perMonthText(annualPrice: price, format: priceFormatStyle)
    }
}
