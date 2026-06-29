//
//  OnboardingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//
//  First-run flow: language → currency. The language is auto-detected from the
//  device and pre-selected, but the user explicitly confirms (or overrides) it —
//  multilingual phones and app-specific preferences make a silent guess a poor
//  default, and an explicit screen is more discoverable. Currency follows, since
//  it's genuinely ambiguous from language alone. Both are changeable later in
//  Settings.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    private enum Step { case language, currency }
    @State private var step: Step = .language

    @State private var selectedLanguage: SupportedLanguage = .en
    @State private var selectedCurrency: SupportedCurrency = .usd

    @State private var showFullCurrencyList = false

    /// The explicitly shippable locales (System is implicit via fallback).
    private let offeredLanguages: [SupportedLanguage] = [.en, .ru, .es, .pt, .uk]

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .language: languageStep
                case .currency: currencyStep
                }
            }
            .onAppear(perform: autoDetectDefaults)
            .toolbar {
                if step == .currency {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { step = .language }
                        } label: {
                            Label("onboarding.back", systemImage: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Language step

    private var languageStep: some View {
        VStack(spacing: 0) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("onboarding.language.title")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Text("onboarding.language.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)

            Spacer(minLength: 6)

            VStack(spacing: 12) {
                ForEach(offeredLanguages) { lang in
                    languageCard(lang)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 6)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { step = .currency }
            } label: {
                Text("onboarding.next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func languageCard(_ lang: SupportedLanguage) -> some View {
        let isSelected = selectedLanguage == lang
        return Button {
            selectLanguage(lang)
        } label: {
            HStack(spacing: 14) {
                Text(lang.flag)
                    .font(.title2)
                Text(lang.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.language.\(lang.id)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Confirms a language. Applies it live (so the rest of onboarding renders in
    /// the chosen language) and re-guesses the currency to match.
    private func selectLanguage(_ lang: SupportedLanguage) {
        guard selectedLanguage != lang else { return }
        selectedLanguage = lang
        appLanguageCode = lang.id
        applyAppleLanguagesOverride(for: lang.id)
        selectedCurrency = defaultCurrency(for: lang)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Currency step

    private var currencyStep: some View {
        VStack(spacing: 0) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("onboarding.currency.title")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Text("onboarding.currency.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 12)

            Spacer(minLength: 6)

            currencySelector

            Spacer(minLength: 6)

            primaryButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
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

    private var popularCurrencies: [SupportedCurrency] {
        let popular: [SupportedCurrency] = [.usd, .eur, .gbp, .rub, .jpy, .cny, .brl, .mxn, .cad, .aud]
        return popular.contains(selectedCurrency) ? popular : popular + [selectedCurrency]
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button {
            appLanguageCode = selectedLanguage.id
            applyAppleLanguagesOverride(for: selectedLanguage.id)
            defaultCurrencyCode = selectedCurrency.code
            hasCompletedOnboarding = true
        } label: {
            Text("onboarding.cta.start_tracking")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
    }

    // MARK: - Auto-detection

    /// Resolves the starting language + currency. On a genuine first run we read
    /// the device language; if the user returned via Settings → Restart onboarding,
    /// their previously pinned choice is respected instead of being overwritten.
    private func autoDetectDefaults() {
        if let pinned = SupportedLanguage(rawValue: appLanguageCode), pinned != .system {
            selectedLanguage = pinned
            selectedCurrency = SupportedCurrency(rawValue: defaultCurrencyCode)
                ?? defaultCurrency(for: pinned)
        } else {
            let detected = detectDeviceLanguage()
            // Unsupported device languages pre-select the English fallback so the
            // user still sees a highlighted card rather than nothing.
            selectedLanguage = detected == .system ? .en : detected
            selectedCurrency = defaultCurrency(for: selectedLanguage)
        }
    }

    /// Maps the device's preferred language to one of our four shipped locales.
    /// Unsupported languages resolve to `.system` (handled as English above).
    private func detectDeviceLanguage() -> SupportedLanguage {
        guard let preferred = Locale.preferredLanguages.first else { return .system }
        switch Locale(identifier: preferred).language.languageCode?.identifier {
        case "en": return .en
        case "ru": return .ru
        case "es": return .es
        case "pt": return .pt
        case "uk": return .uk
        default:   return .system
        }
    }

    /// Best currency guess. Prefers the device region's actual currency when we
    /// support it, otherwise falls back to a language-based default.
    private func defaultCurrency(for language: SupportedLanguage) -> SupportedCurrency {
        if let regionCode = Locale.current.currency?.identifier,
           let regionCurrency = SupportedCurrency(rawValue: regionCode) {
            return regionCurrency
        }
        switch language {
        case .es: return .mxn
        case .pt: return .brl
        case .ru: return .rub
        case .uk: return .uah
        case .en, .system: return .usd
        }
    }

    /// Mirrors the resolved language into the `AppleLanguages` key so
    /// `String(localized:)` / `NSLocalizedString` resolve against the right
    /// `.lproj` on the next launch (matches GeneralSettingsView). For `.system`
    /// we hand control back to iOS by removing the override.
    private func applyAppleLanguagesOverride(for code: String) {
        let appleLangCode: String?
        switch code {
        case "system", "": appleLangCode = nil           // hand control back to iOS
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
}

#Preview {
    OnboardingView()
}
