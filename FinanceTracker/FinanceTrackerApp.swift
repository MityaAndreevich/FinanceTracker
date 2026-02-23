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
            return try ModelContainer(for: FinanceTrackerApp.schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
                .task { PurchaseManager.shared.start() }
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
