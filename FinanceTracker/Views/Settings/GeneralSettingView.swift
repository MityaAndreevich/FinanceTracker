//
//  GeneralSettingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 28.01.2026.
//

import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"

    @State private var showResetAlert = false
    @State private var showInfoAlert = false
    @State private var infoMessage = ""

    var body: some View {
        List {
            Section("Preferences") {

                Picker("Currency", selection: $defaultCurrencyCode) {
                    ForEach(SupportedCurrency.allCases) { c in
                        Text("\(c.flag) \(c.code) — \(c.name)").tag(c.code)
                    }
                }

                Picker("Language", selection: $appLanguageCode) {
                    Text("System").tag("system")
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }

                Text("Language switching will be fully enabled when localization keys are added.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Maintenance") {
                Button {
                    infoMessage = "There’s no cache to clear yet. This will be useful when offline caching is added."
                    showInfoAlert = true
                } label: {
                    Label("Clear Cache", systemImage: "wand.and.stars") // вместо broom
                }

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Reset Transactions", systemImage: "trash")
                }

                Text("Reset Transactions removes all transactions but keeps your categories and sources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Account") {
                Button {
                    infoMessage = "Sign out will be available when we add accounts (iCloud sync / login)."
                    showInfoAlert = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("General")
        .listStyle(.insetGrouped)
        .alert("Info", isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
        .alert("Reset Transactions?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetTransactions()
            }
        } message: {
            Text("This will permanently delete all transactions on this device.")
        }
    }

    private func resetTransactions() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<Transaction>())
            all.forEach { modelContext.delete($0) }
            try modelContext.save()
        } catch {
            infoMessage = "Reset failed: \(error.localizedDescription)"
            showInfoAlert = true
        }
    }
}
