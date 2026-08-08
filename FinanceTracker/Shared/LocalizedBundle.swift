//
//  LocalizedBundle.swift
//  FinanceTracker
//
//  Makes an in-app language override apply *live*, without a relaunch.
//
//  ────────────────────────────────────────────────────────────────────────────
//  CORRECTED 2026-08-08. The previous header claimed that `String(localized:)`
//  and `NSLocalizedString` BOTH "bottom out in
//  `Bundle.main.localizedString(forKey:value:table:)`". That is HALF FALSE, and
//  believing it cost a full review round. Measured from inside the app module
//  under the full production sequence (bundle override + `AppleLanguages`):
//
//      Bundle.main.localizedString  →  honors the override   ✅
//      NSLocalizedString            →  honors the override   ✅
//      String(localized:)           →  STALE, launch language ❌
//
//  See `LocalizedBundlePremiseTests`, which pins each of those three as an
//  assertion rather than a comment. Do not restore the old claim.
//  ────────────────────────────────────────────────────────────────────────────
//
//  THREE resolution mechanisms exist, and they are independent. A screen can be
//  half-translated after a switch precisely because of that:
//
//   1. SwiftUI `Text("key")` — resolves from `environment(\.locale)` during the
//      render pass. Refreshes when the subtree rebuilds. Not our business here;
//      that is what `.languageReactive()` is for.
//
//   2. `NSLocalizedString` — routes through `Bundle.main`, so the
//      `object_setClass(Bundle.main, LanguageBundle.self)` swap below DOES
//      redirect it. This is the mechanism that works as originally designed.
//
//   3. `String(localized:)` — takes its bundle from a `#bundle` default that the
//      class swap never reaches, so it keeps returning the LAUNCH language for
//      the rest of the process. The class swap does not help it, and neither
//      does rebuilding the view: re-resolving a stale lookup yields the same
//      stale value.
//
//      MECHANISM NOT DISTINGUISHED (and deliberately so): the evidence cannot
//      separate "`#bundle` resolves to something the swap never touches" from
//      "Foundation cached the main bundle's localization on first use". Both
//      produce this outcome and in the app the first resolution always happens
//      at launch, before any switch, so the user-visible result is identical.
//      The OUTCOME is verified; the mechanism is not.
//
//  THE RULE THAT FOLLOWS, and it is enforced by a test:
//
//      Every `String(localized:)` in shipping code passes an explicit
//      `bundle:` — `LocalizedBundle.shared.bundle`, or `localizedBundle.bundle`
//      in a view that already observes it.
//
//  `LocalizedCallSiteGuardTests` fails the build's test run if a new bare call
//  site appears. `FrozenArtifactLanguageTests` covers the three producers where
//  the staleness would outlive the session rather than merely look wrong until
//  the next cold launch: notification bodies (frozen at schedule time) and
//  exported PDFs (kept, or forwarded to someone else).
//
//  The shared `LocalizedBundle` also exposes the active code as an `@Published`
//  value so a view tree can re-render on change without the fragile `.id()`
//  recreation that previously bounced the language picker. Re-rendering is
//  mechanism 1; it is orthogonal to which bundle mechanisms 2 and 3 read from.
//

import Foundation
import Combine

/// Single source of truth for the in-app language override. Drives both the
/// `LanguageBundle` redirection and (via `@Published`) SwiftUI re-render.
final class LocalizedBundle: ObservableObject {
    static let shared = LocalizedBundle()

    /// Active language code ("en", "ru", "es", "pt") or nil/"system" for system.
    @Published private(set) var languageCode: String?

    private init() {}

    /// The bundle that code-resolved string lookups should use for the active
    /// language. When an explicit override is set this is the chosen language's
    /// `.lproj` bundle; otherwise it's `Bundle.main` (system launch language).
    ///
    /// Pass this as the `bundle:` argument of EVERY `String(localized:)` in
    /// shipping code — that is a rule, not a suggestion, and
    /// `LocalizedCallSiteGuardTests` enforces it. Also use it for
    /// `bundle.localizedString(forKey:value:table:)` at call sites where
    /// SwiftUI's `Text(LocalizedStringKey:)` isn't available.
    ///
    /// Falls back to `Bundle.main` when no override is set, which is correct:
    /// with no override the launch language IS the chosen language.
    var bundle: Bundle { LanguageBundle.overrideBundle ?? .main }

    /// Points code-resolved string lookups at `code`'s `.lproj`. Pass "system"
    /// (or nil) to hand resolution back to the OS launch language.
    func setLanguage(_ code: String?) {
        LanguageBundle.activate()
        LanguageBundle.overrideBundle = LocalizedBundle.lprojBundle(for: code)
        let normalized = LocalizedBundle.lprojName(for: code) == nil ? nil : code
        if languageCode != normalized { languageCode = normalized }
    }

    private static func lprojBundle(for code: String?) -> Bundle? {
        guard let name = lprojName(for: code),
              let path = Bundle.main.path(forResource: name, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return bundle
    }

    /// Maps the app's language code to its `.lproj` folder name, or nil for system.
    static func lprojName(for code: String?) -> String? {
        switch code {
        case nil, "", "system": return nil
        case "pt": return "pt-BR"   // resources live in pt-BR.lproj
        case "es": return "es"
        default:   return code      // en, ru
        }
    }
}

/// Resolves strings the way the app's own 48 code-resolved call sites do —
/// **from inside the app module**. That distinction is the whole point.
///
/// `String(localized:)` takes its bundle from a `#bundle` default that resolves
/// to the *calling module's* bundle. Called from FinanceTrackerTests.xctest that
/// is the test bundle, which ships no `.lproj`, so a test that calls
/// `String(localized:)` directly measures the harness rather than the app and
/// will report the premise broken when it is not. Every premise assertion goes
/// through here instead. See `LocalizedBundlePremiseTests`.
enum LocalizationProbe {
    static func stringLocalized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func nsLocalizedString(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func stringLocalizedExplicitBundle(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: LocalizedBundle.shared.bundle)
    }

    static func bundleMainLookup(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

/// `Bundle.main`'s runtime class becomes this once `activate()` runs, so every
/// `NSLocalizedString` / `String(localized:)` call routes through `overrideBundle`
/// when an explicit language is set, and falls back to the system bundle for
/// "System". Only static storage is added — no instance properties — so
/// `object_setClass` on the existing `Bundle.main` instance is size-safe.
final class LanguageBundle: Bundle, @unchecked Sendable {
    static var overrideBundle: Bundle?
    private static var activated = false

    static func activate() {
        guard !activated else { return }
        activated = true
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageBundle.overrideBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
