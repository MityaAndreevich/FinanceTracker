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
    /// Returns nil for cells with no digits. The magnitude goes through the shared
    /// `AmountParsing` core; only sign detection is CSV-specific.
    static func parse(_ raw: String, decimal style: CSVDecimalStyle) -> (cents: Int, isNegative: Bool)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Sign: accountant parentheses OR a minus sign anywhere in the token.
        let parenthesised = trimmed.hasPrefix("(") && trimmed.hasSuffix(")")
        let isNegative = parenthesised || trimmed.contains("-") || trimmed.contains("\u{2212}")

        let decimalChar: Character = style == .comma ? "," : "."
        // CSV never guesses: reject a lone separator whose digit count is
        // inconsistent with the declared convention (→ nil → the mapper routes the
        // row to failedRows). QuickAdd keeps the lenient core path.
        guard AmountParsing.hasConsistentSeparators(trimmed, decimalSeparator: decimalChar),
              let cents = AmountParsing.parseCents(trimmed, decimalSeparator: decimalChar) else {
            return nil
        }
        return (cents, isNegative)
    }
}

// MARK: - Date order

/// The component order of a source file's dates. Declared by the preset because
/// "03/04/2026" is a different day in a US vs an EU file. `.auto` infers only
/// when a component >12 removes the ambiguity, else falls back to US (`.mdy`).
enum DateOrder: Equatable {
    case iso   // YYYY-MM-DD (unambiguous)
    case mdy   // MM/DD/YYYY (US)
    case dmy   // DD/MM/YYYY, DD.MM.YYYY (EU)
    case auto  // infer per value, default MDY
}

/// Result of classifying a whole date column, surfaced in the mapping sheet.
/// `.ambiguous` is the safety case: the column carries no >12 signal, so the order
/// cannot be known and the user MUST choose before import.
enum DetectedDateOrder: Equatable {
    case iso
    case resolved(DateOrder)  // a >12 component fixed the order
    case ambiguous            // no signal — do not guess
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

    /// Classify a whole column's date order from sample values. Crucially this
    /// reports `.ambiguous` when NO sample disambiguates day/month (every component
    /// ≤12, non-ISO) rather than silently defaulting to US order — the mapping sheet
    /// then forces the user to choose, so a European file is never transposed.
    static func classifyColumn(samples: [String]) -> DetectedDateOrder {
        let vals = samples
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !vals.isEmpty else { return .ambiguous }

        if vals.allSatisfy({ isoFormatter().date(from: $0) != nil }) { return .iso }

        var sawDayFirst = false
        var sawMonthFirst = false
        for v in vals {
            let parts = v.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
            guard parts.count == 3, let a = Int(parts[0]), let b = Int(parts[1]) else { continue }
            if a > 12, b <= 12 { sawDayFirst = true }
            else if b > 12, a <= 12 { sawMonthFirst = true }
        }
        if sawDayFirst, !sawMonthFirst { return .resolved(.dmy) }
        if sawMonthFirst, !sawDayFirst { return .resolved(.mdy) }
        return .ambiguous  // nothing >12 anywhere → genuinely ambiguous, ask the user
    }
}

// MARK: - Amount / sign combiner

/// A positive magnitude in cents plus a direction. Transaction stores an
/// unsigned `amountCents` and derives sign from `typeRaw`, so this is the shape
/// every foreign amount is normalized into.
struct SignedAmount: Equatable {
    var cents: Int
    var typeRaw: String  // "income" | "expense"
}

/// Why a row's amount/sign could not be resolved. Never a crash — surfaced in the
/// import summary so the user knows exactly which rows need attention.
enum ImportAmountFailure: Equatable, Error {
    case unparsableAmount
    case bothColumnsEmpty         // debit AND credit blank/zero
    case bothColumnsFilled        // debit AND credit both non-zero — ambiguous
    case unrecognizedType(String) // a type column value we can't map to income/expense
}

/// Resolves the three foreign ways of expressing direction into a `SignedAmount`.
enum ImportSign {

    // Direction keywords seen across Mint / bank exports. Mint's Transaction Type
    // column is exactly "debit"/"credit", so exact matches take priority.
    private static let incomeWords: Set<String> = ["credit", "cr", "deposit", "income", "refund", "interest", "dividend"]
    private static let expenseWords: Set<String> = ["debit", "dr", "withdrawal", "payment", "purchase", "sale", "charge", "fee", "expense"]

    /// Map a type-column value ("debit"/"credit"/"Deposit"/…) to a typeRaw, or nil.
    static func classifyType(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return nil }
        if incomeWords.contains(t) { return "income" }
        if expenseWords.contains(t) { return "expense" }
        if incomeWords.contains(where: { t.contains($0) }) { return "income" }
        if expenseWords.contains(where: { t.contains($0) }) { return "expense" }
        return nil
    }

    /// Shape 1: a single column whose sign gives direction (negative → expense).
    static func combineSigned(_ amountCell: String, decimal style: CSVDecimalStyle) -> Result<SignedAmount, ImportAmountFailure> {
        guard let parsed = ImportAmount.parse(amountCell, decimal: style) else {
            return .failure(.unparsableAmount)
        }
        return .success(SignedAmount(cents: parsed.cents, typeRaw: parsed.isNegative ? "expense" : "income"))
    }

    /// Shape 2 (Mint): an unsigned amount column + a type column.
    static func combineUnsignedWithType(amount amountCell: String, type typeCell: String, decimal style: CSVDecimalStyle) -> Result<SignedAmount, ImportAmountFailure> {
        guard let parsed = ImportAmount.parse(amountCell, decimal: style) else {
            return .failure(.unparsableAmount)
        }
        guard let typeRaw = classifyType(typeCell) else {
            return .failure(.unrecognizedType(typeCell.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return .success(SignedAmount(cents: parsed.cents, typeRaw: typeRaw))
    }

    /// Shape 3: two columns (money-out debit, money-in credit), each unsigned.
    /// Exactly one must be non-zero; the magnitude is taken so a bank that writes
    /// its debit column negative still works.
    static func combineDebitCredit(debit debitCell: String, credit creditCell: String, decimal style: CSVDecimalStyle) -> Result<SignedAmount, ImportAmountFailure> {
        let d = debitCell.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = creditCell.trimmingCharacters(in: .whitespacesAndNewlines)

        let dParsed = d.isEmpty ? nil : ImportAmount.parse(d, decimal: style)
        let cParsed = c.isEmpty ? nil : ImportAmount.parse(c, decimal: style)
        if (!d.isEmpty && dParsed == nil) || (!c.isEmpty && cParsed == nil) {
            return .failure(.unparsableAmount)
        }

        let dCents = dParsed?.cents ?? 0
        let cCents = cParsed?.cents ?? 0
        let hasDebit = dCents > 0
        let hasCredit = cCents > 0

        if !hasDebit, !hasCredit { return .failure(.bothColumnsEmpty) }
        if hasDebit, hasCredit { return .failure(.bothColumnsFilled) }
        return hasCredit
            ? .success(SignedAmount(cents: cCents, typeRaw: "income"))
            : .success(SignedAmount(cents: dCents, typeRaw: "expense"))
    }
}

// MARK: - Column mapping model

/// How the amount/direction is laid out in the source file (see `ImportSign`).
enum AmountMapping: Equatable {
    case signed(Int)                                // one signed column
    case unsignedWithType(amount: Int, type: Int)   // Mint: unsigned amount + type column
    case debitCredit(debit: Int, credit: Int)       // two columns
}

/// A resolved mapping from a foreign file's columns to our transaction fields.
/// `date` + `amount` (+ a sign source, encoded in `amount`) are the only required
/// pieces; the rest are optional and left unmapped when absent.
struct ColumnMapping: Equatable {
    var date: Int
    var dateOrder: DateOrder
    var decimal: CSVDecimalStyle
    var amount: AmountMapping
    var category: Int?
    var merchant: Int?
    var note: Int?
    var account: Int?
    /// Foreign files almost never carry a currency column; when unmapped the
    /// importer assumes `defaultCurrencyCode` and flags the assumption.
    var currency: Int? = nil
}

// MARK: - Source presets

enum SourcePreset: String, CaseIterable, Identifiable {
    case mint, ynab, monarch, genericBank, custom
    var id: String { rawValue }

    /// Auto-detect the best preset for a header row. The user can override.
    static func detect(header: [String]) -> SourcePreset {
        let cols = header.map(normalize)
        func has(_ s: String) -> Bool { cols.contains(s) }

        if has("transaction type"), has("original description") { return .mint }
        if has("original statement"), has("merchant") { return .monarch }
        if has("outflow"), has("inflow") { return .ynab }
        if SourcePreset.genericBank.defaultMapping(header: header) != nil { return .genericBank }
        return .custom
    }

    /// Build this preset's default column mapping against an actual header, or nil
    /// if the header lacks the columns this preset requires.
    func defaultMapping(header: [String]) -> ColumnMapping? {
        switch self {
        case .mint:
            guard let date = exact(header, "date"),
                  let amount = exact(header, "amount"),
                  let type = exact(header, "transaction type") else { return nil }
            return ColumnMapping(
                date: date, dateOrder: .mdy, decimal: .period,
                amount: .unsignedWithType(amount: amount, type: type),
                category: exact(header, "category"),
                merchant: exact(header, "description"),
                note: exact(header, "notes"),
                account: exact(header, "account name"))

        case .ynab:
            guard let date = exact(header, "date"),
                  let out = exact(header, "outflow"),
                  let inf = exact(header, "inflow") else { return nil }
            return ColumnMapping(
                date: date, dateOrder: .mdy, decimal: .period,
                amount: .debitCredit(debit: out, credit: inf),
                category: exact(header, "category"),
                merchant: exact(header, "payee"),
                note: exact(header, "memo"),
                account: exact(header, "account"))

        case .monarch:
            guard let date = exact(header, "date"),
                  let amount = exact(header, "amount") else { return nil }
            return ColumnMapping(
                date: date, dateOrder: .iso, decimal: .period,
                amount: .signed(amount),
                category: exact(header, "category"),
                merchant: exact(header, "merchant"),
                note: exact(header, "notes"),
                account: exact(header, "account"))

        case .genericBank:
            guard let date = fuzzy(header, ["date"]) else { return nil }
            let amount: AmountMapping
            if let debit = fuzzy(header, ["debit"]), let credit = fuzzy(header, ["credit"]) {
                amount = .debitCredit(debit: debit, credit: credit)
            } else if let single = fuzzy(header, ["amount"]) {
                amount = .signed(single)
            } else {
                return nil
            }
            return ColumnMapping(
                date: date, dateOrder: .auto, decimal: .period,
                amount: amount,
                category: fuzzy(header, ["category"]),
                merchant: fuzzy(header, ["description", "payee", "merchant", "vendor", "name"]),
                note: fuzzy(header, ["memo", "note"]),
                account: fuzzy(header, ["account"]),
                currency: fuzzy(header, ["currency"]))

        case .custom:
            return nil  // fully manual — the UI seeds an editable skeleton
        }
    }
}

// MARK: - Header column resolution

private func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

/// Index of the first column whose normalized name equals `name`.
private func exact(_ header: [String], _ name: String) -> Int? {
    header.firstIndex { normalize($0) == name }
}

/// Index of the first column whose normalized name contains any candidate.
private func fuzzy(_ header: [String], _ candidates: [String]) -> Int? {
    header.firstIndex { col in
        let n = normalize(col)
        return candidates.contains { n.contains($0) }
    }
}

// MARK: - Row mapper

/// A fully-normalized transaction ready to insert. `amountCents` is a positive
/// magnitude (sign lives in `typeRaw`); `categoryName == nil` means "uncategorized
/// fallback"; `currencyAssumed` records that no currency was present in the file.
struct NormalizedTransaction: Equatable {
    var date: Date
    var amountCents: Int
    var typeRaw: String
    var currency: String
    var currencyAssumed: Bool
    var categoryName: String?
    var merchant: String?
    var note: String?
    var account: String?
}

/// Why a row could not be normalized. Every value maps to a user-facing summary
/// line — a row that fails is REPORTED, never silently dropped.
enum RowMapFailure: Equatable, Error {
    case missingDate
    case invalidDate(String)
    case amount(ImportAmountFailure)
}

/// The pure seam the SwiftData importer sits on: raw row + mapping → normalized
/// transaction or a typed failure. No ModelContext, no side effects.
enum ImportRowMapper {

    static func map(row: [String], mapping: ColumnMapping, defaultCurrency: String) -> Result<NormalizedTransaction, RowMapFailure> {
        func cell(_ index: Int?) -> String? {
            guard let index, index >= 0, index < row.count else { return nil }
            return row[index]
        }
        func text(_ index: Int?) -> String? {
            guard let raw = cell(index)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            return raw
        }

        // Date (required).
        guard let dateStr = text(mapping.date) else { return .failure(.missingDate) }
        guard let date = ImportDate.parse(dateStr, order: mapping.dateOrder) else {
            return .failure(.invalidDate(dateStr))
        }

        // Amount + sign (required), per the file's shape.
        let signedResult: Result<SignedAmount, ImportAmountFailure>
        switch mapping.amount {
        case .signed(let i):
            signedResult = ImportSign.combineSigned(cell(i) ?? "", decimal: mapping.decimal)
        case .unsignedWithType(let a, let t):
            signedResult = ImportSign.combineUnsignedWithType(amount: cell(a) ?? "", type: cell(t) ?? "", decimal: mapping.decimal)
        case .debitCredit(let d, let c):
            signedResult = ImportSign.combineDebitCredit(debit: cell(d) ?? "", credit: cell(c) ?? "", decimal: mapping.decimal)
        }
        let signed: SignedAmount
        switch signedResult {
        case .success(let s): signed = s
        case .failure(let f): return .failure(.amount(f))
        }

        // Currency: honour a mapped, valid ISO code; otherwise assume the default.
        let currency: String
        let currencyAssumed: Bool
        if let raw = text(mapping.currency)?.uppercased(), CSVImportService.isValidISO4217(raw) {
            currency = raw
            currencyAssumed = false
        } else {
            currency = defaultCurrency.uppercased()
            currencyAssumed = true
        }

        return .success(NormalizedTransaction(
            date: date,
            amountCents: signed.cents,
            typeRaw: signed.typeRaw,
            currency: currency,
            currencyAssumed: currencyAssumed,
            categoryName: text(mapping.category),   // nil → uncategorized fallback
            merchant: text(mapping.merchant),
            note: text(mapping.note),
            account: text(mapping.account)))
    }
}
