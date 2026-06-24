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
        "paycheck", "salary", "income", "refund", "bonus", "freelance",
        "deposit", "interest", "dividend",
        "зарплата", "доход", "перевод",
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
