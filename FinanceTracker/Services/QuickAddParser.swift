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

        // 1. Detect amount — supports "$5.50", "12,99", "1,234.56", "1.234,56", etc.
        let amountRegex = #"[$€£¥₽]?\s*\d{1,3}(?:[,.\s]\d{3})*[,.]?\d{0,2}"#
        guard let amountRange = input.range(of: amountRegex, options: .regularExpression) else { return nil }
        let amountString = String(input[amountRange])
        guard let cents = parseAmountCents(from: amountString), cents > 0 else { return nil }

        // 2. Detect type — explicit "+" prefix or income vocabulary
        let lower = input.lowercased()
        let isIncome = input.hasPrefix("+") || incomeKeywords.contains { lower.contains($0) }
        let typeRaw = isIncome ? "income" : "expense"

        // 3. Extract merchant text — strip amount, "+", currency symbols, and income keywords
        var merchantText = input
            .replacingOccurrences(of: amountString, with: "")
            .replacingOccurrences(of: "+", with: "")
        for sym in "$€£¥₽" {
            merchantText = merchantText.replacingOccurrences(of: String(sym), with: "")
        }
        for keyword in incomeKeywords {
            merchantText = merchantText.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }
        merchantText = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)

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
        // Voice transliterations (SFSpeechRecognizer EN locale on RU speech)
        "poluchil", "poluchila", "zarplata", "premia", "premiia", "avans", "zp",
        // Spanish
        "salario", "sueldo", "paga", "nómina", "ingreso", "reembolso", "bono",
        "gané", "recibí", "cobré", "devolución", "propina",
        // German
        "gehalt", "lohn", "einnahme", "verdient", "bekommen", "erhalten",
        "gutgeschrieben", "rückzahlung",
        // French
        "salaire", "paie", "revenu", "remboursement", "prime",
        "gagné", "reçu", "touché", "perçu", "remise",
        // Portuguese (Brazil)
        "salário", "pagamento", "renda", "bônus",
        "ganhei", "recebi", "caiu", "pingou", "devolução",
        // Japanese
        "給料", "給与", "ボーナス", "返金", "副業", "入金",
        "稼いだ", "もらった", "入った", "振り込まれた", "キャッシュバック",
        // Chinese (Simplified)
        "工资", "薪水", "奖金", "退款", "报销", "自由职业",
        "赚了", "收到", "到账", "入账", "现金回赠",
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
