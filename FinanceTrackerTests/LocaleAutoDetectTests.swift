//
//  LocaleAutoDetectTests.swift
//  FinanceTrackerTests
//
//  Silent first-run locale detection mapping (Brief 28 Part E). Inputs are injected
//  so the mapping is verified independent of the test host's actual device locale.
//

import Testing
@testable import FinanceTracker

@Suite("LocaleAutoDetect")
struct LocaleAutoDetectTests {

    // MARK: - Language mapping

    @Test func language_supportedCodes_map() {
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["en-US"]) == .en)
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["ru-RU"]) == .ru)
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["es-ES"]) == .es)
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["pt-BR"]) == .pt)
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["uk-UA"]) == .uk)
    }

    @Test func language_unsupported_isSystem() {
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: ["fr-FR"]) == .system)
    }

    @Test func language_empty_isSystem() {
        #expect(LocaleAutoDetect.detectDeviceLanguage(preferred: []) == .system)
    }

    // MARK: - Currency mapping

    @Test func currency_regionWins_whenSupported() {
        // English speaker on a EUR device → EUR, not the USD language default.
        #expect(LocaleAutoDetect.defaultCurrency(for: .en, regionCurrency: "EUR") == .eur)
    }

    @Test func currency_unsupportedRegion_fallsBackToLanguage() {
        #expect(LocaleAutoDetect.defaultCurrency(for: .es, regionCurrency: "XYZ") == .mxn)
        #expect(LocaleAutoDetect.defaultCurrency(for: .pt, regionCurrency: nil) == .brl)
        #expect(LocaleAutoDetect.defaultCurrency(for: .ru, regionCurrency: nil) == .rub)
        #expect(LocaleAutoDetect.defaultCurrency(for: .uk, regionCurrency: nil) == .uah)
        #expect(LocaleAutoDetect.defaultCurrency(for: .en, regionCurrency: nil) == .usd)
    }

    // MARK: - resolve()

    @Test func resolve_ptBrDevice_noRegion_isPtBrl() {
        let r = LocaleAutoDetect.resolve(preferred: ["pt-BR"], regionCurrency: nil)
        #expect(r.language == .pt)
        #expect(r.currency == .brl)
    }

    @Test func resolve_unsupportedLanguage_defaultsSilently() {
        // Ambiguous/unsupported device → English + region (or USD) — never a crash.
        let r = LocaleAutoDetect.resolve(preferred: ["fr-FR"], regionCurrency: nil)
        #expect(r.language == .system)   // callers treat .system as English
        #expect(r.currency == .usd)
    }
}
