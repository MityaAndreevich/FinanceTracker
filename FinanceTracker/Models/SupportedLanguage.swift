//
//  SupportedLanguage.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 02.02.2026.
//
//  v1.0 ships 4 fully-translated locales (EN, RU, ES, pt-BR) plus System.
//  Incomplete locales were dropped in Brief 28E to avoid showing raw keys.
//

import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ru
    case es
    case pt  // pt-BR maps to the "pt" enum case (iOS resolves it to pt-BR.lproj)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        case .pt: return "Português (Brasil)"
        }
    }

    var flag: String {
        switch self {
        case .system: return "⚙️"
        case .en: return "🇺🇸"
        case .ru: return "🇷🇺"
        case .es: return "🇪🇸"
        case .pt: return "🇧🇷"
        }
    }

    /// Только для конкретного выбранного языка (system оставляем системе).
    /// None of the v1.0 locales are RTL, but the logic stays generic.
    var isRTL: Bool {
        guard self != .system else { return false }
        return Locale.Language(identifier: rawValue).characterDirection == .rightToLeft
    }
}
