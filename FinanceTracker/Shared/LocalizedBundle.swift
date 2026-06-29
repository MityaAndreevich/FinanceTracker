//
//  LocalizedBundle.swift
//  FinanceTracker
//
//  Makes an in-app language override apply *live*, without a relaunch.
//
//  SwiftUI `Text("key")` already refreshes from `environment(\.locale)`. The gap
//  is code-resolved strings — `String(localized:)` and `NSLocalizedString` —
//  which bottom out in `Bundle.main.localizedString(forKey:value:table:)` and
//  otherwise honor only the launch language (the `AppleLanguages` default).
//
//  We close that gap by swapping `Bundle.main`'s class (once) to `LanguageBundle`,
//  whose override forwards string lookups to the chosen language's `.lproj`. The
//  shared `LocalizedBundle` exposes the active code as an `@Published` value so a
//  view tree can re-render on change without the fragile `.id()` recreation that
//  previously bounced the language picker.
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
    /// Use this for `bundle.localizedString(forKey:value:table:)` at call-sites
    /// where SwiftUI's `Text(LocalizedStringKey:)` isn't available and a plain
    /// `NSLocalizedString` would otherwise read only the launch language — e.g.
    /// the Quick Entry preview chip's category name (Bug 1).
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
