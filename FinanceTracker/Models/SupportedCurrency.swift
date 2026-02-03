//
//  SupportedCurrency.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 28.01.2026.
//

import Foundation

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case cny = "CNY"
    case krw = "KRW"
    case inr = "INR"
    case rub = "RUB"
    case uah = "UAH"   // 🇺🇦 добавлено
    case brl = "BRL"
    case mxn = "MXN"
    case tryy = "TRY"
    case pln = "PLN"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case chf = "CHF"
    case hkd = "HKD"
    case sgd = "SGD"

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
        case .uah: return "Ukrainian Hryvnia"
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
        case .uah: return "🇺🇦"
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
