//
//  OnboardingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

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
            self == .language ? "onboarding.next" : "onboarding.cta.start_tracking"
        }

        var progressText: String {
            self == .language ? "1/2" : "2/2"
        }

        var heroSymbol: String {
            self == .language ? "globe" : "dollarsign.circle"
        }

        var searchPromptKey: LocalizedStringKey {
            self == .language ? "onboarding.search.languages" : "onboarding.search.currencies"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Hero icon — Task A
                Image(systemName: step.heroSymbol)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)
                    .animation(.spring(duration: 0.3), value: step)

                // MARK: Title + subtitle — Task B
                VStack(spacing: 8) {
                    Text(step.titleKey)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Text(step.subtitleKey)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)

                // MARK: Elevated card — Tasks C, D, E
                VStack(spacing: 0) {
                    searchBar

                    Color(.tertiarySystemFill).frame(height: 0.5)

                    if step == .language {
                        languageList
                    } else {
                        currencyList
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)

                Spacer(minLength: 6)

                primaryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .navigationBarBackButtonHidden(step == .language)
            .toolbar { topToolbar }
            .onAppear(perform: preloadFromStorage)
            .onChange(of: step) { _, _ in searchText = "" }
        }
    }

    // MARK: - Search bar — Task C

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))

            TextField(step.searchPromptKey, text: $searchText)
                .font(.system(size: 17))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Lists — Tasks E, F

    private var languageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredLanguages.enumerated()), id: \.element.id) { idx, l in
                    selectRow(
                        flag: l.flag,
                        title: l.title,
                        isSelected: l == selectedLanguage
                    ) {
                        selectedLanguage = l
                    }
                    if idx < filteredLanguages.count - 1 {
                        Color(.tertiarySystemFill)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxHeight: 420)
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(duration: 0.25), value: selectedLanguage)
    }

    private var currencyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredCurrencies.enumerated()), id: \.element.id) { idx, c in
                    selectRow(
                        flag: c.flag,
                        title: "\(c.code) — \(c.name)",
                        isSelected: c == selectedCurrency
                    ) {
                        selectedCurrency = c
                    }
                    if idx < filteredCurrencies.count - 1 {
                        Color(.tertiarySystemFill)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxHeight: 420)
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(duration: 0.25), value: selectedCurrency)
    }

    // MARK: - Row — Tasks E, F

    private func selectRow(flag: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.system(size: 22))

                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button {
            if step == .language {
                step = .currency
            } else {
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
        .tint(.accentColor)
    }

    // MARK: - Toolbar — Task B (progress top-trailing, back top-leading)

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if step == .currency {
                Button("onboarding.back") { step = .language }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Text(step.progressText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Storage preload

    private func preloadFromStorage() {
        selectedLanguage = SupportedLanguage(rawValue: appLanguageCode) ?? .system
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
            c.code.lowercased().contains(q) || c.name.lowercased().contains(q)
        }
    }
}

#Preview {
    OnboardingView()
}
