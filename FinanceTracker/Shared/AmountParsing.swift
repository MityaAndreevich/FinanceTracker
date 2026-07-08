//
//  AmountParsing.swift
//  FinanceTracker
//
//  THE money-string → cents numeric core. One implementation, three callers:
//    • QuickAddParser (NL amounts, separator from the USER's locale)
//    • CSV ImportAmount (foreign fields, separator from the FILE's declared format)
//    • Money.parseCents (sanitized money-TextField input)
//
//  Money parsing is where silent data corruption lives — we have already shipped
//  two separate locale bugs here (CSV separator 16f8b75, QuickAdd amount e219c15).
//  Keeping a single core means a fix or bug is shared, never duplicated.
//
//  Algorithm (positional, robust to a mis-declared separator):
//    • Strip everything that isn't a digit, "," or "." (currency symbols, signs,
//      whitespace, NBSP — all grouping/noise).
//    • Identify the decimal separator by POSITION: when both "," and "." are
//      present, the LATER one is the decimal; everything before it is grouping.
//    • The one genuinely ambiguous shape — a single "," or "." followed by exactly
//      three digits ("1.234") — is broken by the caller-supplied `decimalSeparator`.
//    • The fraction is capped/padded to exactly two digits.
//

import Foundation

enum AmountParsing {

    /// Parse a money string into a non-negative magnitude in cents, or nil when it
    /// carries no digits. Sign is the caller's concern (an NL amount is positive; a
    /// CSV field's sign is derived separately from `-`/parentheses/columns).
    ///
    /// - parameter decimalSeparator: the separator to treat as the decimal point in
    ///   the ambiguous single-separator case. Must be "," or "."; anything else
    ///   makes every single separator grouping.
    static func parseCents(_ raw: String, decimalSeparator: Character) -> Int? {
        let s = String(raw.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789,.").contains($0) })
        guard s.contains(where: { $0.isNumber }) else { return nil }

        let lastComma = s.lastIndex(of: ",")
        let lastPeriod = s.lastIndex(of: ".")
        let decimalIndex: String.Index?
        if let lc = lastComma, let lp = lastPeriod {
            decimalIndex = lc > lp ? lc : lp                       // both present → later is decimal
        } else if let lc = lastComma {
            decimalIndex = decimalSeparatorIndex(in: s, at: lc, symbol: ",", isConventionDecimal: decimalSeparator == ",")
        } else if let lp = lastPeriod {
            decimalIndex = decimalSeparatorIndex(in: s, at: lp, symbol: ".", isConventionDecimal: decimalSeparator == ".")
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
        let fracValue = Int((fracDigits + "00").prefix(2)) ?? 0    // pad/cap to 2 digits
        return intValue * 100 + fracValue
    }

    /// Whether a single-symbol separator is the decimal point or a thousands group,
    /// decided by the digit count after it; only the 3-digit case is genuinely
    /// ambiguous and deferred to the caller-declared decimal separator.
    private static func decimalSeparatorIndex(in s: String, at index: String.Index, symbol: Character, isConventionDecimal: Bool) -> String.Index? {
        if s.filter({ $0 == symbol }).count > 1 { return nil }    // repeated → all grouping
        let digitsAfter = s[s.index(after: index)...].filter(\.isNumber).count
        switch digitsAfter {
        case 0: return nil                                        // trailing separator → ignore
        case 1, 2: return index                                   // money decimal (1–2 places)
        case 3: return isConventionDecimal ? index : nil          // ambiguous → declared separator decides
        default: return index                                     // 4+ → decimal (fraction capped)
        }
    }
}
