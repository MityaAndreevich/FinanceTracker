//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }

            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            AddTransactionView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.pie") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
}
