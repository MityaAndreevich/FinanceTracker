//
//  CSVImportMapping.swift
//  FinanceTracker
//
//  Tier-2 flexible CSV import: the pure, side-effect-free layer that turns an
//  arbitrary foreign CSV row + a user/preset column mapping into a normalized,
//  signed transaction. Kept independent of SwiftData so it is exhaustively unit
//  testable — a wrong mapping silently corrupts the user's financial data, which
//  is worse than a crash, so every transform here is table-tested.
//
//  Integrates with the existing importer (CSVImportService / CSVImportActor) via
//  Unit 6 — this file deliberately touches NO ModelContext.
//

import Foundation

// MARK: - Decimal style

/// Which separator a source file uses for the decimal point. Only needed to
/// resolve the one genuinely ambiguous shape (a lone separator followed by
/// exactly three digits, e.g. "1.234"); when both separators are present the
/// decimal is identified by position and the style is irrelevant.
enum CSVDecimalStyle {
    case period  // decimal ".", grouping ","/space/NBSP  (Mint, YNAB, US banks)
    case comma   // decimal ",", grouping "."/space/NBSP  (EU banks)
}

// MARK: - Amount tokenizer

/// Locale-tolerant amount parser for foreign CSV cells.
///
/// Unlike `Money.parseCents` (which maps "," → "." and therefore corrupts any
/// grouped number: "1,234.56" → "1.234.56" → nil), this identifies the decimal
/// separator by *position* — the later of the last "," / "." — and strips every
/// other separator (",", ".", space, NBSP) as grouping. So a US "1,234.56" and
/// an EU "1.234,56" both yield 123456. Sign is reported separately so the
/// amount/sign combiner (Unit 3) can apply it per the mapping's shape.
///
/// This reuses the discipline of `QuickAddParser.parseTokenCents` (kept private
/// there); unify the two in a later refactor.
enum ImportAmount {

    /// Parse one amount cell into a non-negative magnitude in cents plus whether
    /// the cell was written as a negative ("-12.34" or the accountant "(12.34)").
    /// Returns nil for cells with no digits.
    static func parse(_ raw: String, decimal style: CSVDecimalStyle) -> (cents: Int, isNegative: Bool)? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // Sign: accountant parentheses OR a minus sign anywhere in the token.
        var isNegative = false
        if s.hasPrefix("(") && s.hasSuffix(")") {
            isNegative = true
            s.removeFirst()
            s.removeLast()
        }
        if s.contains("-") || s.contains("\u{2212}") {  // ASCII hyphen or Unicode minus
            isNegative = true
        }

        // Keep only digits and the two possible separators; this drops currency
        // symbols, sign glyphs, and grouping spaces/NBSP.
        s = String(s.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789,.").contains($0) })
        guard s.contains(where: { $0.isNumber }) else { return nil }

        // Decimal separator by position.
        let lastComma = s.lastIndex(of: ",")
        let lastPeriod = s.lastIndex(of: ".")
        let decimalIndex: String.Index?
        if let lc = lastComma, let lp = lastPeriod {
            decimalIndex = lc > lp ? lc : lp
        } else if let lc = lastComma {
            decimalIndex = decimalSeparatorIndex(in: s, at: lc, symbol: ",", isConventionDecimal: style == .comma)
        } else if let lp = lastPeriod {
            decimalIndex = decimalSeparatorIndex(in: s, at: lp, symbol: ".", isConventionDecimal: style == .period)
        } else {
            decimalIndex = nil
        }

        let intDigits: String
        let fracDigits: String
        if let d = decimalIndex {
            intDigits = s[s.startIndex..<d].filter(\.isNumber)
            fracDigits = s[s.index(after: d)...].filter(\.isNumber)
        } else {
            intDigits = s.filter(\.isNumber)
            fracDigits = ""
        }
        guard !(intDigits.isEmpty && fracDigits.isEmpty) else { return nil }

        let intValue = Int(intDigits) ?? 0
        let fracValue = Int((fracDigits + "00").prefix(2)) ?? 0  // pad/cap to 2 digits
        return (intValue * 100 + fracValue, isNegative)
    }

    /// Whether a single-symbol separator is the decimal point or a thousands
    /// group, decided by the digit count after it; only the 3-digit case is
    /// genuinely ambiguous and deferred to the file's declared style.
    private static func decimalSeparatorIndex(in s: String, at index: String.Index, symbol: Character, isConventionDecimal: Bool) -> String.Index? {
        if s.filter({ $0 == symbol }).count > 1 { return nil }  // repeated → all grouping
        let digitsAfter = s[s.index(after: index)...].filter(\.isNumber).count
        switch digitsAfter {
        case 0: return nil                                // trailing separator → ignore
        case 1, 2: return index                           // money decimal (1–2 places)
        case 3: return isConventionDecimal ? index : nil  // ambiguous → style decides
        default: return index                             // 4+ → decimal (fraction capped)
        }
    }
}
