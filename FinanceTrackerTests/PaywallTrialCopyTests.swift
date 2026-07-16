//
//  PaywallTrialCopyTests.swift
//  FinanceTrackerTests
//
//  The paywall must never promise a StoreKit free trial we don't offer. As of
//  v1.0.2 the annual product carries NO introductory offer — the 14-day reverse
//  trial is the trial — so in production every trial string must stay unrendered.
//
//  These tests pin both halves of that:
//    1. The gate: no free intro offer from StoreKit → no trial copy at all.
//    2. The copy: the strings that DO render in that state say nothing about a
//       free trial, in all five shipping locales.
//

import Testing
import Foundation
@testable import FinanceTracker

// MARK: - The gate

@Suite("A trial is claimed only when StoreKit actually reports one")
struct FreeTrialGateTests {

    /// The production case. If this ever stops returning nil, the paywall starts
    /// promising a trial Apple will not honour.
    @Test("No introductory offer means no trial copy")
    func noOfferMeansNoTrialCopy() {
        #expect(PaywallTrialCopy.freeTrialPeriodText(for: nil) == nil)
    }

    @Test("A PAID introductory price is not a free trial and is never called one")
    func paidIntroOfferIsNotAFreeTrial() {
        let paid = IntroductoryOffer(unit: .month, value: 1, isFree: false)
        #expect(PaywallTrialCopy.freeTrialPeriodText(for: paid) == nil)
    }

    @Test("A zero-length offer is not describable and claims nothing")
    func zeroLengthOfferClaimsNothing() {
        let empty = IntroductoryOffer(unit: .day, value: 0, isFree: true)
        #expect(PaywallTrialCopy.freeTrialPeriodText(for: empty) == nil)
    }

    /// Should Apple ever hand us a real free offer again, the length is read off
    /// the offer itself — never hardcoded, so the copy cannot go stale.
    @Test("A real free offer is described with ITS length, not a baked-in one")
    func freeOfferIsDescribedFromTheOffer() throws {
        let thirtyDays = IntroductoryOffer(unit: .day, value: 30, isFree: true)
        let text = try #require(PaywallTrialCopy.freeTrialPeriodText(for: thirtyDays,
                                                                    locale: Locale(identifier: "en_US")))
        #expect(text.contains("30"))
        #expect(text.localizedCaseInsensitiveContains("day"))

        let oneWeek = IntroductoryOffer(unit: .week, value: 1, isFree: true)
        let weekText = try #require(PaywallTrialCopy.freeTrialPeriodText(for: oneWeek,
                                                                        locale: Locale(identifier: "en_US")))
        #expect(weekText.localizedCaseInsensitiveContains("week"))
    }

    /// A 30-day offer must never render as "4 weeks". They are not the same
    /// promise — 4 weeks is 28 days — and DateComponentsFormatter will happily
    /// normalize across units if you let it choose. Apple's unit is the contract.
    @Test("A 30-day offer is never re-normalized into weeks")
    func thirtyDaysIsNotFourWeeks() throws {
        let offer = IntroductoryOffer(unit: .day, value: 30, isFree: true)
        let text = try #require(PaywallTrialCopy.freeTrialPeriodText(for: offer,
                                                                    locale: Locale(identifier: "en_US")))
        #expect(text.localizedCaseInsensitiveContains("week") == false, "got \"\(text)\"")
        #expect(text.contains("30"))
    }

    @Test("The period is localized, so the trial length is never English-only")
    func periodIsLocalized() throws {
        let offer = IntroductoryOffer(unit: .day, value: 30, isFree: true)
        let ru = try #require(PaywallTrialCopy.freeTrialPeriodText(for: offer,
                                                                   locale: Locale(identifier: "ru_RU")))
        #expect(ru.contains("30"))
        #expect(ru.localizedCaseInsensitiveContains("day") == false)
    }
}

// MARK: - The copy

@Suite("Shipping copy makes no free-trial claim, in every locale")
struct PaywallCopyHonestyTests {

    private static let locales = ["en", "ru", "es", "pt-BR", "uk"]

    private static func strings(_ localization: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable",
                                          ofType: "strings",
                                          inDirectory: nil,
                                          forLocalization: localization),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return nil
        }
        return dict
    }

    /// Every word each locale uses for a free trial. If one of these shows up in
    /// the copy that renders WITHOUT a StoreKit offer, we are lying to the user.
    private static let trialWords = [
        "free trial", "days free", "trial",              // en
        "бесплатн", "пробн",                              // ru / uk
        "gratis", "gratuita", "gratuito", "prueba",       // es
        "grátis", "teste",                                // pt-BR
        "безкоштовн",
    ]

    /// The keys the yearly card renders when the product has no intro offer.
    /// These are exactly the strings a user sees in production today.
    private static let noOfferKeys = [
        "paywall.plan.yearly.subtitle",
        "paywall.cta.yearly",
    ]

    @Test("The keys shown without an intro offer never mention a free trial")
    func noOfferCopyIsSilentAboutTrials() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            for key in Self.noOfferKeys {
                let value = try #require(dict[key], "\(locale) is missing \(key)")
                for word in Self.trialWords {
                    #expect(value.localizedCaseInsensitiveContains(word) == false,
                            "\(locale)/\(key) still promises a trial: \"\(value)\"")
                }
            }
        }
    }

    /// The old copy hardcoded "$34.99" and "30 days" into five languages. Price
    /// and period now come from StoreKit, so neither may appear in any string.
    @Test("No locale hardcodes a price or a 30-day period into paywall copy")
    func noHardcodedPriceOrPeriod() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            for (key, value) in dict where key.hasPrefix("paywall.") {
                #expect(value.contains("34.99") == false,
                        "\(locale)/\(key) hardcodes the annual price: \"\(value)\"")
                #expect(value.contains("34,99") == false,
                        "\(locale)/\(key) hardcodes the annual price: \"\(value)\"")
                #expect(value.contains("30") == false,
                        "\(locale)/\(key) hardcodes the removed 30-day trial: \"\(value)\"")
            }
        }
    }

    /// The removed keys must not come back: they are the ones that baked the
    /// trial length and price into the sentence.
    @Test("The hardcoded trial-disclosure keys are gone for good")
    func staleTrialKeysAreGone() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            #expect(dict["paywall.trial.disclosure"] == nil, "\(locale) resurrected paywall.trial.disclosure")
            #expect(dict["paywall.trial.modal.body"] == nil, "\(locale) resurrected paywall.trial.modal.body")
        }
    }

    /// The offer-driven strings must keep BOTH positional placeholders, or a
    /// future real offer would render a sentence missing its length or its price.
    @Test("Offer-driven strings keep both positional placeholders")
    func offerFormatsKeepTheirPlaceholders() throws {
        let formatKeys = [
            "paywall.plan.yearly.subtitle.trial.format",
            "paywall.trial.disclosure.format",
            "paywall.trial.modal.body.format",
        ]
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            for key in formatKeys {
                let value = try #require(dict[key], "\(locale) is missing \(key)")
                #expect(value.contains("%1$@"), "\(locale)/\(key) lost the period placeholder")
                #expect(value.contains("%2$@"), "\(locale)/\(key) lost the price placeholder")
            }
        }
    }
}

// MARK: - Reverse-trial ("preview") copy

@Suite("The reverse trial reads as a preview, not a subscription trial")
struct ReverseTrialCopyTests {

    private static let locales = ["en", "ru", "es", "pt-BR", "uk"]

    private static func strings(_ localization: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable",
                                          ofType: "strings",
                                          inDirectory: nil,
                                          forLocalization: localization),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return nil
        }
        return dict
    }

    /// A duration no real configuration would use: if it shows up in the rendered
    /// string, the number genuinely came through the format arg — not from a
    /// hand-typed "14" that will lie the day `ReverseTrial.durationDays` moves
    /// (v1.0.2 review, item 3 — the drift class the comparison table already
    /// kills for the caps).
    private static let sentinelDays = 99

    @Test("The active-preview line derives BOTH numbers: duration and days left")
    func activePreviewRendersWithDurationAndDaysRemaining() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            let value = try #require(dict["paywall.preview_active.format"],
                                     "\(locale) is missing paywall.preview_active.format")
            let rendered = String(format: value, Self.sentinelDays, 7)
            #expect(rendered.contains("\(Self.sentinelDays)"),
                    "\(locale) preview line does not derive its duration from the constant")
            #expect(rendered.contains("7"), "\(locale) preview line lost its days-left count")
        }
    }

    @Test("The preview-ended notice exists in every locale and derives its duration")
    func previewEndedRenders() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            let title = try #require(dict["paywall.trial_ended.title"], "\(locale) missing trial_ended.title")
            let body = try #require(dict["paywall.trial_ended.body"], "\(locale) missing trial_ended.body")
            #expect(String(format: title, Self.sentinelDays).contains("\(Self.sentinelDays)"),
                    "\(locale) trial-ended title does not derive its duration from the constant")
            #expect(body.isEmpty == false)
        }
    }

    /// The regression that reintroduces the bug is a translator (or a merge)
    /// replacing the placeholder with a literal number again. Any digit left in
    /// the raw format string once %-placeholders are stripped is that regression.
    @Test("No locale hand-types a number into the trial-duration copy")
    func noHardcodedNumbersSurvive() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            for key in ["paywall.preview_active.format", "paywall.trial_ended.title"] {
                let value = try #require(dict[key], "\(locale) is missing \(key)")
                let withoutPlaceholders = value.replacingOccurrences(
                    of: #"%\d+\$[a-z@]|%[a-z@]"#, with: "", options: .regularExpression)
                let hasHandTypedNumber = withoutPlaceholders.contains { $0.isNumber }
                #expect(!hasHandTypedNumber,
                        "\(locale) \(key) contains a hand-typed number — the duration must be a format arg")
            }
        }
    }

    @Test("The Settings status line counts down the preview, not a subscription trial")
    func settingsStatusLineCountsDown() throws {
        for locale in Self.locales {
            let dict = try #require(Self.strings(locale), "Missing locale: \(locale)")
            let value = try #require(dict["premium.status.trial.format"],
                                     "\(locale) missing premium.status.trial.format")
            #expect(value.contains("%d"))
            #expect(String(format: value, 3).contains("3"))
        }
    }
}
