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

    @State private var showFullCurrencyList = false

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
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Hero icon
                Image(systemName: step.heroSymbol)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)
                    .animation(.spring(duration: 0.3), value: step)

                // MARK: Title + subtitle
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
                .padding(.bottom, 12)

                Spacer(minLength: 6)

                // MARK: Elevated selection list + escape hatch to the full list
                if step == .language {
                    languageSelector
                } else {
                    currencySelector
                }

                Spacer(minLength: 6)

                primaryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .navigationBarBackButtonHidden(step == .language)
            .toolbar { topToolbar }
            .onAppear(perform: preloadFromStorage)
            // Pre-fill the currency to match the chosen language. The user reaches the
            // currency step next and can still override; this is just a better default
            // (Spanish → MXN, Portuguese → BRL, etc.).
            .onChange(of: selectedLanguage) { _, newLang in
                switch newLang {
                case .en: selectedCurrency = .usd
                case .es: selectedCurrency = .mxn
                case .pt: selectedCurrency = .brl
                case .ru: selectedCurrency = .rub
                case .system: break
                }
            }
        }
    }

    // MARK: - Language selector (elevated list)

    private var languageSelector: some View {
        ElevatedSelectionList(
            items: popularLanguages,
            selection: $selectedLanguage,
            labelProvider: { (flag: $0.flag, title: $0.title) },
            searchable: false   // all supported languages fit directly, no search needed
        )
        .frame(maxHeight: 480)
    }

    // MARK: - Currency selector (elevated list + escape hatch to the full list)

    private var currencySelector: some View {
        VStack(spacing: 16) {
            ElevatedSelectionList(
                items: popularCurrencies,
                selection: $selectedCurrency,
                labelProvider: { (flag: $0.flag, title: "\($0.code) — \($0.name)") },
                searchable: false
            )
            .frame(maxHeight: 420)

            Button {
                showFullCurrencyList = true
            } label: {
                Label("onboarding.currency.more", systemImage: "globe.americas")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .sheet(isPresented: $showFullCurrencyList) {
            SearchablePickerSheet(
                titleKey: "onboarding.currency.all",
                items: SupportedCurrency.allCases,
                labelProvider: { "\($0.flag) \($0.code) — \($0.name)" },
                selection: Binding(
                    get: { selectedCurrency.id },
                    set: { newCode in
                        if let cur = SupportedCurrency(rawValue: newCode) { selectedCurrency = cur }
                    }
                )
            )
        }
    }

    // MARK: - Popular subsets (short wheel for first-run delight)

    private var popularLanguages: [SupportedLanguage] {
        // All 4 supported locales (+ System) fit in the wheel — no overflow needed.
        SupportedLanguage.allCases
    }

    private var popularCurrencies: [SupportedCurrency] {
        let popular: [SupportedCurrency] = [.usd, .eur, .gbp, .rub, .jpy, .cny, .brl, .mxn, .cad, .aud]
        return popular.contains(selectedCurrency) ? popular : popular + [selectedCurrency]
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

    // MARK: - Toolbar (progress top-trailing, back top-leading)

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
}

#Preview {
    OnboardingView()
}
