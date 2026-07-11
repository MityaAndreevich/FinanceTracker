//
//  FinanceTrackerApp.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import os

// MARK: - Cold-start tracing
//
// Signposts are visible in Instruments → os_signpost / Time Profiler; the DEBUG
// print gives a quick console number. Used to profile time-to-first-view and to
// confirm where the synchronous launch cost lives (ModelContainer init).
let coldStartLog = OSLog(subsystem: "com.dmitrylogachev.budgetcrab", category: "ColdStart")

/// Captured at first access (app init), i.e. as early as Swift lets us, to measure
/// time-to-first-view. A global `let` is lazily initialised on first reference.
let appLaunchClock = CFAbsoluteTimeGetCurrent()

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
        os_signpost(.event, log: coldStartLog, name: "app_init_start")
        _ = appLaunchClock   // prime the launch clock as early as possible

        // Must run before SharedModelContainer.shared is first accessed so the
        // lazily-created App Group store is seeded with existing user data.
        SharedModelContainer.migrateLegacyStoreIfNeeded()

        // Silent first-run locale detection (Brief 28 Part E): pins the device
        // language + region currency before the first frame instead of a setup wall.
        // Only writes when the keys are unset, so it never overrides a later Settings
        // choice or an upgrading user's existing selection.
        LocaleAutoDetect.applyDetectedDefaultsIfUnset()

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
                .onAppear {
                    os_signpost(.event, log: coldStartLog, name: "first_view_appeared")
                    #if DEBUG
                    let ms = (CFAbsoluteTimeGetCurrent() - appLaunchClock) * 1000
                    print(String(format: "⏱ cold start → first view: %.0fms", ms))
                    #endif
                }
                // NOTE: deliberately no `.id(appLanguageCode)` here. Re-creating the
                // whole view tree on language change dismissed any in-flight sheet,
                // which caused the Language picker to "bounce back" on the first try.
                // `environment(\.locale)` already refreshes Text("key") strings; the
                // AppleLanguages override (set in GeneralSettingsView) handles the
                // remaining String(localized:) calls on next launch.
                .task {
                    PurchaseManager.shared.start()
                    // Must run after PurchaseManager.start(): AccessManager
                    // subscribes to its entitlement stream and stamps the reverse
                    // trial start on the very first launch (idempotent thereafter).
                    AccessManager.shared.start()
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
