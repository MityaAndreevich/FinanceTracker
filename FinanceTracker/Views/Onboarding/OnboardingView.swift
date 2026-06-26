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

    @State private var showFullLanguageList = false
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

                // MARK: Wheel picker + escape hatch to the full list
                if step == .language {
                    languageWheel
                } else {
                    currencyWheel
                }

                Spacer(minLength: 6)

                primaryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .navigationBarBackButtonHidden(step == .language)
            .toolbar { topToolbar }
            .onAppear(perform: preloadFromStorage)
            // Tactile detent feedback as the user spins the wheel.
            .sensoryFeedback(.selection, trigger: selectedLanguage)
            .sensoryFeedback(.selection, trigger: selectedCurrency)
        }
    }

    // MARK: - Language wheel

    private var languageWheel: some View {
        VStack(spacing: 16) {
            Picker("onboarding.language.picker", selection: $selectedLanguage) {
                ForEach(popularLanguages) { lang in
                    HStack(spacing: 12) {
                        Text(lang.flag).font(.title2)
                        Text(lang.title).font(.body)
                    }
                    .tag(lang)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
            .clipped()

            Button {
                showFullLanguageList = true
            } label: {
                Label("onboarding.language.more", systemImage: "globe")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .sheet(isPresented: $showFullLanguageList) {
            SearchablePickerSheet(
                titleKey: "onboarding.language.all",
                items: SupportedLanguage.allCases,
                labelProvider: { "\($0.flag) \($0.title)" },
                selection: Binding(
                    get: { selectedLanguage.id },
                    set: { newID in
                        if let lang = SupportedLanguage(rawValue: newID) { selectedLanguage = lang }
                    }
                )
            )
        }
    }

    // MARK: - Currency wheel

    private var currencyWheel: some View {
        VStack(spacing: 16) {
            Picker("onboarding.currency.picker", selection: $selectedCurrency) {
                ForEach(popularCurrencies) { c in
                    HStack(spacing: 12) {
                        Text(c.flag).font(.title2)
                        Text("\(c.code) — \(c.name)").font(.body)
                    }
                    .tag(c)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
            .clipped()

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
        let popular: [SupportedLanguage] = [.system, .en, .es, .ru, .de, .fr, .pt, .ja, .zhHans]
        // Ensure a long-tail pick made via "More…" still shows in the wheel.
        return popular.contains(selectedLanguage) ? popular : popular + [selectedLanguage]
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
