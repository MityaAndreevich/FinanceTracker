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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Source.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var appLocale: Locale {
        if appLanguageCode == "system" {
            return .current
        } else {
            return Locale(identifier: appLanguageCode)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLocale)
                .task {
                    PurchaseManager.shared.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
