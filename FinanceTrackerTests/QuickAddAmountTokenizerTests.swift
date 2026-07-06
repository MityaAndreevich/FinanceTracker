//
//  QuickAddAmountTokenizerTests.swift
//  FinanceTrackerTests
//
//  Locale-aware amount tokenizer parse table (Brief: NLParser amount/locale).
//  LAUNCH BLOCKER regression suite — the Quick Add parser was silently recording
//  the WRONG amount on large, decimal, and major+minor (rubles+kopecks) input.
//
//  Each row asserts `QuickAddParser.amountCents(from:convention:) == expectedCents`,
//  run under the decimal convention of the matching launch locale.
//

import Testing
@testable import FinanceTracker

@Suite("QuickAddParser amount tokenizer")
struct QuickAddAmountTokenizerTests {

    // MARK: - ru_RU (comma-decimal: decimal ",", grouping space/NBSP/".")

    @Test func ru_bigDecimal_noGrouping() {
        #expect(QuickAddParser.amountCents(from: "10143,15", convention: .comma) == 1_014_315)
    }

    @Test func ru_bigDecimal_spaceGrouping_withUnit() {
        #expect(QuickAddParser.amountCents(from: "10 143,15 руб.", convention: .comma) == 1_014_315)
    }

    @Test func ru_majorMinor_rublesKopecks() {
        #expect(QuickAddParser.amountCents(from: "1342 рубля 15 копеек", convention: .comma) == 134_215)
    }

    @Test func ru_kopecksOnly() {
        #expect(QuickAddParser.amountCents(from: "50 коп", convention: .comma) == 50)
    }

    @Test func ru_plainInteger() {
        #expect(QuickAddParser.amountCents(from: "1000", convention: .comma) == 100_000)
    }

    // MARK: - en_US (period-decimal: decimal ".", grouping ",")

    @Test func en_commaGrouping_periodDecimal() {
        #expect(QuickAddParser.amountCents(from: "10,143.15", convention: .period) == 1_014_315)
    }

    @Test func en_bigDecimal_noGrouping() {
        #expect(QuickAddParser.amountCents(from: "10143.15", convention: .period) == 1_014_315)
    }

    @Test func en_majorMinor_dollarsCents() {
        #expect(QuickAddParser.amountCents(from: "12 dollars 5 cents", convention: .period) == 1205)
    }

    @Test func en_symbol_commaGrouping() {
        #expect(QuickAddParser.amountCents(from: "$1,342.15", convention: .period) == 134_215)
    }

    // MARK: - es_MX (period-decimal)

    @Test func esMX_commaGrouping_periodDecimal() {
        #expect(QuickAddParser.amountCents(from: "10,143.15", convention: .period) == 1_014_315)
    }

    @Test func esMX_majorMinor_pesosCentavos() {
        #expect(QuickAddParser.amountCents(from: "1342 pesos 15 centavos", convention: .period) == 134_215)
    }

    // MARK: - pt_BR (comma-decimal)

    @Test func ptBR_spaceGrouping_commaDecimal() {
        #expect(QuickAddParser.amountCents(from: "10 143,15", convention: .comma) == 1_014_315)
    }

    @Test func ptBR_majorMinor_reaisCentavos() {
        #expect(QuickAddParser.amountCents(from: "1342 reais 15 centavos", convention: .comma) == 134_215)
    }

    @Test func ptBR_symbol_periodGrouping_commaDecimal() {
        #expect(QuickAddParser.amountCents(from: "R$ 10.143,15", convention: .comma) == 1_014_315)
    }

    // MARK: - uk_UA (comma-decimal)

    @Test func ukUA_spaceGrouping_commaDecimal() {
        #expect(QuickAddParser.amountCents(from: "10 143,15", convention: .comma) == 1_014_315)
    }

    @Test func ukUA_majorMinor_hryvniaKopiyky() {
        #expect(QuickAddParser.amountCents(from: "1342 гривні 15 копійок", convention: .comma) == 134_215)
    }

    // MARK: - Edge cases

    @Test func edge_noDecimals() {
        #expect(QuickAddParser.amountCents(from: "500", convention: .comma) == 50_000)
        #expect(QuickAddParser.amountCents(from: "500", convention: .period) == 50_000)
    }

    @Test func edge_decimalsOnly_comma() {
        #expect(QuickAddParser.amountCents(from: ",15", convention: .comma) == 15)
    }

    @Test func edge_decimalsOnly_period() {
        #expect(QuickAddParser.amountCents(from: ".15", convention: .period) == 15)
    }

    @Test func edge_trailingPeriodAfterUnit() {
        // iOS dictation appends a sentence period after the currency word.
        #expect(QuickAddParser.amountCents(from: "10 143,15 руб.", convention: .comma) == 1_014_315)
    }

    @Test func edge_singleMinorDigit_padsToCents() {
        // "5 копеек" = 5 kopecks = 5 cents, not 500.
        #expect(QuickAddParser.amountCents(from: "5 копеек", convention: .comma) == 5)
    }

    @Test func edge_oneDecimalDigit_padsToTens() {
        // "5,5" = 5.50 = 550 cents.
        #expect(QuickAddParser.amountCents(from: "5,5", convention: .comma) == 550)
    }

    // MARK: - Convention disambiguates the genuinely ambiguous single-3-digit case

    @Test func ambiguous_commaThreeDigits_periodLocale_isGrouping() {
        // "1,234" in en/es-MX = one thousand two hundred thirty-four.
        #expect(QuickAddParser.amountCents(from: "1,234", convention: .period) == 123_400)
    }

    @Test func ambiguous_periodThreeDigits_commaLocale_isGrouping() {
        // "1.234" in ru/pt-BR/uk = one thousand two hundred thirty-four.
        #expect(QuickAddParser.amountCents(from: "1.234", convention: .comma) == 123_400)
    }

    // MARK: - End-to-end device evidence (through the full parse pipeline)
    //
    // These three rows are the confirmed ru_RU device failures. They must parse
    // correctly regardless of the CI locale because each resolves by shape
    // (2 trailing decimal digits, or a major+minor unit pair) rather than by
    // the single-separator ambiguity that needs the locale.

    @Test func device_text_10143comma15() {
        let result = QuickAddParser.parse("10143,15")
        #expect(result?.amountCents == 1_014_315)  // was 15,00 ₽
    }

    @Test func device_text_spaced_10143comma15_rub() {
        let result = QuickAddParser.parse("10 143,15 руб.")
        #expect(result?.amountCents == 1_014_315)  // was 1 014 315,00 ₽
    }

    @Test func device_voice_1342rublya15kopeek() {
        let result = QuickAddParser.parse("1342 рубля 15 копеек")
        #expect(result?.amountCents == 134_215)     // was 15 ₽
    }
}
