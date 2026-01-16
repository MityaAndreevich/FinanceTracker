//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 1) Достаём "контекст базы данных" из окружения
    // Он будет доступен, потому что в FinanceTrackerApp.swift мы подключили .modelContainer(...)
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("tab.dashboard", systemImage: "house") }

            TransactionsView()
                .tabItem { Label("tab.transactions", systemImage: "list.bullet") }

            AddTransactionView()
                .tabItem { Label("tab.add", systemImage: "plus.circle.fill") }

            AnalyticsView()
                .tabItem { Label("tab.analytics", systemImage: "chart.pie") }

            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gear") }
        }
        // 2) Seed делаем здесь, один раз при появлении ContentView
        .task {
            SeedService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    // В Preview используем inMemory: true, чтобы не трогать реальную базу
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
