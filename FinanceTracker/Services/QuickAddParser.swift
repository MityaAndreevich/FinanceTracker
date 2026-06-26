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
}

enum QuickAddParser {

    // MARK: - Public

    static func parse(_ raw: String) -> QuickAddParsedInput? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        // 1. Detect amount — smart multi-number selection so "bought 3 eggs for 7"
        //    captures the price (7), not the quantity (3). See detectAmountCents.
        guard let (cents, _) = detectAmountCents(in: input), cents > 0 else { return nil }

        // 2. Detect type — explicit "+" prefix or income vocabulary
        let lower = input.lowercased()
        let isIncome = input.hasPrefix("+") || incomeKeywords.contains { lower.contains($0) }
        let typeRaw = isIncome ? "income" : "expense"

        // 3. Extract merchant text — strip ALL number tokens (the chosen amount plus
        //    stray quantities), "+", currency symbols, and income keywords.
        var merchantText = input.replacingOccurrences(of: "+", with: "")
        merchantText = merchantText.replacingOccurrences(
            of: amountRegexPattern, with: " ", options: .regularExpression
        )
        for sym in "$€£¥₽" {
            merchantText = merchantText.replacingOccurrences(of: String(sym), with: "")
        }
        for keyword in incomeKeywords {
            merchantText = merchantText.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }
        merchantText = merchantText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading prepositions left over after keyword removal.
        // "на Амазон" → "Амазон", "from Amazon" → "Amazon"
        let lowerMerchant = merchantText.lowercased()
        for prefix in merchantPrefixesToStrip where lowerMerchant.hasPrefix(prefix) {
            merchantText = String(merchantText.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        let merchant: String? = merchantText.isEmpty ? nil : merchantText

        // 4. Suggest category using the existing on-device lookup table
        let suggestedCategoryName = merchant.flatMap { CategorySuggestionService.suggest(forMerchant: $0) }

        return QuickAddParsedInput(
            amountCents: cents,
            typeRaw: typeRaw,
            merchant: merchant,
            suggestedCategoryName: suggestedCategoryName
        )
    }

    // MARK: - Amount detection

    /// Regex for a single amount token: optional currency symbol, then a number
    /// supporting both "5.50"/"1,234.56" and European "12,99"/"1.234,56".
    private static let amountRegexPattern = #"[$€£¥₽]?\s*\d{1,3}(?:[,.\s]\d{3})*[,.]?\d{0,2}"#

    /// Picks the most likely transaction amount from inputs that may contain several
    /// numbers (e.g. "bought 3 eggs for 7"). Heuristic priority:
    ///   1. Number immediately after a price-marker preposition (for, за, at, по, à, por, für)
    ///   2. Number adjacent to a currency symbol ($, €, £, ¥, ₽)
    ///   3. Last number (often the price in "5 apples 12 dollars")
    ///   4. First number (fallback — original single-number behaviour)
    private static func detectAmountCents(in input: String) -> (cents: Int, matchedSubstring: String)? {
        struct Candidate {
            let substring: String
            let startOffset: Int
            let cents: Int
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let regex = try? NSRegularExpression(pattern: amountRegexPattern) else { return nil }
        let matches = regex.matches(in: input, range: nsRange)

        let candidates: [Candidate] = matches.compactMap { match in
            guard let range = Range(match.range, in: input) else { return nil }
            let substring = String(input[range])
            guard let cents = parseAmountCents(from: substring), cents > 0 else { return nil }
            let startOffset = input.distance(from: input.startIndex, to: range.lowerBound)
            return Candidate(substring: substring, startOffset: startOffset, cents: cents)
        }
        guard !candidates.isEmpty else { return nil }

        // Heuristic 1: number after a price-marker preposition
        let pricePrepositions = [" for ", " за ", " at ", " по ", " à ", " por ", " für "]
        let lower = input.lowercased()
        for prep in pricePrepositions {
            if let prepRange = lower.range(of: prep) {
                let prepEnd = lower.distance(from: lower.startIndex, to: prepRange.upperBound)
                if let afterPrep = candidates.first(where: { $0.startOffset >= prepEnd }) {
                    return (afterPrep.cents, afterPrep.substring)
                }
            }
        }

        // Heuristic 2: number adjacent to a currency symbol
        if let withSymbol = candidates.first(where: { $0.substring.contains { "$€£¥₽".contains($0) } }) {
            return (withSymbol.cents, withSymbol.substring)
        }

        // Heuristic 3: multiple numbers — use the LAST (likely the price after a count)
        if candidates.count >= 2, let last = candidates.last {
            return (last.cents, last.substring)
        }

        // Heuristic 4: single number fallback
        let first = candidates[0]
        return (first.cents, first.substring)
    }

    // MARK: - Private

    private static let incomeKeywords = [
        // English — formal + conversational
        "paycheck", "salary", "income", "refund", "bonus", "freelance",
        "deposit", "interest", "dividend", "earned", "received", "cashback",
        "payout", "reimbursement", "got paid", "won", "made", "sold", "commission",
        // Russian — formal
        "зарплата", "зп", "з/п", "доход", "перевод", "премия", "аванс", "выплата",
        "донат", "чаевые", "перевели",
        // Russian — conversational verbs (past tense, the natural way users type)
        "заработал", "заработала", "получил", "получила", "зачислено",
        "пришло", "пришла", "пришёл", "вернули", "возврат", "кэшбэк", "кешбэк",
        "продал", "продала", "продаю", "продали",
        // Voice transliterations (SFSpeechRecognizer EN locale on RU speech)
        "poluchil", "poluchila", "zarplata", "premia", "premiia", "avans", "zp",
        // Spanish
        "salario", "sueldo", "paga", "nómina", "ingreso", "reembolso", "bono",
        "gané", "recibí", "cobré", "devolución", "propina", "vendí", "vendió",
        // German
        "gehalt", "lohn", "einnahme", "verdient", "bekommen", "erhalten",
        "gutgeschrieben", "rückzahlung", "verkauft", "verkaufte",
        // French
        "salaire", "paie", "revenu", "remboursement", "prime",
        "gagné", "reçu", "touché", "perçu", "remise", "vendu", "vendue",
        // Portuguese (Brazil)
        "salário", "pagamento", "renda", "bônus",
        "ganhei", "recebi", "caiu", "pingou", "devolução", "vendi", "vendeu",
        // Japanese
        "給料", "給与", "ボーナス", "返金", "副業", "入金",
        "稼いだ", "もらった", "入った", "振り込まれた", "キャッシュバック", "売った", "売却",
        // Chinese (Simplified)
        "工资", "薪水", "奖金", "退款", "报销", "自由职业",
        "赚了", "收到", "到账", "入账", "现金回赠", "卖了", "卖出",
    ]

    /// Words to strip from extracted merchant text after income keyword detection.
    /// E.g. "заработал на Амазон" → merchant should be "Амазон", not "на Амазон".
    /// Longer prefixes listed before shorter ones to prevent partial matches (e.g. "desde" before "de").
    private static let merchantPrefixesToStrip = [
        // Russian
        "на ", "от ", "из ", "в ", "за ", "по ",
        // English
        "from ", "via ", "on ", "at ", "by ",
        // Spanish / Portuguese-BR / French — longer prefixes first
        "desde ", "depuis ", "de ", "en ", "por ", "do ", "da ", "em ", "à ", "par ",
        // German
        "von ", "bei ", "aus ", "an ",
        // Japanese
        "から", "で",
        // Chinese (Simplified)
        "从", "在", "由",
    ]

    /// Handles both standard ("5.50", "1,234.56") and European ("12,99", "1.234,56") formats.
    private static func parseAmountCents(from raw: String) -> Int? {
        var s = raw.filter { !"$€£¥₽ ".contains($0) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // European: number ends with ,XX or ,X (e.g. "12,99" or "1.234,56")
        // The diagnostic is a comma followed by 1–2 digits at the very end.
        let euroPattern = #"^\d{1,3}(?:\.\d{3})*,\d{1,2}$"#
        if s.range(of: euroPattern, options: .regularExpression) != nil {
            s = s.replacingOccurrences(of: ".", with: "")   // remove thousands dots
            s = s.replacingOccurrences(of: ",", with: ".")  // decimal comma → dot
        } else {
            s = s.replacingOccurrences(of: ",", with: "")   // remove thousands commas
        }

        return Money.parseCents(from: s)
    }
}
