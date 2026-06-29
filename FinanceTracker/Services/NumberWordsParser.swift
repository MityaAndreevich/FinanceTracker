//
//  NumberWordsParser.swift
//  FinanceTracker
//
//  Converts spelled-out numbers in transcribed speech to digit substrings,
//  so the main parser can find amounts even when iOS dictation spells them out.
//
//  Handles:
//    - Russian: "семь" → "7", "двадцать пять" → "25", "сто пятьдесят" → "150"
//    - English: "twelve" → "12", "twenty five" → "25", "one hundred fifty" → "150"
//    - Spanish, German, French, Portuguese, Japanese, Chinese
//
//  Algorithm: token-based with multiplier folding (hundreds, thousands).
//  Returns the input string with number-word sequences replaced by digit strings.
//  All logic is on-device; no data leaves the device.
//

import Foundation

enum NumberWordsParser {

    /// Convert spelled-out numbers in `input` to digit substrings.
    /// Example: "Продал яйца за семь" → "Продал яйца за 7"
    /// Returns the modified string.
    static func normalize(_ input: String, locale: String) -> String {
        let dict = dictionary(for: locale)
        guard !dict.isEmpty else { return input }

        // Tokenize on whitespace, preserve case for non-matches
        let tokens = input.split(separator: " ", omittingEmptySubsequences: false)
        var output: [String] = []
        var numberRun: [String] = []

        func flushRun() {
            guard !numberRun.isEmpty else { return }
            if let value = combine(numberRun, dict: dict) {
                output.append(String(value))
            } else {
                output.append(contentsOf: numberRun)
            }
            numberRun.removeAll()
        }

        for token in tokens {
            let lower = token.lowercased()
            if dict[lower] != nil {
                numberRun.append(String(token))
            } else {
                flushRun()
                output.append(String(token))
            }
        }
        flushRun()

        return output.joined(separator: " ")
    }

    // MARK: - Cross-locale normalization (Bug 2)

    /// Languages with a number-word dictionary, used by the cross-locale fallback.
    private static let supportedLanguages = ["en", "ru", "es", "de", "fr", "pt", "ja", "zh"]

    /// Two-letter language prefix used for dictionary dispatch.
    private static func languagePrefix(for locale: String) -> String {
        if locale == "system" || locale.isEmpty {
            return String(Locale.current.identifier.prefix(2))
        }
        return String(locale.prefix(2))
    }

    /// Tries the app's language first, then every other supported language when the
    /// input still carries no digit. iOS dictation may transcribe in a different
    /// language than the app UI — e.g. a Russian-UI user who says "fifteen", or an
    /// English-UI user who says "quince" — and gating only by the app language left
    /// the amount unparsed (Save disabled). The digit guard prevents a cross-language
    /// false positive (e.g. Spanish "una"→1) when the amount is already present.
    static func normalize(_ input: String, primaryLocale: String) -> String {
        let primaryResult = normalize(input, locale: primaryLocale)
        if primaryResult != input { return primaryResult }
        // An amount is already spelled in digits — let the amount regex find it.
        if input.contains(where: \.isNumber) { return primaryResult }

        let primaryLang = languagePrefix(for: primaryLocale)
        for lang in supportedLanguages where lang != primaryLang {
            let result = normalize(input, locale: lang)
            if result != input { return result }
        }
        return input
    }

    // MARK: - Combine adjacent number-words into integer

    /// Combines a sequence of number-words into a single integer.
    /// Examples:
    ///   ["семь"] → 7
    ///   ["двадцать", "пять"] → 25
    ///   ["сто", "пятьдесят"] → 150
    ///   ["две", "тысячи", "пятьсот"] → 2500
    ///   ["one", "hundred", "twenty", "five"] → 125
    private static func combine(_ words: [String], dict: [String: Int]) -> Int? {
        var total = 0
        var current = 0
        for word in words {
            guard let value = dict[word.lowercased()] else { return nil }
            switch value {
            case 1_000_000:
                total += max(current, 1) * 1_000_000
                current = 0
            case 1000:
                total += max(current, 1) * 1000
                current = 0
            case 100:
                current = max(current, 1) * 100
            default:
                // For languages with already-multiplied hundreds (сто=100, двести=200),
                // these values are 100, 200, 300, ... 900 — add directly.
                // For 1-99 values — add directly.
                current += value
            }
        }
        let result = total + current
        return result > 0 ? result : nil
    }

    // MARK: - Locale dispatch

    private static func dictionary(for locale: String) -> [String: Int] {
        // Map appLanguageCode or system locale prefix to dictionary
        let lang: String
        if locale == "system" || locale.isEmpty {
            // Fall back to current locale prefix
            lang = String(Locale.current.identifier.prefix(2))
        } else {
            lang = String(locale.prefix(2))
        }

        switch lang {
        case "ru": return russian
        case "en": return english
        case "es": return spanish
        case "de": return german
        case "fr": return french
        case "pt": return portuguese
        case "ja": return japanese
        case "zh": return chinese
        default: return english  // fallback
        }
    }

    // MARK: - Russian

    private static let russian: [String: Int] = [
        "ноль": 0, "один": 1, "одна": 1, "одно": 1,
        "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5,
        "шесть": 6, "семь": 7, "восемь": 8, "девять": 9, "десять": 10,
        "одиннадцать": 11, "двенадцать": 12, "тринадцать": 13, "четырнадцать": 14,
        "пятнадцать": 15, "шестнадцать": 16, "семнадцать": 17, "восемнадцать": 18,
        "девятнадцать": 19,
        "двадцать": 20, "тридцать": 30, "сорок": 40, "пятьдесят": 50,
        "шестьдесят": 60, "семьдесят": 70, "восемьдесят": 80, "девяносто": 90,
        // RU has irregular hundreds — each one its own word
        "сто": 100, "двести": 200, "триста": 300, "четыреста": 400, "пятьсот": 500,
        "шестьсот": 600, "семьсот": 700, "восемьсот": 800, "девятьсот": 900,
        // Thousands
        "тысяча": 1000, "тысячи": 1000, "тысяч": 1000, "тыс": 1000,
        // Colloquial "тыща" forms (пять тыщ → 5000)
        "тыща": 1000, "тыщи": 1000, "тыщ": 1000,
        // Millions
        "миллион": 1_000_000, "миллиона": 1_000_000, "миллионов": 1_000_000,
        "млн": 1_000_000,
    ]

    // MARK: - English

    private static let english: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "thirty": 30, "forty": 40, "fourty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
        "hundred": 100, "thousand": 1000, "million": 1_000_000,
    ]

    // MARK: - Spanish

    private static let spanish: [String: Int] = [
        "cero": 0, "uno": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
        "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10,
        "once": 11, "doce": 12, "trece": 13, "catorce": 14, "quince": 15,
        "dieciséis": 16, "dieciseis": 16, "diecisiete": 17, "dieciocho": 18, "diecinueve": 19,
        "veinte": 20, "veintiuno": 21, "veintidós": 22, "veintidos": 22,
        "veintitrés": 23, "veintitres": 23, "veinticuatro": 24, "veinticinco": 25,
        "veintiséis": 26, "veintiseis": 26, "veintisiete": 27, "veintiocho": 28, "veintinueve": 29,
        "treinta": 30, "cuarenta": 40, "cincuenta": 50,
        "sesenta": 60, "setenta": 70, "ochenta": 80, "noventa": 90,
        "cien": 100, "ciento": 100, "doscientos": 200, "trescientos": 300,
        "cuatrocientos": 400, "quinientos": 500, "seiscientos": 600,
        "setecientos": 700, "ochocientos": 800, "novecientos": 900,
        "mil": 1000, "millón": 1_000_000, "millon": 1_000_000,
    ]

    // MARK: - German

    private static let german: [String: Int] = [
        "null": 0, "eins": 1, "ein": 1, "eine": 1, "zwei": 2, "drei": 3, "vier": 4,
        "fünf": 5, "funf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9, "zehn": 10,
        "elf": 11, "zwölf": 12, "zwolf": 12, "dreizehn": 13, "vierzehn": 14,
        "fünfzehn": 15, "funfzehn": 15, "sechzehn": 16, "siebzehn": 17, "achtzehn": 18, "neunzehn": 19,
        "zwanzig": 20, "dreißig": 30, "dreissig": 30, "vierzig": 40, "fünfzig": 50, "funfzig": 50,
        "sechzig": 60, "siebzig": 70, "achtzig": 80, "neunzig": 90,
        "hundert": 100, "tausend": 1000, "million": 1_000_000,
    ]

    // MARK: - French

    private static let french: [String: Int] = [
        "zéro": 0, "zero": 0, "un": 1, "une": 1, "deux": 2, "trois": 3,
        "quatre": 4, "cinq": 5, "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        "onze": 11, "douze": 12, "treize": 13, "quatorze": 14, "quinze": 15,
        "seize": 16, "dix-sept": 17, "dix-huit": 18, "dix-neuf": 19,
        "vingt": 20, "trente": 30, "quarante": 40, "cinquante": 50,
        "soixante": 60, "soixante-dix": 70, "quatre-vingts": 80, "quatre-vingt": 80,
        "quatre-vingt-dix": 90,
        "cent": 100, "cents": 100, "mille": 1000, "million": 1_000_000,
    ]

    // MARK: - Portuguese (Brazil)

    private static let portuguese: [String: Int] = [
        "zero": 0, "um": 1, "uma": 1, "dois": 2, "duas": 2, "três": 3, "tres": 3,
        "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10,
        "onze": 11, "doze": 12, "treze": 13, "quatorze": 14, "catorze": 14, "quinze": 15,
        "dezesseis": 16, "dezessete": 17, "dezoito": 18, "dezenove": 19,
        "vinte": 20, "trinta": 30, "quarenta": 40, "cinquenta": 50,
        "sessenta": 60, "setenta": 70, "oitenta": 80, "noventa": 90,
        "cem": 100, "cento": 100, "duzentos": 200, "trezentos": 300,
        "quatrocentos": 400, "quinhentos": 500, "seiscentos": 600,
        "setecentos": 700, "oitocentos": 800, "novecentos": 900,
        "mil": 1000, "milhão": 1_000_000, "milhao": 1_000_000,
    ]

    // MARK: - Japanese

    private static let japanese: [String: Int] = [
        "ゼロ": 0, "零": 0, "いち": 1, "一": 1, "に": 2, "二": 2,
        "さん": 3, "三": 3, "よん": 4, "し": 4, "四": 4,
        "ご": 5, "五": 5, "ろく": 6, "六": 6, "なな": 7, "しち": 7, "七": 7,
        "はち": 8, "八": 8, "きゅう": 9, "く": 9, "九": 9, "じゅう": 10, "十": 10,
        "ひゃく": 100, "百": 100, "せん": 1000, "千": 1000, "まん": 10_000, "万": 10_000,
    ]

    // MARK: - Chinese (Simplified)

    private static let chinese: [String: Int] = [
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
        "百": 100, "千": 1000, "万": 10_000,
    ]
}
