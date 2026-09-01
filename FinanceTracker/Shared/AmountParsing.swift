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

    /// The largest amount the app will accept, in cents — 100 000 000 000.00.
    ///
    /// ONE constant, referenced by every writer. It was previously a literal
    /// repeated in AddTransactionView and EditTransactionView and absent from the
    /// import path entirely, so import could insert a row the editor would then
    /// refuse to save — a value the user could see but not correct.
    static let maxAmountCents = 10_000_000_000_000


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

        // ── AN AMOUNT THAT CANNOT BE REPRESENTED IS NOT AN AMOUNT ───────────────
        // This tail used to read `Int(intDigits) ?? 0`, and that `?? 0` was a
        // silent data-loss bug: a 22-digit cell — an account or reference number
        // mis-mapped into the amount column, which the app's own flexible column
        // mapping makes easy — imported as ZERO cents, with no error and no flag.
        // The user was told the import succeeded and their ledger was wrong.
        //
        // `intValue * 100` was worse: for 17–19 digit input it TRAPPED, crashing
        // the process inside a parser, on a file the app itself accepted.
        //
        // Both are the same mistake in opposite directions — a value the app
        // cannot represent turned into a plausible number, or into a crash. It is
        // neither: it is a row we cannot read, and the caller's contract for that
        // is already `nil`. `taxCents` next door has always kept the optional
        // (CSVImportService.swift:714) — evidence this was an oversight rather
        // than a decision.
        // Two different things that both make `Int(intDigits)` fail, and the first
        // version of this fix collapsed them — which broke ".15" and ",15", i.e.
        // every leading-decimal amount a user can type. Caught by
        // AmountParsingTests.testLeadingDecimal, not by review.
        //
        //   • EMPTY  → there is no integer part. That is a legitimate amount.
        //   • NON-EMPTY but unparseable → digits we cannot represent. Reject.
        let intValue: Int
        if intDigits.isEmpty {
            intValue = 0
        } else {
            guard let parsed = Int(intDigits) else { return nil }
            intValue = parsed
        }
        guard var fracValue = Int((fracDigits + "00").prefix(2)) else { return nil }

        // Half-up rounding on the 3rd fractional digit — truncating here biased
        // every >2-decimal foreign amount down by up to a cent. Working on the
        // digit string avoids binary-float artifacts (2.675 → 2.68, not 2.67). The
        // carry (99 → 100) folds naturally into intValue * 100 below.
        if fracDigits.count > 2 {
            let thirdDigit = fracDigits[fracDigits.index(fracDigits.startIndex, offsetBy: 2)].wholeNumberValue ?? 0
            if thirdDigit >= 5 { fracValue += 1 }
        }

        let (scaled, mulOverflow) = intValue.multipliedReportingOverflow(by: 100)
        guard !mulOverflow else { return nil }
        let (cents, addOverflow) = scaled.addingReportingOverflow(fracValue)
        guard !addOverflow else { return nil }
        return cents
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

    /// CSV-only strictness gate (QuickAdd deliberately stays lenient — the user
    /// sees the field). Returns false when a LONE separator's digit count can't
    /// match the declared convention, so the CSV mapper can route the row to
    /// `failedRows` instead of silently coercing it:
    ///   • the GROUPING character (the one that isn't `decimalSeparator`) is valid
    ///     only as an exact 3-digit thousands group;
    ///   • the DECIMAL character is always fine (1–2 places, or 3+ that round);
    ///   • both separators present (position-resolved), a repeated separator (an
    ///     unambiguous group run like "1,234,567"), or a bare integer are all fine.
    /// It does NOT re-implement parsing — it only judges separator consistency.
    static func hasConsistentSeparators(_ raw: String, decimalSeparator: Character) -> Bool {
        let s = String(raw.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789,.").contains($0) })
        let commas = s.filter { $0 == "," }.count
        let periods = s.filter { $0 == "." }.count

        // Both kinds present → decimal fixed by position; none → integer.
        guard (commas == 0) != (periods == 0) else { return true }

        let sep: Character = commas > 0 ? "," : "."
        let count = commas > 0 ? commas : periods
        if count > 1 { return true }  // repeated same separator → unambiguous grouping

        if sep == decimalSeparator { return true }  // decimal char: always acceptable
        // Grouping char: valid only as an exact 3-digit group.
        guard let idx = s.lastIndex(of: sep) else { return true }
        return s[s.index(after: idx)...].filter(\.isNumber).count == 3
    }
}
