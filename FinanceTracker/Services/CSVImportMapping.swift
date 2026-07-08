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

// MARK: - Date order

/// The component order of a source file's dates. Declared by the preset because
/// "03/04/2026" is a different day in a US vs an EU file. `.auto` infers only
/// when a component >12 removes the ambiguity, else falls back to US (`.mdy`).
enum DateOrder {
    case iso   // YYYY-MM-DD (unambiguous)
    case mdy   // MM/DD/YYYY (US)
    case dmy   // DD/MM/YYYY, DD.MM.YYYY (EU)
    case auto  // infer per value, default MDY
}

// MARK: - Date parser

enum ImportDate {

    private static func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static func isoFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = utcCalendar()
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }

    /// Parse a foreign date cell into UTC midnight, or nil if it cannot be a real
    /// calendar date. ISO `YYYY-MM-DD` is always accepted regardless of `order`.
    static func parse(_ raw: String, order: DateOrder) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if let iso = isoFormatter().date(from: s) { return iso }
        guard order != .iso else { return nil }  // declared ISO but not ISO-shaped

        let parts = s.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let a = Int(parts[0]), let b = Int(parts[1]), let rawYear = Int(parts[2]) else {
            return nil
        }
        let year = rawYear < 100 ? 2000 + rawYear : rawYear

        let (month, day): (Int, Int)
        switch order {
        case .mdy, .iso: (month, day) = (a, b)
        case .dmy:       (month, day) = (b, a)
        case .auto:
            if a > 12, b <= 12 { (month, day) = (b, a) }        // first >12 → it's the day → DMY
            else if b > 12, a <= 12 { (month, day) = (a, b) }   // second >12 → DMY-day is 2nd → MDY
            else { (month, day) = (a, b) }                      // ambiguous → US default
        }
        return makeDate(year: year, month: month, day: day)
    }

    /// Strict date construction with a round-trip validation so rolled-over
    /// values (e.g. Feb 31) are rejected rather than silently shifted.
    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let cal = utcCalendar()
        guard let date = cal.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard c.year == year, c.month == month, c.day == day else { return nil }
        return date
    }

    /// Infer a whole column's order from sample values: ISO if all look ISO;
    /// otherwise DMY/MDY if any value's first/second component is >12; else US.
    static func detectOrder(samples: [String]) -> DateOrder {
        let vals = samples
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !vals.isEmpty else { return .mdy }

        if vals.allSatisfy({ isoFormatter().date(from: $0) != nil }) { return .iso }

        var sawDayFirst = false
        var sawMonthFirst = false
        for v in vals {
            let parts = v.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
            guard parts.count == 3, let a = Int(parts[0]), let b = Int(parts[1]) else { continue }
            if a > 12, b <= 12 { sawDayFirst = true }
            else if b > 12, a <= 12 { sawMonthFirst = true }
        }
        if sawDayFirst, !sawMonthFirst { return .dmy }
        if sawMonthFirst, !sawDayFirst { return .mdy }
        return .mdy
    }
}
