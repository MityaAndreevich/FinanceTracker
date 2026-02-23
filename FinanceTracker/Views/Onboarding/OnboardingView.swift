//
//  OnboardingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct OnboardingView: View {
    // Source of truth
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    // UI state
    @State private var step: Step = .language
    @State private var selectedLanguage: SupportedLanguage = .system
    @State private var selectedCurrency: SupportedCurrency = .usd
    @State private var searchText: String = ""

    private enum Step: Int {
        case language = 0
        case currency = 1

        var titleKey: LocalizedStringKey {
            self == .language ? "onboarding.language.title" : "onboarding.currency.title"
        }

        var subtitleKey: LocalizedStringKey {
            self == .language ? "onboarding.language.subtitle" : "onboarding.currency.subtitle"
        }

        var primaryButtonKey: LocalizedStringKey {
            self == .language ? "onboarding.next" : "onboarding.start"
        }

        var progressText: String {
            self == .language ? "1/2" : "2/2"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header

                // Main content
                Group {
                    if step == .language {
                        languageList
                    } else {
                        currencyList
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                Spacer(minLength: 6)

                primaryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .padding(.top, 10)
            .navigationBarBackButtonHidden(step == .language)
            .toolbar { topToolbar }
            .onAppear(perform: preloadFromStorage)
            .onChange(of: step) { _, _ in
                // очищаем поиск при переходе шага (приятнее)
                searchText = ""
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text(step.progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)

            Text(step.titleKey)
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text(step.subtitleKey)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Lists

    private var languageList: some View {
        List {
            ForEach(filteredLanguages) { l in
                selectRow(
                    title: "\(l.flag) \(l.title)",
                    isSelected: l == selectedLanguage
                ) {
                    selectedLanguage = l
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: Text("onboarding.search.languages"))
        .frame(maxHeight: 520)
    }

    private var currencyList: some View {
        List {
            ForEach(filteredCurrencies) { c in
                selectRow(
                    title: "\(c.flag) \(c.code) — \(c.name)",
                    isSelected: c == selectedCurrency
                ) {
                    selectedCurrency = c
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: Text("onboarding.search.currencies"))
        .frame(maxHeight: 520)
    }

    private func selectRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button {
            if step == .language {
                step = .currency
            } else {
                // Save + finish
                appLanguageCode = selectedLanguage.id
                defaultCurrencyCode = selectedCurrency.code
                hasCompletedOnboarding = true
            }
        } label: {
            Text(step.primaryButtonKey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Toolbar

    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if step == .currency {
                Button("onboarding.back") { step = .language }
            }
        }
    }

    // MARK: - Storage preload

    private func preloadFromStorage() {
        // язык
        selectedLanguage = SupportedLanguage(rawValue: appLanguageCode) ?? .system

        // валюта
        selectedCurrency = SupportedCurrency(rawValue: defaultCurrencyCode) ?? .usd
    }

    // MARK: - Filtering

    private var filteredLanguages: [SupportedLanguage] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return SupportedLanguage.allCases }

        return SupportedLanguage.allCases.filter { l in
            l.title.lowercased().contains(q) || l.id.lowercased().contains(q)
        }
    }

    private var filteredCurrencies: [SupportedCurrency] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return SupportedCurrency.allCases }

        return SupportedCurrency.allCases.filter { c in
            c.code.lowercased().contains(q) ||
            c.name.lowercased().contains(q)
        }
    }
}

#Preview {
    OnboardingView()
}


