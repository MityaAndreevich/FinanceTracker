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
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.dark.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @AppStorage("hasSeenFeatureTour") private var hasSeenFeatureTour = false

    // Q1=C confidence-gated auto-save (commit cb79b57) is user-tunable here.
    @AppStorage("quickAddConfidenceThreshold") private var quickAddThreshold: Double = 0.75

    // Overall monthly budget (cents). 0 == unset. When set, the Dashboard hero
    // switches from net-this-month to true safe-to-spend. Per-category budgets are
    // a later feature; this is a single app-wide number, no SwiftData model.
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents: Int = 0
    @State private var budgetText: String = ""
    @FocusState private var budgetFieldFocused: Bool

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

    // Demo data is opt-in and reversible, but both adding (inserts ~25 sample
    // transactions) and clearing it are bulk operations, so each is gated behind
    // an explicit confirmation (Bug 11 — demo data must never appear silently).
    @State private var showAddDemoAlert = false
    @State private var showClearDemoAlert = false

    // Универсальный Info Alert
    @State private var showInfoAlert = false
    @State private var infoTitleKey: String = "general.alert.info.title"
    @State private var infoMessageKey: String = "general.info.default"
    @State private var infoExtra: String? = nil // для опциональной детали (например, ошибка)

    var body: some View {
        List {
            preferencesSection
            budgetSection
            quickAddSensitivitySection
            tutorialDemoSection
            maintenanceSection
        }
        .navigationTitle("general.title")
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { budgetFieldFocused = false }
            }
        }
        .onAppear {
            normalizeStoredValuesIfNeeded()
            syncBudgetText()
        }
        .onChange(of: budgetFieldFocused) { _, focused in
            if !focused { commitBudget() }
        }
        .onChange(of: appLanguageCode) { _, _ in normalizeStoredValuesIfNeeded() }
        .onChange(of: defaultCurrencyCode) { _, _ in normalizeStoredValuesIfNeeded() }

        // Picker sheet on root — attaching to a Section (non-root) caused a
        // SwiftUI presentation race where the first tap on the language row was
        // silently swallowed ~50% of the time. Root attachment avoids that.
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
                    identifierPrefix: "picker.locale",
                    selection: Binding(
                        get: { pendingLanguage ?? appLanguageCode },
                        set: { pendingLanguage = $0 }
                    )
                )
            }
        }

        // Info alert
        // B-loc: `infoTitleKey`/`infoMessageKey` are String VARIABLES, so a bare
        // `.alert(infoTitleKey, …)` / `Text(infoMessageKey)` binds the non-localizing
        // `StringProtocol` initializer and renders the raw key ("general.alert.info.title",
        // "general.reset_success.message") verbatim — the device symptom. Wrap them in
        // LocalizedStringKey to force the localizing lookup. `infoExtra` stays verbatim:
        // it is genuine dynamic detail (e.g. an error string), not a key.
        .alert(LocalizedStringKey(infoTitleKey), isPresented: $showInfoAlert) {
            Button("general.alert.ok", role: .cancel) { infoExtra = nil }
        } message: {
            if let infoExtra, !infoExtra.isEmpty {
                // Сообщение по ключу + деталь отдельной строкой
                Text(LocalizedStringKey(infoMessageKey)) + Text(verbatim: "\n\n") + Text(verbatim: infoExtra)
            } else {
                Text(LocalizedStringKey(infoMessageKey))
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

        // Add sample data confirm
        .alert("settings.demo.add", isPresented: $showAddDemoAlert) {
            Button("general.alert.cancel", role: .cancel) {}
            Button("common.add") { DemoDataController.seedDemoData() }
        } message: {
            Text("tutorial.page3.demo_offer")
        }

        // Clear sample data confirm
        .alert("settings.demo.clear", isPresented: $showClearDemoAlert) {
            Button("general.alert.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) {
                DemoDataController.clearDemoData(modelContext: modelContext)
            }
        }
    }

    // MARK: - Quick Add sensitivity (Q1=C threshold override)

    /// Discrete confidence thresholds behind the segmented picker. "Confirm" uses
    /// a sentinel above the 1.0 confidence maximum so even a textbook-perfect parse
    /// still previews — i.e. it always confirms, matching the label.
    private enum QuickAddSensitivity: Double, CaseIterable, Identifiable {
        case confirm = 1.1
        case balanced = 0.75
        case instant = 0.5

        var id: Double { rawValue }
        var labelKey: LocalizedStringKey {
            switch self {
            case .confirm:  return "settings.quickadd.sensitivity.confirm"
            case .balanced: return "settings.quickadd.sensitivity.balanced"
            case .instant:  return "settings.quickadd.sensitivity.instant"
            }
        }
    }

    private var quickAddSensitivityBinding: Binding<QuickAddSensitivity> {
        Binding(
            get: { QuickAddSensitivity(rawValue: quickAddThreshold) ?? .balanced },
            set: { quickAddThreshold = $0.rawValue }
        )
    }

    private var quickAddSensitivitySection: some View {
        Section {
            Picker("settings.quickadd.sensitivity.label", selection: quickAddSensitivityBinding) {
                ForEach(QuickAddSensitivity.allCases) { level in
                    Text(level.labelKey).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.quickadd.sensitivity.picker")
        } header: {
            Text("settings.quickadd.sensitivity.label")
        } footer: {
            Text("settings.quickadd.sensitivity.caption")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sections

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .dark },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private var preferencesSection: some View {
        Section("general.section.preferences") {

            Picker(selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.labelKey).tag(mode)
                }
            } label: {
                Label("settings.appearance.label", systemImage: "moon.stars")
            }
            .pickerStyle(.menu)

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
            .accessibilityIdentifier("settings.language.row")

            Text("general.language_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                // Bug 10: RU/UK copy is ~30-40% longer than EN and was truncating
                // mid-sentence ("…при следующем открытии Budget…"). fixedSize forces
                // full vertical wrap instead of clipping to the row's default height.
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Monthly budget

    private var budgetSection: some View {
        Section {
            HStack {
                Label("settings.budget.label", systemImage: "target")
                Spacer(minLength: 12)
                TextField("settings.budget.placeholder", text: $budgetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($budgetFieldFocused)
                    .frame(maxWidth: 140)
                    .accessibilityIdentifier("settings.budget.field")
                Text(defaultCurrencyCode)
                    .foregroundStyle(.secondary)
            }

            if monthlyBudgetCents > 0 {
                Button("settings.budget.clear", role: .destructive) {
                    monthlyBudgetCents = 0
                    budgetText = ""
                    budgetFieldFocused = false
                }
            }
        } header: {
            Text("settings.budget.header")
        } footer: {
            Text("settings.budget.caption")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Mirrors the stored cents into the editable text field (on appear / after a
    /// commit). Empty when unset so the placeholder shows through.
    private func syncBudgetText() {
        budgetText = monthlyBudgetCents > 0
            ? Money.plainDecimalString(cents: monthlyBudgetCents)
            : ""
    }

    /// Parses the field into `monthlyBudgetCents` on focus loss. Blank clears the
    /// budget (0 == unset → hero falls back to net-this-month).
    private func commitBudget() {
        let trimmed = budgetText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            monthlyBudgetCents = 0
        } else {
            monthlyBudgetCents = max(0, Money.parseCents(from: trimmed) ?? 0)
        }
        syncBudgetText()
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

        // 5th attempt at the "screen drops on the first language change" bug.
        // onDismiss fires while the sheet's dismiss transition is still settling.
        // Mutating @AppStorage there re-resolves every LocalizedStringKey AND the
        // environment locale mid-transition, so the List underneath visibly drops
        // on the *first* attempt (the second worked only because the sheet was
        // already gone). Fix: defer the apply past the full dismiss animation, and
        // commit it with animations disabled so the locale re-render doesn't ride
        // the transition. No restart alert (see Briefs 28D–28G); the live
        // environment(\.locale) refreshes Text("key") immediately and code-resolved
        // String(localized:) strings pick up the new language on next launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            var tx = SwiftUI.Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                if let currency, currency != defaultCurrencyCode {
                    defaultCurrencyCode = currency
                }
                if let language, language != appLanguageCode {
                    appLanguageCode = language
                    applyAppleLanguagesOverride(for: language)
                }
            }
        }
    }

    /// Mirrors the chosen app language into the `AppleLanguages` UserDefaults key so
    /// Bundle.main (and therefore every `String(localized:)` / `NSLocalizedString`
    /// call) resolves against the right `.lproj` on the next launch. The live
    /// `environment(\.locale)` binding already handles `Text("key")` immediately;
    /// this closes the gap for code-resolved strings without the fragile `.id()`
    /// view-tree recreation that previously bounced the picker.
    private func applyAppleLanguagesOverride(for code: String) {
        let appleLangCode: String?
        switch code {
        case "system", "": appleLangCode = nil          // hand control back to iOS
        case "es":         appleLangCode = "es-MX"        // LATAM target market
        case "pt":         appleLangCode = "pt-BR"        // resources live in pt-BR.lproj
        default:           appleLangCode = code           // en, ru
        }
        if let appleLangCode {
            UserDefaults.standard.set([appleLangCode], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    private var tutorialDemoSection: some View {
        Section("settings.section.tutorial_demo") {
            if DemoDataController.isDemoDataActive {
                Button("settings.demo.clear", role: .destructive) {
                    showClearDemoAlert = true
                }
            } else {
                Button("settings.demo.add") {
                    showAddDemoAlert = true
                }
            }

            Button("settings.tutorial.replay") {
                // Re-run the first-run coach-mark flow immediately (Brief 28 Part B):
                // arm the coordinator's one-shot replay flag and ask ContentView to
                // restart the flow on the Dashboard. hasSeenFeatureTour is reset for the
                // rating gate's sake; the retired carousel no longer reads it.
                UserDefaults.standard.set(true, forKey: OnboardingCoordinator.replayKey)
                hasSeenFeatureTour = false
                RatingPromptCoordinator.resetForTutorialReplay()
                NotificationCenter.default.post(name: .budgetCrabReplayOnboarding, object: nil)
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
        // Bug 20: decide by what's actually left in the store, not by whether
        // save() threw. SwiftData can emit non-fatal aggregated validation noise on
        // a bulk delete even when every row is gone — surfacing that as an error was
        // a false negative (the data really was wiped).
        switch TransactionResetService.reset(in: modelContext) {
        case .success:
            // Reset wipes every transaction, including any demo-flagged ones, so the
            // demo-active flag must follow — otherwise Settings would keep showing
            // "Clear sample data" (and block re-adding) with no demo data present.
            DemoDataController.isDemoDataActive = false

            showInfo(
                titleKey: "general.alert.info.title",
                messageKey: "general.reset_success.message",
                extra: nil
            )
        case .failure(let remaining):
            // Only a genuine failure — rows actually survived the delete.
            showInfo(
                titleKey: "general.alert.info.title",
                messageKey: "general.reset_failed.message",
                extra: nil
            )
            #if DEBUG
            print("Reset failed: \(remaining) transaction(s) remain.")
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
