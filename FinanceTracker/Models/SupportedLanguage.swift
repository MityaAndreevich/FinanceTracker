//
//  SupportedLanguage.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//

import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case system
    case en, ru, uk, es, fr, de, it, pt, nl, sv, no, da, fi, pl, cs, tr, ar, he, hi, zhHans, ja, ko

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ru: return "Русский"
        case .uk: return "Українська"
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
        case .uk: return "🇺🇦"
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
        case .tr: return "🇹🇷"
        case .ar: return "🇸🇦"
        case .he: return "🇮🇱"
        case .hi: return "🇮🇳"
        case .zhHans: return "🇨🇳"
        case .ja: return "🇯🇵"
        case .ko: return "🇰🇷"
        }
    }

    /// Только для конкретного выбранного языка (system оставляем системе)
    var isRTL: Bool {
        guard self != .system else { return false }
        return Locale.Language(identifier: rawValue).characterDirection == .rightToLeft
    }
}
