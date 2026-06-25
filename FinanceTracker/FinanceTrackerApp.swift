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

    init() {
        // Must run before SharedModelContainer.shared is first accessed so the
        // lazily-created App Group store is seeded with existing user data.
        SharedModelContainer.migrateLegacyStoreIfNeeded()
    }

    // MARK: - Locale + Layout

    private var appLocale: Locale {
        guard appLanguageCode != "system" else { return .autoupdatingCurrent }
        return Locale(identifier: appLanguageCode)
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
                .applyLayoutDirection(overrideLayoutDirection)
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
