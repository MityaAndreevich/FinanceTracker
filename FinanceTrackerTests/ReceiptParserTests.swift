//
//  ReceiptParserTests.swift
//  FinanceTrackerTests
//
//  DESIGN_RECEIPT_SCAN.md §9. Hand-written recognised lines — NOT corpus images.
//  The corpus is frozen and split before any of this is tuned; these fixtures
//  are the ranking rules stated as examples, one rule per test.
//
//  Negative control: a mutant that re-enables "largest number wins" must fail
//  `onlineOrderPicksTheOrderTotalNotTheLargestNumber` (recorded in the commit).
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("ReceiptParser")
struct ReceiptParserTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 12))! }

    private func parse(_ lines: [String], sep: Character = ".", confidence: Float = 0.95) -> ReceiptParser.Parse {
        ReceiptParser.parse(lines: lines.map { RecognizedLine(text: $0, confidence: confidence) },
                            decimalSeparator: sep, calendar: cal, now: now)
    }

    // MARK: - The rule that matters

    @Test("an online order picks Order total, not the largest number on the page")
    func onlineOrderPicksTheOrderTotalNotTheLargestNumber() throws {
        let p = parse([
            "Order Confirmation", "Thanks for your order, Dana",
            "Wireless Headphones  $199.00",
            "Promo code SAVE50  -$100.00",
            "Subtotal  $99.00", "Shipping  $5.99", "Tax  $8.42",
            "Order total  $113.41",
        ])
        #expect(p.total?.cents == 11_341)
        #expect(p.confidence == .high)
        #expect(p.total?.keyword == .grandTotal)
    }

    @Test("no keyword anywhere → no total, low confidence, no guess")
    func noKeywordNoGuess() {
        let p = parse(["Corner Shop", "Milk 2.49", "Bread 3.10", "Eggs 4.99", "Thank you"])
        #expect(p.total == nil)
        #expect(p.confidence == .low)
        #expect(p.candidates.count == 3, "the amounts are still offered as candidates to tap")
    }

    @Test("Subtotal / Tax / Total: the plain Total wins, the subtotal never does")
    func subtotalThenTotal() {
        let p = parse(["Cafe Luna", "Latte 4.50", "Bagel 3.25", "Subtotal 7.75", "Tax 0.62", "Total 8.37"])
        #expect(p.total?.cents == 837)
        #expect(p.confidence == .high)
    }

    @Test("two plain Totals: the earlier, smaller one is a subtotal in disguise")
    func twoTotalsLargerLaterWins() {
        let p = parse(["Store", "Total 42.00", "Discount -2.00", "Tax 3.20", "Total 43.20"])
        #expect(p.total?.cents == 4_320)
        #expect(p.confidence == .high)
    }

    @Test("a later plain Total that is SMALLER than an earlier one is picked but low confidence")
    func laterSmallerTotalIsLow() {
        let p = parse(["Store", "Total 50.00", "Total 10.00"])
        #expect(p.total?.cents == 1_000)
        #expect(p.confidence == .low)
    }

    @Test("tier 1 beats tier 2 even when tier 2 is lower on the page")
    func tier1BeatsTier2() {
        let p = parse(["Shop", "Total 20.00", "Amount due 18.00", "Total items 3"])
        #expect(p.total?.cents == 1_800)
    }

    @Test("exclusion lines never win: Cash tendered, Change, Tip, Savings, Tax, Shipping",
          arguments: ["Cash 100.00", "Change 51.63", "Tip 10.00", "You saved 12.00", "Sales tax 3.20", "Shipping 5.99", "Total tendered 100.00"])
    func exclusionsNeverWin(line: String) {
        let p = parse(["Store", "Total 48.37", line])
        #expect(p.total?.cents == 4_837, Comment(rawValue: "\(line) was chosen over the total"))
    }

    @Test("'tip' does not exclude 'multiple', 'tax' does not exclude 'taxi', 'total' is not inside 'totally'")
    func wholeWordMatching() {
        #expect(ReceiptParser.containsWord("multiple items", "tip") == false)
        #expect(ReceiptParser.containsWord("taxi ride", "tax") == false)
        #expect(ReceiptParser.containsWord("totally", "total") == false)
        #expect(ReceiptParser.containsWord("sales tax 3.20", "tax"))
        #expect(ReceiptParser.containsWord("итого 1 250,00", "итого"))
    }

    @Test("the amount on the NEXT line: a right-aligned total OCR split in two")
    func amountOnNextLine() {
        let p = parse(["Store", "Subtotal", "12.00", "Total", "12.96", "Thank you"])
        #expect(p.total?.cents == 1_296)
        #expect(p.total?.line == 3)
    }

    @Test("a token AmountParsing rejects is not a candidate; > maxAmountCents is not a candidate")
    func rejectedTokensAreNotCandidates() {
        let huge = String(repeating: "9", count: 22)
        let p = parse(["Store", "Total \(huge).00", "Total 99999999999999999.00"])
        #expect(p.total == nil)
        #expect(p.candidates.isEmpty)
    }

    @Test("a bare 4+ digit integer is not an amount (card fragments, order numbers)")
    func bareLongIntegersIgnored() {
        #expect(ReceiptParser.amountTokens(in: "Card **** 4242") == [])
        #expect(ReceiptParser.amountTokens(in: "Order 118273") == [])
        #expect(ReceiptParser.amountTokens(in: "Total 1250") == [])
        #expect(ReceiptParser.amountTokens(in: "Total 1250.00") == ["1250.00"])
        #expect(ReceiptParser.amountTokens(in: "Total 1 250,00") == ["1 250,00"])
        #expect(ReceiptParser.amountTokens(in: "Итого 1\u{00A0}250,00 ₽") == ["1\u{00A0}250,00"])
        #expect(ReceiptParser.amountTokens(in: "Qty 3") == ["3"])
    }

    // MARK: - Locales

    @Test("Russian paper receipt: ИТОГО wins over ПОДЫТОГ and НДС; comma decimal")
    func russianReceipt() {
        let p = parse(["ПЕРЕКРЁСТОК", "Молоко 89,90", "Хлеб 45,00", "ПОДЫТОГ 134,90", "В т.ч. НДС 20% 22,48",
                       "ИТОГО 1 250,00", "НАЛИЧНЫМИ 1 500,00", "СДАЧА 250,00"], sep: ",")
        #expect(p.total?.cents == 125_000)
        #expect(p.confidence == .high)
        #expect(p.merchant == "ПЕРЕКРЁСТОК")
    }

    @Test("Ukrainian: ДО СПЛАТИ wins; СУМА alone is tier 2")
    func ukrainianReceipt() {
        let p = parse(["АТБ", "Хліб 24,50", "Сума 24,50", "ПДВ 4,08", "До сплати 24,50"], sep: ",")
        #expect(p.total?.cents == 2_450)
        #expect(p.total?.keyword == .grandTotal)
    }

    @Test("Spanish (MX): TOTAL A PAGAR wins over SUBTOTAL and IVA; period decimal")
    func spanishReceipt() {
        let p = parse(["OXXO", "Coca 500ml $18.00", "Sabritas $22.00", "SUBTOTAL $40.00", "IVA $6.40",
                       "TOTAL A PAGAR $46.40", "EFECTIVO $50.00", "CAMBIO $3.60"])
        #expect(p.total?.cents == 4_640)
        #expect(p.currencyHint == "$")
    }

    @Test("Portuguese (BR): VALOR TOTAL wins; comma decimal with period grouping")
    func portugueseReceipt() {
        let p = parse(["Supermercado Pão de Açúcar", "Arroz 5kg R$ 24,90", "Frete R$ 9,90",
                       "Desconto -R$ 5,00", "VALOR TOTAL R$ 1.029,80", "Troco R$ 0,00"], sep: ",")
        #expect(p.total?.cents == 102_980)
        #expect(p.currencyHint == "R$")
    }

    @Test("English receipt in a comma-decimal app: 12.96 still reads as 12.96 (both separators present is positional)")
    func englishReceiptInRussianApp() {
        let p = parse(["Store", "Total 1,296.50"], sep: ",")
        #expect(p.total?.cents == 129_650)
    }

    @Test("diacritics and case are folded for keywords")
    func foldedKeywords() {
        #expect(parse(["Loja", "TOTAL À PAGAR 12,00"], sep: ",").total?.cents == 1_200)
        #expect(parse(["Tienda", "Importe Total 12.00"]).total?.keyword == .grandTotal)
    }

    // MARK: - Confidence

    @Test("a keyword line with low Vision confidence yields the amount but LOW confidence")
    func lowVisionConfidence() {
        let p = parse(["Store", "Total 8.37"], confidence: 0.3)
        #expect(p.total?.cents == 837)
        #expect(p.confidence == .low)
    }

    // MARK: - Merchant

    @Test("merchant is the first alphabetic line that is not a date, amount, phone, URL or keyword")
    func merchant() {
        let p = parse(["21/09/2026 14:02", "+1 (555) 010-2233", "www.cornershop.example", "Corner Shop Ltd", "Total 8.37"])
        #expect(p.merchant == "Corner Shop Ltd")
        #expect(parse(["Total 8.37"]).merchant == nil)
    }

    // MARK: - Date

    @Test("ISO and day-month-year dates are read; an out-of-window date is not")
    func dates() {
        let d = parse(["Store", "2026-09-18", "Total 1.00"]).date
        #expect(d.map { cal.dateComponents([.year, .month, .day], from: $0) } == DateComponents(year: 2026, month: 9, day: 18))
        let d2 = parse(["Store", "18.09.2026 10:31", "Total 1,00"], sep: ",").date
        #expect(d2.map { cal.component(.day, from: $0) } == 18)
        #expect(parse(["Store", "1985-03-03", "Total 1.00"]).date == nil)
        #expect(parse(["Store", "2031-01-01", "Total 1.00"]).date == nil)
        #expect(parse(["Store", "31/02/2026", "Total 1.00"]).date == nil, "31 Feb must not roll into March")
    }

    @Test("an ambiguous a/b/yyyy where both readings are valid and differ is NOT prefilled")
    func ambiguousDateNotPrefilled() {
        #expect(parse(["Store", "03/04/2026", "Total 1.00"]).date == nil)
        // Unambiguous: 13 can only be a day.
        #expect(parse(["Store", "13/04/2026", "Total 1.00"]).date.map { cal.component(.month, from: $0) } == 4)
        #expect(parse(["Store", "04/13/2026", "Total 1.00"]).date.map { cal.component(.month, from: $0) } == 4)
    }

    @Test("month names in five locales")
    func monthNames() {
        for (line, sep, month) in [("18 Sep 2026", Character("."), 9), ("18 сен 2026", Character(","), 9),
                                   ("18 set 2026", Character(","), 9), ("18 вер 2026", Character(","), 9), ("18 sept 2026", Character("."), 9)] {
            let d = parse(["Store", line, "Total 1.00"], sep: sep).date
            #expect(d.map { cal.component(.month, from: $0) } == month, Comment(rawValue: line))
        }
    }

    // MARK: - Non-receipts (the negative control the corpus tests also carry)

    @Test("non-receipt text yields no total", arguments: [
        ["Chapter 3", "It was a bright cold day in April, and the clocks were striking thirteen."],
        ["Dana Reyes", "Product Designer", "dana@example.com", "+1 555 010 2233"],
        ["Menu", "Espresso 3.00", "Cappuccino 4.20", "Croissant 3.50"],
    ])
    func nonReceipts(lines: [String]) {
        let p = parse(lines)
        #expect(p.total == nil)
        #expect(p.confidence == .low)
    }
}
