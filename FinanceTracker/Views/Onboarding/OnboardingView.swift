//
//  OnboardingView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var step: Int = 0
    @State private var selectedLanguage: String = "system"
    @State private var selectedCurrency: String = "USD"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 10)

                Text(step == 0 ? "onboarding.language.title" : "onboarding.currency.title")
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(step == 0 ? "onboarding.language.subtitle" : "onboarding.currency.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if step == 0 {
                    languagePicker
                } else {
                    currencyPicker
                }

                Spacer()

                Button {
                    if step == 0 {
                        step = 1
                    } else {
                        // Save + finish
                        settings.appLanguage = selectedLanguage
                        settings.defaultCurrencyCode = selectedCurrency
                        settings.hasCompletedOnboarding = true
                    }
                } label: {
                    Text(step == 0 ? "onboarding.next" : "onboarding.start")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.top, 10)
            .navigationBarBackButtonHidden(step == 0)
            .toolbar {
                if step == 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("onboarding.back") { step = 0 }
                    }
                }
            }
        }
    }

    private var languagePicker: some View {
        List {
            Picker("onboarding.language.picker", selection: $selectedLanguage) {
                ForEach(SupportedLanguage.allCases) { l in
                    Text("\(l.flag) \(l.title)").tag(l.id)
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(maxHeight: 360)
    }

    private var currencyPicker: some View {
        List {
            Picker("onboarding.currency.picker", selection: $selectedCurrency) {
                ForEach(SupportedCurrency.allCases) { c in
                    Text("\(c.flag) \(c.code) — \(c.name)").tag(c.code)
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(maxHeight: 360)
    }
}

private enum SupportedLanguage: String, CaseIterable, Identifiable {
    case system
    case en, ru, es, fr, de, it, pt, nl, sv, no, da, fi, pl, cs, uk, tr, ar, he, hi, zhHans, ja, ko // 20+ уже есть

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .nl: return "Nederlands"
        case .sv: return "Svenska"
        case .no: return "Norsk"
        case .da: return "Dansk"
        case .fi: return "Suomi"
        case .pl: return "Polski"
        case .cs: return "Čeština"
        case .uk: return "Українська"
        case .tr: return "Türkçe"
        case .ar: return "العربية"
        case .he: return "עברית"
        case .hi: return "हिन्दी"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    var flag: String {
        switch self {
        case .system: return "⚙️"
        case .en: return "🇺🇸"
        case .ru: return "🇷🇺"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .pt: return "🇵🇹"
        case .nl: return "🇳🇱"
        case .sv: return "🇸🇪"
        case .no: return "🇳🇴"
        case .da: return "🇩🇰"
        case .fi: return "🇫🇮"
        case .pl: return "🇵🇱"
        case .cs: return "🇨🇿"
        case .uk: return "🇺🇦"
        case .tr: return "🇹🇷"
        case .ar: return "🇸🇦"
        case .he: return "🇮🇱"
        case .hi: return "🇮🇳"
        case .zhHans: return "🇨🇳"
        case .ja: return "🇯🇵"
        case .ko: return "🇰🇷"
        }
    }
}

// Можно переиспользовать твой SupportedCurrency, но расширим до 20+
private enum SupportedCurrency: String, CaseIterable, Identifiable {
    case usd="USD", eur="EUR", gbp="GBP", cad="CAD", aud="AUD"
    case jpy="JPY", cny="CNY", krw="KRW", inr="INR", rub="RUB"
    case brl="BRL", mxn="MXN", tryy="TRY", pln="PLN", sek="SEK"
    case nok="NOK", dkk="DKK", chf="CHF", hkd="HKD", sgd="SGD"

    var id: String { rawValue }
    var code: String { rawValue }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .krw: return "South Korean Won"
        case .inr: return "Indian Rupee"
        case .rub: return "Russian Ruble"
        case .brl: return "Brazilian Real"
        case .mxn: return "Mexican Peso"
        case .tryy: return "Turkish Lira"
        case .pln: return "Polish Zloty"
        case .sek: return "Swedish Krona"
        case .nok: return "Norwegian Krone"
        case .dkk: return "Danish Krone"
        case .chf: return "Swiss Franc"
        case .hkd: return "Hong Kong Dollar"
        case .sgd: return "Singapore Dollar"
        }
    }

    var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .cad: return "🇨🇦"
        case .aud: return "🇦🇺"
        case .jpy: return "🇯🇵"
        case .cny: return "🇨🇳"
        case .krw: return "🇰🇷"
        case .inr: return "🇮🇳"
        case .rub: return "🇷🇺"
        case .brl: return "🇧🇷"
        case .mxn: return "🇲🇽"
        case .tryy: return "🇹🇷"
        case .pln: return "🇵🇱"
        case .sek: return "🇸🇪"
        case .nok: return "🇳🇴"
        case .dkk: return "🇩🇰"
        case .chf: return "🇨🇭"
        case .hkd: return "🇭🇰"
        case .sgd: return "🇸🇬"
        }
    }
}
