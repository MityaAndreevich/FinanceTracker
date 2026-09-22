//
//  ReceiptParser.swift
//  FinanceTracker
//
//  From recognised text lines to a grand total, a merchant and a date. PURE:
//  no Vision, no model, no I/O, no clock — so `ReceiptParserTests` drives it
//  with hand-written lines and the corpus tests drive it with real OCR output,
//  and the two cannot disagree about what the parser does.
//
//  THE ONE RULE THAT MATTERS (DESIGN_RECEIPT_SCAN.md §4.2): the total is chosen
//  by a KEYWORD on its line, never by being the largest number on the page. An
//  online order's largest number is often an item price before a discount; a
//  plausible wrong money figure, filled in, is the defect class this project has
//  paid for most. No keyword → no total → the amount field stays empty.
//
//  Two confidence states, deliberately (§4.4). A third, silent state is what the
//  pre-test's §1.1 defect was.
//

import CoreGraphics
import Foundation

struct RecognizedLine: Equatable, Sendable {
    let text: String
    /// Normalised Vision bounding box (0…1, origin bottom-left) — kept for the
    /// review sheet's highlight; the parser only uses line ORDER.
    let box: CGRect
    /// Vision's confidence for the line, 0…1.
    let confidence: Float

    init(text: String, box: CGRect = .zero, confidence: Float = 1) {
        self.text = text
        self.box = box
        self.confidence = confidence
    }
}

enum ReceiptParser {

    enum Confidence: Equatable, Sendable { case high, low }

    enum TotalKeyword: Equatable, Sendable {
        /// "grand total", "order total", "amount due", "итого", "к оплате", …
        case grandTotal
        /// "total", "всего", "сума", …
        case total
    }

    struct AmountCandidate: Equatable, Sendable {
        let cents: Int
        /// Index into the input lines.
        let line: Int
        let keyword: TotalKeyword?
        let visionConfidence: Float
        /// The token as recognised, for the review sheet ("1.250" next to 1 250,00 ₽).
        let token: String
    }

    struct Parse: Equatable, Sendable {
        let total: AmountCandidate?
        let confidence: Confidence
        let candidates: [AmountCandidate]
        let merchant: String?
        let date: Date?
        /// A currency symbol or code seen on the total line — a mismatch hint only.
        let currencyHint: String?
        let rawText: String
    }

    /// Vision confidence below which a keyword line does not earn `high`.
    static let minimumLineConfidence: Float = 0.5

    // MARK: - Keywords (all five locales always active — a Russian user photographs an English receipt)

    /// Tier 1: the amount the customer paid.
    static let grandTotalKeywords: [String] = [
        // en
        "grand total", "order total", "total due", "amount due", "amount paid", "you paid", "total paid",
        "balance due", "total charged", "charged",
        // ru
        "итого к оплате", "к оплате", "итого", "всего к оплате", "сумма к оплате", "оплачено", "итого оплачено",
        // es
        "total a pagar", "importe total", "total pagado", "gran total", "total del pedido",
        // pt-BR
        "total a pagar", "valor total", "total pago", "total do pedido", "total geral",
        // uk
        "до сплати", "разом до сплати", "всього до сплати", "сплачено", "сума до сплати",
    ]

    /// Tier 2: "total" and its plain equivalents.
    static let totalKeywords: [String] = [
        "total",
        "всего", "сумма",
        "importe",
        "сума", "разом", "всього",
    ]

    /// A line matching any of these is NEVER a total, whatever else it matches.
    static let exclusionKeywords: [String] = [
        "subtotal", "sub-total", "sub total", "промежуточный итог", "подытог", "проміжний підсумок", "проміжна сума",
        "tax", "vat", "gst", "hst", "налог", "ндс", "impuesto", "iva", "imposto", "icms", "податок", "пдв",
        "shipping", "delivery", "доставка", "envío", "envio", "frete", "entrega",
        "discount", "скидка", "descuento", "desconto", "знижка",
        "tip", "gratuity", "чаевые", "propina", "gorjeta", "чайові",
        "change", "сдача", "cambio", "troco", "решта",
        "cash", "наличные", "наличными", "efectivo", "dinheiro", "готівка", "готівкою",
        "savings", "you saved", "saved", "экономия", "ahorro", "ahorraste", "economia", "economizou", "заощаджено", "економія",
        "tendered", "внесено", "recibido", "recebido",
    ]

    // MARK: - Parse

    /// `decimalSeparator` is the APP locale's (DESIGN §4.3). `calendar` and
    /// `now` bound the date (1990-01-01 … now + 1 year, the form's own window).
    static func parse(
        lines: [RecognizedLine],
        decimalSeparator: Character,
        calendar: Calendar,
        now: Date
    ) -> Parse {
        let rawText = lines.map(\.text).joined(separator: "\n")
        var candidates: [AmountCandidate] = []

        for (index, line) in lines.enumerated() {
            let folded = fold(line.text)
            let excluded = exclusionKeywords.contains { containsWord(folded, $0) }
            let keyword: TotalKeyword? = excluded ? nil : keywordTier(in: folded)

            var tokens = amountTokens(in: line.text)
            // A right-aligned total that OCR split onto the next line: the
            // keyword line has no token, the next line is only an amount.
            if tokens.isEmpty, keyword != nil, index + 1 < lines.count {
                let next = lines[index + 1]
                let nextTokens = amountTokens(in: next.text)
                if nextTokens.count == 1, isOnlyAmount(next.text) {
                    tokens = nextTokens
                }
            }
            for token in tokens {
                guard let cents = AmountParsing.parseCents(token, decimalSeparator: decimalSeparator),
                      cents > 0, cents <= AmountParsing.maxAmountCents
                else { continue }
                candidates.append(AmountCandidate(cents: cents, line: index, keyword: excluded ? nil : keyword,
                                                  visionConfidence: line.confidence, token: token))
            }
        }

        let (total, confidence) = chooseTotal(from: candidates)
        let merchant = chooseMerchant(lines: lines)
        let date = chooseDate(lines: lines, decimalSeparator: decimalSeparator, calendar: calendar, now: now)
        let currencyHint = total.map { currencySymbol(in: lines[$0.line].text) } ?? nil

        return Parse(total: total, confidence: confidence, candidates: candidates,
                     merchant: merchant, date: date, currencyHint: currencyHint, rawText: rawText)
    }

    // MARK: - Total

    /// DESIGN §4.2 ranking: tier 1 (last on the page, then largest) → tier 2
    /// (excluding a "Total" followed by a larger "Total" — subtotal/total pairs;
    /// last, then largest) → nothing. The largest number is never a fallback.
    static func chooseTotal(from candidates: [AmountCandidate]) -> (AmountCandidate?, Confidence) {
        let tier1 = candidates.filter { $0.keyword == .grandTotal }
        if let pick = tier1.max(by: { a, b in a.line != b.line ? a.line < b.line : a.cents < b.cents }) {
            return (pick, pick.visionConfidence >= minimumLineConfidence ? .high : .low)
        }
        let tier2 = candidates.filter { $0.keyword == .total }
        guard !tier2.isEmpty else { return (nil, .low) }
        // Drop any "Total" that has a LARGER "Total" below it on the page.
        let survivors = tier2.filter { c in
            !tier2.contains { other in other.line > c.line && other.cents > c.cents }
        }
        guard let pick = survivors.max(by: { a, b in a.line != b.line ? a.line < b.line : a.cents < b.cents }) else {
            return (nil, .low)
        }
        let isMaxOfTier = tier2.allSatisfy { $0.cents <= pick.cents }
        let high = pick.visionConfidence >= minimumLineConfidence && isMaxOfTier
        return (pick, high ? .high : .low)
    }

    static func keywordTier(in folded: String) -> TotalKeyword? {
        if grandTotalKeywords.contains(where: { containsWord(folded, $0) }) { return .grandTotal }
        if totalKeywords.contains(where: { containsWord(folded, $0) }) { return .total }
        return nil
    }

    /// Case- and diacritic-insensitive, for keyword matching.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
    }

    /// Whole-word (or whole-phrase) match: "total" is not inside "subtotal" or
    /// "totally", "tip" is not inside "multiple", "tax" is not inside "taxi".
    static func containsWord(_ haystack: String, _ word: String) -> Bool {
        let pattern = "(^|[^\\p{L}])" + NSRegularExpression.escapedPattern(for: word) + "($|[^\\p{L}])"
        return haystack.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Amount tokens

    /// Digit groups with optional grouping (space, NBSP, narrow NBSP, apostrophe,
    /// comma, period) and an optional decimal part. Currency symbols are not part
    /// of the token; AmountParsing strips everything but digits and separators.
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\d])\d{1,3}(?:[   '.,]\d{3})*(?:[.,]\d{1,2})?(?![\d])|(?<![\p{L}\d])\d+(?:[.,]\d{1,2})?(?![\d])"#
    )

    static func amountTokens(in text: String) -> [String] {
        let ns = text as NSString
        return amountRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
            .filter { token in
                // A bare 4+ digit integer with no decimals is a card/order/phone
                // fragment far more often than money; keep integers ≤ 3 digits and
                // any token with a decimal part or grouping.
                let digitsOnly = token.allSatisfy(\.isNumber)
                return !(digitsOnly && token.count >= 4)
            }
    }

    private static func isOnlyAmount(_ text: String) -> Bool {
        let stripped = text.replacingOccurrences(of: #"[\s\d.,'  $€£₽₴¥R\$]"#, with: "", options: .regularExpression)
        return stripped.count <= 3
    }

    static func currencySymbol(in text: String) -> String? {
        if let r = text.range(of: #"[$€£₽₴¥]|R\$|\b(USD|EUR|GBP|RUB|UAH|MXN|BRL|JPY)\b"#, options: .regularExpression) {
            return String(text[r])
        }
        return nil
    }

    // MARK: - Merchant

    /// The first line from the top with ≥ 3 letters that is not a date, an
    /// amount, a phone, a URL, an address number or a keyword line. ≤ 200 chars.
    static func chooseMerchant(lines: [RecognizedLine]) -> String? {
        for line in lines.prefix(8) {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard letters >= 3 else { continue }
            let folded = fold(text)
            if keywordTier(in: folded) != nil || exclusionKeywords.contains(where: { containsWord(folded, $0) }) { continue }
            if text.range(of: #"https?://|www\.|@"#, options: .regularExpression) != nil { continue }
            if text.range(of: #"\+?\d[\d\s\-()]{7,}\d"#, options: .regularExpression) != nil { continue }
            if dateRegex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil { continue }
            if !amountTokens(in: text).isEmpty && letters < 6 { continue }
            if folded.contains("receipt") || folded.contains("чек") || folded.contains("recibo") || folded.contains("cupom") { continue }
            return String(text.prefix(200))
        }
        return nil
    }

    // MARK: - Date

    private static let dateRegex = try! NSRegularExpression(
        pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b|\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b|\b(\d{1,2})\s+([\p{L}]{3,})\.?\s+(\d{4})\b"#
    )

    static let monthNames: [String: Int] = {
        var m: [String: Int] = [:]
        let tables: [[String]] = [
            ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"],
            ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"],
            ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
            ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"],
            ["січ", "лют", "бер", "кві", "тра", "чер", "лип", "сер", "вер", "жов", "лис", "гру"],
        ]
        for table in tables { for (i, name) in table.enumerated() { m[name] = i + 1 } }
        m["май"] = 5; m["июня"] = 6; m["setembro"] = 9
        return m
    }()

    /// First date on the page that falls in the form's window. An ambiguous
    /// `a/b/yyyy` where both day-first and month-first are valid AND differ is
    /// NOT prefilled (DESIGN §4.2) — today stays.
    static func chooseDate(lines: [RecognizedLine], decimalSeparator: Character, calendar: Calendar, now: Date) -> Date? {
        let lower = calendar.date(from: DateComponents(year: 1990, month: 1, day: 1))!
        let upper = calendar.date(byAdding: .year, value: 1, to: now)!
        let dayFirst = decimalSeparator == ","   // the comma-decimal locales here are all day-first
        for line in lines {
            let ns = line.text as NSString
            for m in dateRegex.matches(in: line.text, range: NSRange(location: 0, length: ns.length)) {
                func g(_ i: Int) -> String? { m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i)) }
                var comps: [DateComponents] = []
                if let y = g(1), let mo = g(2), let d = g(3) {
                    comps = [DateComponents(year: Int(y), month: Int(mo), day: Int(d))]
                } else if let a = g(4), let b = g(5), let yRaw = g(6) {
                    var y = Int(yRaw)!; if yRaw.count == 2 { y += 2000 }
                    let (x, z) = (Int(a)!, Int(b)!)
                    let df = DateComponents(year: y, month: z, day: x)
                    let mf = DateComponents(year: y, month: x, day: z)
                    let dfValid = exactDate(df, calendar: calendar) != nil
                    let mfValid = exactDate(mf, calendar: calendar) != nil
                    if dfValid && mfValid && x != z { continue }   // ambiguous: not prefilled
                    comps = [dayFirst ? df : mf, dayFirst ? mf : df]
                } else if let d = g(7), let name = g(8), let y = g(9) {
                    let key = String(fold(name).prefix(3))
                    if let mo = monthNames[fold(name)] ?? monthNames[key] {
                        comps = [DateComponents(year: Int(y), month: mo, day: Int(d))]
                    }
                }
                for c in comps {
                    guard let date = exactDate(c, calendar: calendar), date >= lower, date <= upper else { continue }
                    return date
                }
            }
        }
        return nil
    }
}

extension ReceiptParser {
    /// The date for y/m/d ONLY if the calendar does not roll it (31 Feb → nil).
    static func exactDate(_ c: DateComponents, calendar: Calendar) -> Date? {
        guard let y = c.year, let m = c.month, let d = c.day,
              let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
        else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return (back.year == y && back.month == m && back.day == d) ? date : nil
    }
}
