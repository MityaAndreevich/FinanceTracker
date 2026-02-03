//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Onboarding flag
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainApp
            } else {
                OnboardingView()
            }
        }
        .task {
            // Seed должен отработать и до, и после онбординга (на случай если нужны категории для выбора)
            SeedService.seedIfNeeded(modelContext: modelContext)
        }
    }

    // MARK: - Main App

    private var mainApp: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("tab.dashboard", systemImage: "house") }

            NavigationStack {
                TransactionsView()
            }
            .tabItem { Label("tab.transactions", systemImage: "list.bullet") }

            NavigationStack {
                AddTransactionView()
            }
            .tabItem { Label("tab.add", systemImage: "plus.circle.fill") }

            NavigationStack {
                AnalyticsView()
            }
            .tabItem { Label("tab.analytics", systemImage: "chart.pie") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab.settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
