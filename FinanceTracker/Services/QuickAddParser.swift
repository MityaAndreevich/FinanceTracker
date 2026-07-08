//
//  QuickAddParser.swift
//  FinanceTracker
//
//  Natural-language amount parser for the Quick Add bar.
//  Parses a free-text string like "$5.50 Starbucks" or "12,99 spotify" into a
//  structured QuickAddParsedInput. All logic is on-device; no data leaves the device.
//

import Foundation

struct QuickAddParsedInput: Equatable {
    let amountCents: Int
    let typeRaw: String           // "income" | "expense"
    let merchant: String?
    let suggestedCategoryName: String?

    /// Heuristic 0...1 confidence in the parse, used to decide whether Quick Add
    /// can commit immediately (Q1 option C) or should surface a preview for the
    /// user to confirm. Weighting: amount detected +0.4, a real merchant +0.3,
    /// a concrete (non-"Other", non-nil) category +0.3.
    var confidence: Double {
        var score = 0.0
        if amountCents > 0 { score += 0.4 }
        if let m = merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            score += 0.3
        }
        if let c = suggestedCategoryName?.lowercased(), !c.isEmpty, c != "other" {
            score += 0.3
        }
        return score
    }

    /// At or above this, Quick Add saves immediately and offers an edit toast
    /// instead of showing a confirmation preview.
    static let highConfidenceThreshold = 0.75
}

enum QuickAddParser {

    // MARK: - Public

    static func parse(_ raw: String) -> QuickAddParsedInput? {
        let stripped = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }

        // Pre-process spelled-out numbers to digits using the user's app language.
        // iOS dictation spells out numbers ("семь" not "7") in most locales, which
        // would otherwise leave the amount regex with nothing to match.
        let langCode = UserDefaults.standard.string(forKey: "appLanguageCode") ?? "system"
        // Bug 2: try the app language first, then all supported locales, so mixed
        // language input (e.g. RU UI + spoken English "fifteen") still parses.
        let normalizedWords = NumberWordsParser.normalize(stripped, primaryLocale: langCode)
        // Collapse locale grouping spaces inside numbers ("10 143,15" → "10143,15")
        // so the amount tokenizer sees one contiguous value instead of two numbers.
        let input = collapseGroupingSpaces(in: normalizedWords)
        guard !input.isEmpty else { return nil }

        // 1. Detect amount — locale-aware tokenizer with smart multi-number selection
        //    ("bought 3 eggs for 7" captures the price 7, not the quantity 3) and
        //    major+minor unit combination ("1342 рубля 15 копеек" → 1342.15).
        let convention = DecimalConvention.current()
        guard let cents = detectAmountCents(in: input, convention: convention), cents > 0 else { return nil }

        // 2. Detect type — explicit "+" prefix or income vocabulary (verb OR noun).
        let lower = input.lowercased()
        let isIncome = input.hasPrefix("+")
            || verbIncomeKeywords.contains { lower.contains($0) }
            || nounIncomeKeywords.contains { lower.contains($0) }
        let typeRaw = isIncome ? "income" : "expense"

        // 3. Extract merchant text. Strip ALL number tokens (the chosen amount plus
        //    stray quantities), "+", and currency symbols. Income *verbs* are always
        //    stripped. Income *nouns* are removed only when a real merchant remains
        //    (e.g. the payer in "зп от Сбербанк" → "Сбербанк"); when the noun is the
        //    only content it is kept so the transaction still has a description
        //    ("зп" → "зп" instead of an empty merchant).
        var base = input.replacingOccurrences(of: "+", with: "")
        base = base.replacingOccurrences(of: amountTokenPattern, with: " ", options: .regularExpression)
        for sym in currencySymbols {
            base = base.replacingOccurrences(of: String(sym), with: "")
        }
        var verbStripped = base
        for keyword in verbIncomeKeywords {
            verbStripped = verbStripped.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }
        var nounStripped = verbStripped
        for keyword in nounIncomeKeywords {
            nounStripped = nounStripped.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }
        // Strip standalone currency words ("баксов", "dollars", "euros", "reais")
        // and expense-indicator words ("расход", "expense", "gasto") so "50 баксов
        // за кофе" yields merchant "кофе" and "50 расход" yields no merchant — not
        // the literal word "расход". normalizeMerchant then drops dangling prepositions.
        let nounWordsStripped = stripWholeWords(noiseWordsToStrip, from: nounStripped)
        let verbWordsStripped = stripWholeWords(noiseWordsToStrip, from: verbStripped)
        let cleanMerchant = normalizeMerchant(nounWordsStripped)
        let merchantText = cleanMerchant.isEmpty ? normalizeMerchant(verbWordsStripped) : cleanMerchant
        // Bug 5 (P0): capitalize first letter of merchant so voice-added rows read like
        // proper labels ("Кофе"/"Coffee" instead of "кофе"/"coffee"). Done at the last
        // step so trailing-preposition / orphan-conjunction stripping isn't affected by
        // the case. We deliberately do NOT use `.capitalized` — that would lowercase
        // the rest of the word and break brand names like "iPhone" → "Iphone".
        let merchant: String? = merchantText.isEmpty ? nil : merchantText.capitalizedFirst

        // 4. Suggest category. The taxonomy has a single income category, so any
        //    income transaction maps to "Income" rather than falling back to "Other"
        //    or borrowing an expense category. Expenses use the merchant lookup.
        let suggestedCategoryName: String?
        if isIncome {
            suggestedCategoryName = "Income"
        } else {
            suggestedCategoryName = merchant.flatMap { CategorySuggestionService.suggest(forMerchant: $0) }
        }

        return QuickAddParsedInput(
            amountCents: cents,
            typeRaw: typeRaw,
            merchant: merchant,
            suggestedCategoryName: suggestedCategoryName
        )
    }

    /// True when `text` signals income — a leading "+" or any income verb/noun
    /// in the supported vocabularies. Exposed for the App Intent (Bug 8), which
    /// builds a transaction from structured parameters but must still apply the
    /// same income heuristics so e.g. "paycheck" isn't filed as an expense.
    static func isIncome(_ text: String) -> Bool {
        let lower = text.lowercased()
        return text.hasPrefix("+")
            || verbIncomeKeywords.contains { lower.contains($0) }
            || nounIncomeKeywords.contains { lower.contains($0) }
    }

    // MARK: - Amount detection

    /// Decimal formatting convention of the user's *regional* locale (independent of
    /// the in-app UI language). Disambiguates the one genuinely ambiguous shape — a
    /// lone separator followed by exactly three digits ("1.234" / "1,234") — which
    /// could be thousands-grouping OR a decimal depending on locale. Every other
    /// shape resolves purely by position (see `parseTokenCents`).
    enum DecimalConvention {
        case comma   // decimal ",", grouping space/NBSP/"."  (ru, uk, pt-BR, es-ES, de, fr…)
        case period  // decimal ".", grouping space/NBSP/","  (en-US, es-MX…)

        static func current() -> DecimalConvention {
            Locale.current.decimalSeparator == "," ? .comma : .period
        }
    }

    /// Currency glyphs stripped when isolating the numeric value of a token.
    private static let currencySymbols = "$€£¥₽₴¢"

    /// A single amount token: optional currency glyph, optional leading decimal
    /// separator, then digits with internal grouping/decimal separators. Matches
    /// "10143,15", "10,143.15", "1.234,56", "$1,342.15", ",15" and bare "50".
    /// Grouping *spaces* are collapsed beforehand (see `collapseGroupingSpaces`),
    /// so this pattern never has to span a space and can't merge two numbers.
    /// Whitespace is consumed only when a currency glyph precedes it ("$ 10,50"),
    /// so a bare number's start offset is its true position — critical for the
    /// major/minor pairing, which compares token offsets to the minor number.
    private static let amountTokenPattern =
        #"(?:[$€£¥₽₴¢]\s*)?(?:[.,]?\d[\d.,]*\d|[.,]?\d)"#

    /// Numeric tokens (amount + kopecks + stray quantities) with values resolved
    /// under `convention`. Minor-unit words like "копеек"/"cents" combine two of
    /// these into a single amount (see `combineMajorMinor`).
    private struct NumberCandidate {
        let cents: Int
        let startOffset: Int
        let hasCurrencySymbol: Bool
    }

    /// Minor-unit words (kopecks / cents / centavos) that turn a trailing integer
    /// into the fractional part of the amount. The negative look-ahead prevents
    /// "center"/"copil" style false positives; bare "коп"/"cent" are covered by
    /// dedicated alternatives so "50 коп" and "5 cents" both fire.
    private static let minorUnitPattern =
        #"(\d+)\s*(?:копе\p{L}*|копі\p{L}*|коп|cents?|centavos?|c[eé]ntimos?|¢)(?![\p{L}])"#

    /// Picks the most likely transaction amount from inputs that may contain several
    /// numbers. Priority:
    ///   0. Major + minor currency units ("1342 рубля 15 копеек", "12 dollars 5 cents")
    ///   1. Number immediately after a price-marker preposition (for, за, at, по, à, por, für)
    ///   2. Number adjacent to a currency symbol ($, €, £, ¥, ₽, ₴, ¢)
    ///   3. Last number (often the price in "5 apples 12 dollars")
    ///   4. First number (fallback — original single-number behaviour)
    private static func detectAmountCents(in input: String, convention: DecimalConvention) -> Int? {
        let candidates = numberCandidates(in: input, convention: convention)
        guard !candidates.isEmpty else { return nil }

        // Heuristic 0: combine major + minor currency units into one amount.
        if let combined = combineMajorMinor(in: input, candidates: candidates) {
            return combined
        }

        // Heuristic 1: number after a price-marker preposition.
        // "на" ("продукты на 100") works like "за" for amount selection.
        let pricePrepositions = [" for ", " за ", " на ", " at ", " по ", " à ", " por ", " für "]
        let lower = input.lowercased()
        for prep in pricePrepositions {
            if let prepRange = lower.range(of: prep) {
                let prepEnd = lower.distance(from: lower.startIndex, to: prepRange.upperBound)
                if let afterPrep = candidates.first(where: { $0.startOffset >= prepEnd }) {
                    return afterPrep.cents
                }
            }
        }

        // Heuristic 2: number adjacent to a currency symbol
        if let withSymbol = candidates.first(where: { $0.hasCurrencySymbol }) {
            return withSymbol.cents
        }

        // Heuristic 3: multiple numbers — use the LAST (likely the price after a count)
        if candidates.count >= 2, let last = candidates.last {
            return last.cents
        }

        // Heuristic 4: single number fallback
        return candidates[0].cents
    }

    /// Locale-aware amount tokenizer. Given a raw NL fragment and the regional
    /// decimal convention, returns the transaction amount in cents (or nil).
    /// Exposed for the parse-table tests; the full `parse` pipeline routes through
    /// the same code after spelled-out-number normalization.
    static func amountCents(from raw: String, convention: DecimalConvention) -> Int? {
        detectAmountCents(in: collapseGroupingSpaces(in: raw), convention: convention)
    }

    /// Extracts numeric token candidates in reading order.
    private static func numberCandidates(in input: String, convention: DecimalConvention) -> [NumberCandidate] {
        guard let regex = try? NSRegularExpression(pattern: amountTokenPattern) else { return [] }
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.matches(in: input, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: input) else { return nil }
            let substring = String(input[range])
            guard let cents = parseTokenCents(substring, convention: convention), cents > 0 else { return nil }
            let startOffset = input.distance(from: input.startIndex, to: range.lowerBound)
            let hasSymbol = substring.contains { currencySymbols.contains($0) }
            return NumberCandidate(cents: cents, startOffset: startOffset, hasCurrencySymbol: hasSymbol)
        }
    }

    /// If a minor-unit word ("копеек"/"cents"/"centavos") is present, treat the
    /// integer before it as the fractional part and the preceding number as the
    /// major amount: "1342 рубля 15 копеек" → 1342 + 15/100 → 134215¢; a lone
    /// "50 коп" → 50¢. Returns nil when no minor-unit word is found.
    private static func combineMajorMinor(in input: String, candidates: [NumberCandidate]) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: minorUnitPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..<input.endIndex, in: input)),
              let numberRange = Range(match.range(at: 1), in: input) else { return nil }

        // Minor units map 1:1 to cents (15 kopecks = 15¢); cap at two digits.
        let minorDigits = String(input[numberRange]).prefix(2)
        let minorCents = Int(minorDigits) ?? 0
        let minorStart = input.distance(from: input.startIndex, to: numberRange.lowerBound)

        // Major amount = the last numeric token that starts before the minor number.
        if let major = candidates.last(where: { $0.startOffset < minorStart }) {
            return major.cents + minorCents
        }
        return minorCents
    }

    /// Collapses locale grouping *spaces* that sit inside a number so the token
    /// regex sees one contiguous value: "10 143,15" → "10143,15", "1 000 000" →
    /// "1000000". Only fires on a digit run followed by one-or-more space+3-digit
    /// groups, so word-separated numbers ("1342 рубля 15 копеек") are untouched.
    private static func collapseGroupingSpaces(in text: String) -> String {
        let pattern = #"\d{1,3}(?:[\u00A0\u202F ]\d{3})+(?:[.,]\d{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = 0
        for m in matches {
            result += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
            result += ns.substring(with: m.range)
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
                .replacingOccurrences(of: " ", with: "")
            lastEnd = m.range.location + m.range.length
        }
        result += ns.substring(from: lastEnd)
        return result
    }

    // MARK: - Private

    // MARK: - Income keyword taxonomy
    //
    // VERBS describe the act of receiving (получил, got paid, earned, recibí…).
    // They are STRIPPED from merchant text since they're actions, not the thing earned.
    //
    // NOUNS describe what was received (зп, зарплата, salary, bonus…).
    // They are KEPT in merchant text so the transaction has a meaningful description.
    //
    // Either list firing flags the transaction as income.

    private static let verbIncomeKeywords = [
        // English — "found" covers found money (Bug 2: a windfall is income).
        "earned", "received", "got paid", "won", "made", "sold", "found",
        // Russian. Bug 2 (device test #3): "выйграла 100" filed as an expense
        // because no win/found verb existed. Substring matching means the masculine
        // root also catches -ла/-ли ("выиграл" → "выиграла"/"выиграли"); the common
        // "выйграл" misspelling (extra й) is listed explicitly.
        "заработал", "заработала", "получил", "получила", "зачислено",
        "пришло", "пришла", "пришёл", "вернули", "перевели",
        "продал", "продала", "продаю", "продали",
        "выиграл", "выйграл", "нашёл", "нашел", "нашла", "нашли",
        // Voice transliterations (SFSpeechRecognizer EN locale on RU speech)
        "poluchil", "poluchila", "vyigral", "vyigrala",
        // Spanish — add 1st/3rd-person & accent-free conjugations (Bug 2)
        "gané", "gane", "ganó", "gano", "ganamos", "recibí", "cobré",
        "encontré", "encontre", "vendí", "vendió",
        // German
        "verdient", "bekommen", "erhalten", "gutgeschrieben", "verkauft", "verkaufte",
        // French
        "gagné", "reçu", "touché", "perçu", "vendu", "vendue",
        // Portuguese (Brazil) — add 3rd-person & plural conjugations (Bug 2)
        "ganhei", "ganhou", "ganhamos", "recebi", "encontrei", "caiu", "pingou",
        "vendi", "vendeu",
        // Japanese
        "稼いだ", "もらった", "入った", "振り込まれた", "売った", "売却",
        // Chinese (Simplified)
        "赚了", "收到", "到账", "入账", "卖了", "卖出",
    ]

    private static let nounIncomeKeywords = [
        // English
        "paycheck", "salary", "income", "refund", "bonus", "freelance",
        "deposit", "interest", "dividend", "cashback", "payout",
        "reimbursement", "commission", "prize", "lottery",
        // Russian. "выигрыш"/"выйгрыш" (Bug 2) + lottery noun so a bare
        // "лотерея 100" reads as income even without a win verb.
        "зарплата", "зп", "з/п", "доход", "перевод", "премия", "аванс", "выплата",
        "донат", "чаевые", "возврат", "кэшбэк", "кешбэк",
        "выигрыш", "выйгрыш", "лотерея",
        // Voice transliterations
        "zarplata", "premia", "premiia", "avans", "zp",
        // Spanish
        "salario", "sueldo", "paga", "nómina", "ingreso", "reembolso", "bono",
        "devolución", "propina", "premio", "lotería", "loteria",
        // German
        "gehalt", "lohn", "einnahme", "rückzahlung",
        // French
        "salaire", "paie", "revenu", "remboursement", "prime", "remise",
        // Portuguese (Brazil)
        "salário", "pagamento", "renda", "bônus", "devolução",
        "prêmio", "premio", "loteria",
        // Japanese
        "給料", "給与", "ボーナス", "返金", "副業", "入金", "キャッシュバック",
        // Chinese (Simplified)
        "工资", "薪水", "奖金", "退款", "报销", "自由职业", "现金回赠",
    ]

    /// Words to strip from extracted merchant text after income keyword detection.
    /// E.g. "заработал на Амазон" → merchant should be "Амазон", not "на Амазон".
    /// Longer prefixes listed before shorter ones to prevent partial matches (e.g. "desde" before "de").
    private static let merchantPrefixesToStrip = [
        // Russian
        "на ", "от ", "из ", "в ", "за ", "по ",
        // English
        "from ", "via ", "on ", "at ", "by ", "for ",
        // Spanish / Portuguese-BR / French — longer prefixes first
        "desde ", "depuis ", "de ", "en ", "por ", "do ", "da ", "na ", "no ", "em ", "à ", "par ",
        // Spanish / Portuguese articles ("tomé un café" → "café", "tomei um café" → "café").
        // Bug 1 (P0): the verb is whole-word-stripped by stripWholeWords, but the
        // dangling article "un"/"um" survived into the merchant.
        "un ", "una ", "unos ", "unas ",   // Spanish
        "um ", "uma ", "uns ", "umas ",    // Portuguese
        // German
        "von ", "bei ", "aus ", "an ",
        // Japanese
        "から", "で",
        // Chinese (Simplified)
        "从", "在", "由",
        // Orphan conjunctions that can leak after a verb-keyword strip
        // ("получил а зарплату" → "а зарплату" → "зарплату").
        "а ", "и ", "но ", "то ",       // Russian
        "and ", "or ", "but ",          // English
        "y ", "o ", "pero ",            // Spanish
        "e ", "ou ", "mas ",            // Portuguese
    ]

    /// Prepositions that can dangle at the END of a merchant once the amount that
    /// followed them has been removed ("продал яйца за 7" → "яйца за" → "яйца").
    private static let merchantSuffixesToStrip = [
        " за", " от", " из", " в", " по", " на",   // Russian
        " for", " from", " at", " by", " via", " on",  // English
        " por", " de", " en", " desde",            // Spanish
        " em",                                      // Portuguese
    ]

    /// Spelled-out currency words that, like a "$" symbol, name the unit rather than
    /// the merchant. Stripped from merchant text after the amount is removed so the
    /// description is the thing bought ("кофе"), not the currency ("баксов за кофе").
    /// Listed longest-first within each language is unnecessary because word-boundary
    /// matching prevents one entry from clobbering a longer one ("доллар" won't match
    /// inside "долларов").
    private static let currencyWordsToStrip = [
        // RU — "р" is the bare ruble abbreviation ("молоко 50р" → "молоко").
        "баксов", "баксы", "бакс", "долларов", "доллары", "доллар",
        "евро", "евра", "рублей", "рубля", "рублях", "рубли", "рубль", "руб", "р",
        "юаней", "юаня", "юань",
        // RU/UK minor units (kopecks) — combined into the amount, then stripped here.
        "копеек", "копейки", "копейка", "копейку", "коп",
        "копійок", "копійки", "копійка", "копійку",
        // UK major unit (hryvnia)
        "гривень", "гривні", "гривня", "грн",
        // EN
        "dollars", "dollar", "bucks", "buck",
        "euros", "euro", "pounds", "pound",
        "rubles", "ruble", "cents", "cent",
        // ES
        "dólares", "dolares", "dólar", "dolar", "pesos", "peso",
        "centavos", "centavo", "céntimos", "céntimo", "centimos", "centimo",
        // PT
        "reais", "real",
    ]

    /// Bare expense-indicator words ("50 расход" = "50, an expense"). Expense is
    /// already the default type, so these only need removing from merchant text —
    /// they describe direction, not a payee.
    private static let expenseIndicatorWords = [
        // RU
        "расходы", "расход", "расхода", "траты", "трата",
        // EN
        "expenses", "expense",
        // ES
        "gastos", "gasto",
        // PT
        "despesas", "despesa",
    ]

    /// Expense transaction verbs/lead-in nouns ("купил молоко за 15" → "молоко",
    /// "bought milk for 12" → "milk", "compré leche por 12" → "leche"). Unlike income
    /// verbs these don't change the type (expense is the default) — they only describe
    /// the *act* of spending, not the thing bought, so they're stripped from merchant
    /// text via stripWholeWords (whole-word, case-insensitive). Income-side phrases that
    /// reuse the same root ("got paid") are stripped earlier by verbIncomeKeywords, so
    /// listing "got"/"paid" here can't change a transaction's income/expense type.
    private static let expenseVerbKeywords = [
        // Russian — "взял/взяла/взяли" added per Bug 1 (P0): "Взял кофе за 20"
        // was leaking the verb into the merchant ("взял кофе") because it wasn't
        // in this strip list. Case is handled by stripWholeWords's regex flag.
        "купил", "купила", "купили",
        "взял", "взяла", "взяли",
        "потратил", "потратила", "потратили", "потратился",
        "заплатил", "заплатила", "заплатили",
        "оплатил", "оплатила", "оплатили", "оплата", "оплату",
        "приобрёл", "приобрел", "приобрела", "приобрели",
        "отдал", "отдала", "отдали",
        // English
        "bought", "paid", "spent", "purchased", "got",
        // Spanish — "tomé/tomó/tomamos" cover "Tomé un café" / "Tomamos cerveza".
        "compré", "compre", "pagué", "pague", "gasté", "gaste", "aboné", "abone", "adquirí", "adquiri",
        "tomé", "tome", "tomó", "tomo", "tomamos",
        // Portuguese (Brazil) — "tomei/tomou/tomamos" cover "Tomei um café".
        "comprei", "paguei", "gastei", "adquiri",
        "tomei", "tomou",
    ]

    private static let noiseWordsToStrip = currencyWordsToStrip + expenseIndicatorWords + expenseVerbKeywords

    /// Removes whole words from `words` (case-insensitive, Unicode word boundaries
    /// so Cyrillic matches) and leaves a space so adjacent words don't merge.
    private static func stripWholeWords(_ words: [String], from text: String) -> String {
        var s = text
        for word in words {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: " ")
        }
        return s
    }

    /// Collapses whitespace, trims, and strips a single leading preposition and a
    /// single trailing preposition.
    /// "  desde Empresa " → "Empresa", "от Сбербанк" → "Сбербанк", "яйца за" → "яйца".
    private static func normalizeMerchant(_ text: String) -> String {
        // Trim whitespace AND edge punctuation. iOS dictation appends a sentence
        // period ("купил молоко за 15 руб." → "молоко ."), and the bare period
        // otherwise survives into the description. Internal punctuation (e.g. "AT&T",
        // "7-eleven") is preserved — only leading/trailing marks are trimmed.
        let trimChars = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        var s = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimChars)
        let lower = s.lowercased()
        for prefix in merchantPrefixesToStrip where lower.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count)).trimmingCharacters(in: trimChars)
            break
        }
        // Trailing prepositions can stack once the amount and a multi-word number
        // are removed ("за пять тыщ" → "за 5000" → "за"), so iterate until stable.
        var strippedSuffix = true
        while strippedSuffix {
            strippedSuffix = false
            let lowerNow = s.lowercased()
            for suffix in merchantSuffixesToStrip where lowerNow.hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count)).trimmingCharacters(in: trimChars)
                strippedSuffix = true
                break
            }
        }
        return s
    }

    /// Converts one numeric token to cents via the shared `AmountParsing` core,
    /// supplying the decimal separator from the user's locale convention. The core
    /// identifies the decimal by position and treats every other separator as
    /// grouping, so this stays robust to mixed shapes:
    ///   "10143,15" → 1014315   "10,143.15" → 1014315   "1.234,56" → 123456
    ///   "$1,342.15" → 134215   ",15" → 15   "1000" → 100000
    private static func parseTokenCents(_ token: String, convention: DecimalConvention) -> Int? {
        AmountParsing.parseCents(token, decimalSeparator: convention == .comma ? "," : ".")
    }
}

// MARK: - String capitalization helper

private extension String {
    /// Returns the string with the first character uppercased; the remainder is
    /// preserved verbatim. Unlike `.capitalized`, this does NOT lowercase
    /// mid-word characters, so brand names like "iPhone" and acronyms like
    /// "AT&T" survive intact.
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
