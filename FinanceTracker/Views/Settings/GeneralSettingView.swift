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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @AppStorage("hasSeenFeatureTour") private var hasSeenFeatureTour = false

    // Single source of truth for the two picker sheets. Using .sheet(item:) rather
    // than two .sheet(isPresented:) modifiers prevents "Attempt to present … which is
    // already presenting …" when one sheet's content changes while another resolves.
    private enum PickerSheet: String, Identifiable {
        case currency, language
        var id: String { rawValue }
    }
    @State private var activeSheet: PickerSheet?
    // Pending selections are applied only after the sheet finishes dismissing, so the
    // locale/currency re-render storm can't collide with the dismiss transition
    // (which previously produced "Invalid frame dimension" NaN warnings).
    @State private var pendingCurrency: String?
    @State private var pendingLanguage: String?

    @State private var showResetTransactionsAlert = false
    @State private var showRestartOnboardingAlert = false

    // Универсальный Info Alert
    @State private var showInfoAlert = false
    @State private var infoTitleKey: String = "general.alert.info.title"
    @State private var infoMessageKey: String = "general.info.default"
    @State private var infoExtra: String? = nil // для опциональной детали (например, ошибка)

    var body: some View {
        List {
            preferencesSection
            tutorialDemoSection
            maintenanceSection
        }
        .navigationTitle("general.title")
        .listStyle(.insetGrouped)
        .onAppear { normalizeStoredValuesIfNeeded() }
        .onChange(of: appLanguageCode) { _, _ in normalizeStoredValuesIfNeeded() }
        .onChange(of: defaultCurrencyCode) { _, _ in normalizeStoredValuesIfNeeded() }

        // Info alert
        .alert(infoTitleKey, isPresented: $showInfoAlert) {
            Button("general.alert.ok", role: .cancel) { infoExtra = nil }
        } message: {
            if let infoExtra, !infoExtra.isEmpty {
                // Сообщение по ключу + деталь отдельной строкой
                Text(infoMessageKey) + Text("\n\n") + Text(infoExtra)
            } else {
                Text(infoMessageKey)
            }
        }

        // Reset transactions confirm
        .alert("general.alert.reset_tx.title", isPresented: $showResetTransactionsAlert) {
            Button("general.alert.cancel", role: .cancel) {}
            Button("general.alert.reset", role: .destructive) { resetTransactions() }
        } message: {
            Text("general.alert.reset_tx.message")
        }

        // Restart onboarding confirm
        .alert("general.alert.restart_onboarding.title", isPresented: $showRestartOnboardingAlert) {
            Button("general.alert.cancel", role: .cancel) {}
            Button("general.alert.restart", role: .destructive) { restartOnboarding() }
        } message: {
            Text("general.alert.restart_onboarding.message")
        }
    }

    // MARK: - Sections

    private var preferencesSection: some View {
        Section("general.section.preferences") {

            Button {
                activeSheet = .currency
            } label: {
                HStack {
                    Text("general.currency")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let current = SupportedCurrency.allCases.first(where: { $0.code == defaultCurrencyCode }) {
                        Text("\(current.flag) \(current.code)")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                activeSheet = .language
            } label: {
                HStack {
                    Text("general.language")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let current = SupportedLanguage(rawValue: appLanguageCode) {
                        Text("\(current.flag) \(current.title)")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text("general.language_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sheet(item: $activeSheet, onDismiss: applyPendingSelection) { sheet in
            switch sheet {
            case .currency:
                SearchablePickerSheet(
                    titleKey: "general.currency",
                    items: SupportedCurrency.allCases,
                    labelProvider: { "\($0.flag) \($0.code) — \($0.name)" },
                    selection: Binding(
                        get: { pendingCurrency ?? defaultCurrencyCode },
                        set: { pendingCurrency = $0 }
                    )
                )
            case .language:
                SearchablePickerSheet(
                    titleKey: "general.language",
                    items: SupportedLanguage.allCases,
                    labelProvider: { "\($0.flag) \($0.title)" },
                    selection: Binding(
                        get: { pendingLanguage ?? appLanguageCode },
                        set: { pendingLanguage = $0 }
                    )
                )
            }
        }
    }

    /// Commits a picker selection after the sheet has fully dismissed. Applying the
    /// @AppStorage change inline (while the sheet animates away) re-resolves every
    /// LocalizedStringKey and the environment locale mid-transition, which crashed
    /// sheet presentation and emitted NaN frame warnings.
    private func applyPendingSelection() {
        let currency = pendingCurrency
        let language = pendingLanguage
        pendingCurrency = nil
        pendingLanguage = nil
        guard currency != nil || language != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let currency, currency != defaultCurrencyCode { defaultCurrencyCode = currency }
            if let language, language != appLanguageCode { appLanguageCode = language }
        }
    }

    private var tutorialDemoSection: some View {
        Section("settings.section.tutorial_demo") {
            if DemoDataController.isDemoDataActive {
                Button("settings.demo.clear", role: .destructive) {
                    DemoDataController.clearDemoData(modelContext: modelContext)
                }
            } else {
                Button("settings.demo.add") {
                    DemoDataController.seedDemoData()
                }
            }

            Button("settings.tutorial.replay") {
                hasSeenFeatureTour = false
                RatingPromptCoordinator.resetForTutorialReplay()
            }
        }
    }

    private var maintenanceSection: some View {
        Section("general.section.maintenance") {

            Button {
                showRestartOnboardingAlert = true
            } label: {
                Label("general.restart_onboarding", systemImage: "arrow.counterclockwise")
            }

            Button(role: .destructive) {
                showResetTransactionsAlert = true
            } label: {
                Label("general.reset_transactions", systemImage: "trash")
            }

            Text("general.reset_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func restartOnboarding() {
        // Данные не трогаем. Просто возвращаем онбординг.
        hasCompletedOnboarding = false
    }

    private func resetTransactions() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<Transaction>())
            all.forEach { modelContext.delete($0) }
            try modelContext.save()

            showInfo(
                titleKey: "general.alert.info.title",
                messageKey: "general.reset_success.message",
                extra: nil
            )
        } catch {
            // Локализованный текст + опционально деталь (на английском, как приходит от системы)
            showInfo(
                titleKey: "general.alert.info.title",
                messageKey: "general.reset_failed.message",
                extra: error.localizedDescription
            )
            #if DEBUG
            print("Reset failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Helpers

    private func showInfo(titleKey: String, messageKey: String, extra: String?) {
        infoTitleKey = titleKey
        infoMessageKey = messageKey
        infoExtra = extra
        showInfoAlert = true
    }

    private func normalizeStoredValuesIfNeeded() {
        if SupportedLanguage(rawValue: appLanguageCode) == nil {
            appLanguageCode = "system"
        }

        let codes = Set(SupportedCurrency.allCases.map { $0.code })
        if codes.contains(defaultCurrencyCode) == false {
            defaultCurrencyCode = "USD"
        }
    }
}
