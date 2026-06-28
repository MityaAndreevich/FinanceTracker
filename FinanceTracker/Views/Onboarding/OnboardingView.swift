//
//  OnboardingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//
//  First-run flow. The language is auto-detected from the device (Brief: Wave 3
//  Fix #14) so the user lands one tap from value — only the currency, which is
//  genuinely ambiguous from language alone, still needs confirming. Manual
//  language override lives in Settings → Language for later.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    // Auto-detected on appear; not user-facing anymore (no language screen).
    @State private var selectedLanguage: SupportedLanguage = .system
    @State private var selectedCurrency: SupportedCurrency = .usd

    @State private var showFullCurrencyList = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Hero icon
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)

                // MARK: Title + subtitle
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

                // MARK: Currency selection + escape hatch to the full list
                currencySelector

                Spacer(minLength: 6)

                primaryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .onAppear(perform: autoDetectDefaults)
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
            selectedLanguage = detected
            selectedCurrency = defaultCurrency(for: detected)
        }
    }

    /// Maps the device's preferred language to one of our four shipped locales.
    /// Unsupported languages resolve to `.system`, which renders the English base
    /// strings at runtime (no `<lang>.lproj` to match) — graceful fallback, no
    /// confirmation screen needed.
    private func detectDeviceLanguage() -> SupportedLanguage {
        guard let preferred = Locale.preferredLanguages.first else { return .system }
        switch Locale(identifier: preferred).language.languageCode?.identifier {
        case "en": return .en
        case "ru": return .ru
        case "es": return .es
        case "pt": return .pt
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
