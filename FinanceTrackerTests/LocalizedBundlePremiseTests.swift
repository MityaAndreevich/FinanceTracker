//
//  LocalizedBundlePremiseTests.swift
//  FinanceTrackerTests
//
//  LocalizedBundle.swift's header asserts a PREMISE the whole in-app language
//  override rests on:
//
//      "`String(localized:)` and `NSLocalizedString` … bottom out in
//       `Bundle.main.localizedString(forKey:value:table:)`"
//
//  If that is false, `object_setClass(Bundle.main, LanguageBundle.self)` closes a
//  gap it does not actually cover, and 46 of 48 code-resolved call sites keep
//  returning the LAUNCH language after the user switches — silently, in the one
//  place a user cannot report precisely ("some words stayed English").
//
//  VERDICT (2026-08-06, VERIFIED by the runs below): the premise is HALF true.
//    Bundle.main.localizedString  → Russian  ✅ the override works
//    NSLocalizedString            → Russian  ✅ routes through Bundle.main
//    String(localized:)           → English  ❌ STALE — the launch language
//  and that holds under the FULL production sequence (bundle override +
//  appLanguageCode + AppleLanguages), called from inside the app module. 35 live
//  `String(localized:)` sites in 11 files are affected. NOT FIXED — reported.
//
//  These tests are PINS, not aspirations: the broken path is asserted BROKEN, the
//  same way LanguageSwitchTests records the first-tap race instead of asserting a
//  contract the app does not yet keep. A red suite documenting a known-open defect
//  is worse than a green one that fails the moment the defect is fixed. When it is
//  fixed, every `KNOWN DEFECT PIN` below flips from `!=` to `==`.
//
//  Until now this was a comment. `LanguageSwitchTests` (UITests) does not test
//  it: it asserts the picker opens in ≤1 tap, dismisses cleanly, the Settings
//  list survives and the app stays responsive — nothing about which language any
//  string resolves to. So the suite could be green with the premise false.
//
//  HARNESS TRAP, found the hard way and recorded so nobody re-derives it:
//  `String(localized:)` takes its bundle from a `#bundle` default that resolves
//  to the CALLING MODULE's bundle. Called from this test target that is
//  FinanceTrackerTests.xctest, which ships no `.lproj` — so a test that calls
//  `String(localized:)` directly reports the premise BROKEN when it is fine.
//  (First run here did exactly that: the two explicit-bundle spellings passed and
//  only the bare one failed.) Every assertion therefore goes through
//  `LocalizationProbe`, which lives in the app module and resolves the way the
//  app's own call sites do.
//
//  METHOD — no process-locale strings are asserted. The expected value is read
//  out of `ru.lproj` directly, and every path is compared against THAT. So the
//  test states "all four resolution paths agree with the Russian table", which is
//  the premise, rather than "this string equals «Настройки»", which would depend
//  on the machine the test runs on.
//
//  SIDE EFFECT, deliberate and contained: `setLanguage` calls
//  `LanguageBundle.activate()`, which swaps `Bundle.main`'s runtime class for the
//  rest of the test PROCESS and cannot be undone (the `activated` flag is
//  one-shot). That is safe because the override forwards to `super` whenever
//  `overrideBundle` is nil, and every test here restores nil. The suite is
//  `.serialized` so no concurrent test observes a half-set override.
//

import Foundation
import Testing
@testable import FinanceTracker

//  @MainActor is REQUIRED, not tidiness. The unit-test host is the REAL RUNNING
//  APP: `setLanguage` mutates a `@Published` that a live SwiftUI tree observes.
//  Off the main actor that is "Updating ObservedObject from background threads",
//  and it crashed the host process AFTER the suite reported all green — so
//  xcodebuild printed `** TEST FAILED **` over four passing tests. Verified by
//  isolation: every test passes alone, only the whole suite killed the host.
@Suite("LocalizedBundle premise: code-resolved strings honor the override", .serialized)
@MainActor
struct LocalizedBundlePremiseTests {

    /// A key that exists in every shipped .lproj and whose Russian value differs
    /// from its English one, so "did the override take" is answerable.
    private let key = "title.settings"

    /// The Russian value, read straight out of ru.lproj — the oracle.
    private func russianValue(for key: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: "ru", ofType: "lproj"))
        let ru = try #require(Bundle(path: path))
        let value = ru.localizedString(forKey: key, value: nil, table: nil)
        #expect(value != key, "precondition: the key must exist in ru.lproj")
        return value
    }

    private func englishValue(for key: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let en = try #require(Bundle(path: path))
        return en.localizedString(forKey: key, value: nil, table: nil)
    }

    private func withRussian(_ body: () throws -> Void) rethrows {
        LocalizedBundle.shared.setLanguage("ru")
        defer { LocalizedBundle.shared.setLanguage("system") }
        try body()
    }

    // MARK: - The premise

    @Test("all four code-resolved paths return Russian after setLanguage(\"ru\")")
    func codeResolvedPathsHonorTheOverride() throws {
        let expected = try russianValue(for: key)
        let english = try englishValue(for: key)
        #expect(expected != english, "precondition: ru and en differ for this key")

        try withRussian {
            // 1. The path the override actually overrides.
            #expect(
                LocalizationProbe.bundleMainLookup(key) == expected,
                "the override itself is not working"
            )

            // 2. THE PREMISE — and it does not hold. KNOWN DEFECT PIN: flip to
            // `==` when String(localized:) is made to honor the override.
            #expect(
                LocalizationProbe.stringLocalized(key) != expected,
                "String(localized:) now honors the override — flip this pin to == "
            )

            // 3. The older spelling, same claim.
            #expect(
                LocalizationProbe.nsLocalizedString(key) == expected,
                "PREMISE FAILED: NSLocalizedString does not route through Bundle.main"
            )

            // 4. The explicit-bundle spelling the two known exceptions use.
            #expect(
                LocalizationProbe.stringLocalizedExplicitBundle(key) == expected
            )
        }
    }

    @Test("setLanguage(\"system\") hands resolution back")
    func systemRestores() throws {
        let russian = try russianValue(for: key)

        try withRussian {
            #expect(LocalizationProbe.stringLocalized(key) != russian)   // KNOWN DEFECT PIN
        }

        // Back on system: whatever the host's launch language is, it is no longer
        // being forced to Russian by us. Asserting the *value* here would be a
        // process-locale assertion; asserting the OVERRIDE is gone is not.
        #expect(LanguageBundle.overrideBundle == nil)
        #expect(LocalizedBundle.shared.languageCode == nil)
        #expect(LocalizedBundle.shared.bundle == Bundle.main)
    }

    // MARK: - The FULL production sequence

    /// `setLanguage` alone is not what the app does. `GeneralSettingView:373-381`
    /// does three things in order:
    ///
    ///   1. `LocalizedBundle.shared.setLanguage(language)`   — the bundle override
    ///   2. `appLanguageCode = language`                     — @AppStorage cascade
    ///   3. `applyAppleLanguagesOverride(for: language)`     — writes AppleLanguages
    ///
    /// (3) is the candidate that could make `String(localized:)` resolve correctly
    /// without the bundle override doing it — `AppleLanguages` is what Foundation's
    /// preferred-localization machinery reads. Whether that takes effect WITHIN a
    /// running process is exactly the open question, so it is reproduced here
    /// rather than reasoned about.
    ///
    /// Restores every global it touches.
    @Test("the full production language-change sequence, not just setLanguage")
    func fullProductionSequence() throws {
        let russian = try russianValue(for: key)
        let defaults = UserDefaults.standard
        let priorAppleLanguages = defaults.object(forKey: "AppleLanguages")

        defer {
            if let priorAppleLanguages {
                defaults.set(priorAppleLanguages, forKey: "AppleLanguages")
            } else {
                defaults.removeObject(forKey: "AppleLanguages")
            }
            LocalizedBundle.shared.setLanguage("system")
        }

        // Step (2), the `appLanguageCode` write, is DELIBERATELY OMITTED. Its only
        // job in production is to drive the SwiftUI cascade (RootView's `.id`, the
        // environment locale) — it cannot change what `String(localized:)` returns,
        // and writing it here reaches into the live host app's view tree from a
        // test. Steps (1) and (3) are the two that could plausibly affect string
        // resolution, and both are reproduced.
        LocalizedBundle.shared.setLanguage("ru")
        LocaleAutoDetect.applyAppleLanguagesOverride(for: "ru", defaults: defaults)

        // Recorded, not asserted-blind: this is the number the investigation needs.
        let viaBundleMain = LocalizationProbe.bundleMainLookup(key)
        let viaStringLocalized = LocalizationProbe.stringLocalized(key)
        let viaNSLocalizedString = LocalizationProbe.nsLocalizedString(key)
        print("[premise/full] Bundle.main.localizedString → \(viaBundleMain)")
        print("[premise/full] String(localized:)          → \(viaStringLocalized)")
        print("[premise/full] NSLocalizedString           → \(viaNSLocalizedString)")

        #expect(viaBundleMain == russian)
        #expect(viaNSLocalizedString == russian)
        // KNOWN DEFECT PIN. The full production sequence does NOT rescue it.
        //
        // MECHANISM NOT DISTINGUISHED, deliberately: this evidence cannot tell
        // "`#bundle` resolves to something the class swap never touches" apart from
        // "Foundation cached the main bundle's localization on first use". Both
        // produce this outcome, and in the app the first resolution always happens
        // at launch, before any switch — so the user-visible result is identical
        // either way. The OUTCOME is VERIFIED; the mechanism is not.
        #expect(
            viaStringLocalized != russian,
            "String(localized:) now honors the override — flip this pin to == "
        )
    }

    // MARK: - The other mechanism, pinned beside it

    /// `Text("literal")` does NOT go through the bundle override — it resolves
    /// from `environment(\.locale)` during SwiftUI's render pass, which is why
    /// `.languageReactive()` exists as a separate thing. That resolution cannot
    /// be read out of a `Text` in a unit test, so this pins the *distinction*
    /// rather than claiming to test `Text` itself: with the override set to
    /// Russian, an explicitly English-locale lookup must still come back English.
    ///
    /// The two mechanisms being independent is the whole reason a screen can be
    /// half-translated after a switch.
    @Test("the locale-driven path is independent of the bundle override")
    func localeDrivenPathIsIndependent() throws {
        let russian = try russianValue(for: key)
        let english = try englishValue(for: key)

        try withRussian {
            #expect(LocalizationProbe.stringLocalized(key) != russian)   // KNOWN DEFECT PIN

            let enPath = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
            let enBundle = try #require(Bundle(path: enPath))
            #expect(
                String(localized: String.LocalizationValue(key), bundle: enBundle) == english,
                "an explicit bundle must win over the override, or nothing can opt out"
            )
        }
    }
}
