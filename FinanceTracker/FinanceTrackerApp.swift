//
//  FinanceTrackerApp.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @AppStorage("firstLaunchDate") private var firstLaunchInterval: Double = 0
    // Mirror default currency to App Group defaults so AppIntents can read it.
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    // Observing the shared bundle re-renders the tree when the in-app language
    // changes, so code-resolved strings (String(localized:) / NSLocalizedString)
    // refresh live alongside Text("key") — no relaunch, no `.id()` recreation.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    init() {
        // Must run before SharedModelContainer.shared is first accessed so the
        // lazily-created App Group store is seeded with existing user data.
        SharedModelContainer.migrateLegacyStoreIfNeeded()

        // Apply the stored language override to Bundle.main *before* the first
        // frame, so code-resolved strings match the chosen language immediately.
        let stored = UserDefaults.standard.string(forKey: "appLanguageCode") ?? "system"
        LocalizedBundle.shared.setLanguage(stored)
    }

    // MARK: - Locale + Layout

    private var appLocale: Locale {
        switch appLanguageCode {
        case "system", "": return .autoupdatingCurrent
        case "pt": return Locale(identifier: "pt_BR")  // resources live in pt-BR.lproj
        case "es": return Locale(identifier: "es_MX")  // LATAM target market
        default: return Locale(identifier: appLanguageCode)
        }
    }

    private var overrideLayoutDirection: LayoutDirection? {
        // System → не трогаем, iOS сама выберет LTR/RTL
        guard appLanguageCode != "system" else { return nil }

        // Если по какой-то причине код странный — лучше LTR, чем падение/undefined
        let direction = Locale.Language(identifier: appLanguageCode).characterDirection
        return direction == .rightToLeft ? .rightToLeft : .leftToRight
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, appLocale)
                .environmentObject(localizedBundle)
                .applyLayoutDirection(overrideLayoutDirection)
                // NOTE: deliberately no `.id(appLanguageCode)` here. Re-creating the
                // whole view tree on language change dismissed any in-flight sheet,
                // which caused the Language picker to "bounce back" on the first try.
                // `environment(\.locale)` already refreshes Text("key") strings; the
                // AppleLanguages override (set in GeneralSettingsView) handles the
                // remaining String(localized:) calls on next launch.
                .task {
                    PurchaseManager.shared.start()
                    if UserDefaults.standard.object(forKey: "firstLaunchDate") == nil {
                        firstLaunchInterval = Date().timeIntervalSinceReferenceDate
                    }
                    // Seed App Group defaults on every launch so AppIntents read the
                    // current currency without requiring the main app to be running.
                    UserDefaults.appGroup.set(defaultCurrencyCode, forKey: "defaultCurrencyCode")
                }
                .onChange(of: defaultCurrencyCode) { _, new in
                    UserDefaults.appGroup.set(new, forKey: "defaultCurrencyCode")
                }
                // Redirect Bundle.main string lookups the instant the in-app
                // language changes. GeneralSettingView already defers this state
                // change past the picker's dismiss (with animations disabled), so
                // wiring it here keeps Bug 2's sheet-presentation timing untouched.
                .onChange(of: appLanguageCode) { _, new in
                    LocalizedBundle.shared.setLanguage(new)
                }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

// MARK: - Small helper

private extension View {
    @ViewBuilder
    func applyLayoutDirection(_ dir: LayoutDirection?) -> some View {
        if let dir {
            self.environment(\.layoutDirection, dir)
        } else {
            self
        }
    }
}
