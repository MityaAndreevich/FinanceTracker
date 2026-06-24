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

    // MARK: - SwiftData container

    private static let schema = Schema([
        Transaction.self,
        Category.self,
        Source.self
    ])

    var sharedModelContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(
            schema: FinanceTrackerApp.schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: FinanceTrackerApp.schema, configurations: [modelConfiguration])
            applyStoreProtection(to: modelConfiguration.url)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - File protection (T-2, T-6)

    /// Apply NSFileProtectionComplete + backup exclusion to the SwiftData store.
    /// Called once after container init. Non-fatal on failure.
    private static func applyStoreProtection(to url: URL) {
        do {
            try (url as NSURL).setResourceValue(
                URLFileProtection.complete,
                forKey: .fileProtectionKey
            )
            // Exclude from iTunes / iCloud backup while CloudKit sync is not active.
            // Reverse isExcludedFromBackupKey when Phase 1 CloudKit sync ships (T-6 trade-off).
            try (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

            #if DEBUG
            let values = try url.resourceValues(forKeys: [.fileProtectionKey])
            let applied = values.fileProtection == .complete
            print("[Security] SwiftData store NSFileProtectionComplete: \(applied ? "✓" : "⚠️ NOT applied")")
            #endif
        } catch {
            // Non-fatal: the store may not exist on the first cold launch before
            // ModelContainer writes the file. Protection is re-applied each launch.
            print("[Security] ⚠️ Could not apply store protection: \(error.localizedDescription)")
        }
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
                }
        }
        .modelContainer(sharedModelContainer)
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
