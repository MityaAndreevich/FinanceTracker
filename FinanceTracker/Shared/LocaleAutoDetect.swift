//
//  LocaleAutoDetect.swift
//  FinanceTracker
//
//  Silent first-run locale detection (Brief 28 Part E). Replaces the language +
//  currency picker wall: we detect the device language and region currency and apply
//  them without blocking the user with setup before value. Both remain changeable in
//  Settings. Logic extracted verbatim from the retired OnboardingView so behavior is
//  unchanged — only the moment it runs (silent, at launch) differs.
//

import Foundation

enum LocaleAutoDetect {

    /// Best-guess (language, currency) for a genuine first run. Never blocks; an
    /// ambiguous or unsupported device locale falls back to English + a
    /// language-based currency default rather than prompting. Inputs are injectable
    /// so the mapping is unit-testable independent of the running device's locale.
    static func resolve(
        preferred: [String] = Locale.preferredLanguages,
        regionCurrency: String? = Locale.current.currency?.identifier
    ) -> (language: SupportedLanguage, currency: SupportedCurrency) {
        let language = detectDeviceLanguage(preferred: preferred)
        // `.system` (unsupported device language) still needs a concrete currency
        // guess; treat it as English for the by-language fallback branch.
        let currency = defaultCurrency(for: language == .system ? .en : language,
                                       regionCurrency: regionCurrency)
        return (language, currency)
    }

    /// Maps the device's preferred language to one of the shipped locales, or
    /// `.system` when unsupported (handled by callers as English).
    static func detectDeviceLanguage(preferred: [String] = Locale.preferredLanguages) -> SupportedLanguage {
        guard let first = preferred.first else { return .system }
        switch Locale(identifier: first).language.languageCode?.identifier {
        case "en": return .en
        case "ru": return .ru
        case "es": return .es
        case "pt": return .pt
        case "uk": return .uk
        default:   return .system
        }
    }

    /// Prefers the device region's actual currency when we support it, else a
    /// language-based default. Never returns nil.
    static func defaultCurrency(
        for language: SupportedLanguage,
        regionCurrency: String? = Locale.current.currency?.identifier
    ) -> SupportedCurrency {
        if let regionCode = regionCurrency,
           let regionCurrency = SupportedCurrency(rawValue: regionCode) {
            return regionCurrency
        }
        switch language {
        case .es: return .mxn
        case .pt: return .brl
        case .ru: return .rub
        case .uk: return .uah
        case .en, .system: return .usd
        }
    }

    /// Applies the detected defaults on a genuine first run: writes appLanguageCode /
    /// defaultCurrencyCode and mirrors the language into AppleLanguages so
    /// String(localized:) resolves the right .lproj on next launch. Idempotent-safe:
    /// only writes when the keys are still at their unset defaults, so it never
    /// clobbers a choice the user later makes in Settings.
    static func applyDetectedDefaultsIfUnset(_ defaults: UserDefaults = .standard) {
        let langUnset = (defaults.string(forKey: "appLanguageCode") ?? "system") == "system"
        let currencyUnset = defaults.string(forKey: "defaultCurrencyCode") == nil

        let (language, currency) = resolve()

        if langUnset {
            defaults.set(language.rawValue, forKey: "appLanguageCode")
            applyAppleLanguagesOverride(for: language.rawValue, defaults: defaults)
        }
        if currencyUnset {
            defaults.set(currency.code, forKey: "defaultCurrencyCode")
        }
    }

    /// Mirrors the resolved language into `AppleLanguages`. `.system` hands control
    /// back to iOS by removing the override. Mirrors the retired OnboardingView.
    static func applyAppleLanguagesOverride(for code: String, defaults: UserDefaults = .standard) {
        let appleLangCode: String?
        switch code {
        case "system", "": appleLangCode = nil
        case "es":         appleLangCode = "es-MX"   // LATAM target market
        case "pt":         appleLangCode = "pt-BR"   // resources live in pt-BR.lproj
        default:           appleLangCode = code       // en, ru, uk
        }
        if let appleLangCode {
            defaults.set([appleLangCode], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
