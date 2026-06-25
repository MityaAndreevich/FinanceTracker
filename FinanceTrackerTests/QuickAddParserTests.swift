//
//  QuickAddParserTests.swift
//  FinanceTrackerTests
//

import Testing
@testable import FinanceTracker

@Suite("QuickAddParser")
struct QuickAddParserTests {

    @Test func parse_amount_only_no_merchant() {
        let result = QuickAddParser.parse("$5.50")
        #expect(result?.amountCents == 550)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == nil)
        #expect(result?.suggestedCategoryName == nil)
    }

    @Test func parse_amount_merchant_category() {
        let result = QuickAddParser.parse("$5.50 Starbucks")
        #expect(result?.amountCents == 550)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Starbucks")
        // Starbucks is a coffee brand now mapped to the consolidated Food & Drink category
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_income_with_plus_sign() {
        let result = QuickAddParser.parse("+2800 paycheck")
        #expect(result?.amountCents == 280000)
        #expect(result?.typeRaw == "income")
    }

    @Test func parse_european_decimal() {
        let result = QuickAddParser.parse("12,99 spotify")
        #expect(result?.amountCents == 1299)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "spotify")
        #expect(result?.suggestedCategoryName == "Subscriptions")
    }

    @Test func parse_empty_returns_nil() {
        #expect(QuickAddParser.parse("") == nil)
    }

    @Test func parse_no_amount_returns_nil() {
        #expect(QuickAddParser.parse("just text") == nil)
    }

    // MARK: - EN new keywords

    @Test func parse_income_en_gotPaid() {
        let result = QuickAddParser.parse("3000 got paid by Company")
        #expect(result?.amountCents == 300000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Company")
    }

    @Test func parse_income_en_made() {
        let result = QuickAddParser.parse("500 made from Client")
        #expect(result?.amountCents == 50000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Client")
    }

    // MARK: - Spanish (ES)

    @Test func parse_income_es() {
        let result = QuickAddParser.parse("200 gané en supermercado")
        #expect(result?.amountCents == 20000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "supermercado")
    }

    @Test func parse_prefixStrip_es() {
        let result = QuickAddParser.parse("2000 salario desde Empresa")
        #expect(result?.amountCents == 200000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Empresa")
    }

    // MARK: - German (DE)

    @Test func parse_income_de() {
        let result = QuickAddParser.parse("1500 verdient von Arbeitgeber")
        #expect(result?.amountCents == 150000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Arbeitgeber")
    }

    @Test func parse_prefixStrip_de() {
        let result = QuickAddParser.parse("3000 Gehalt von Firma")
        #expect(result?.amountCents == 300000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Firma")
    }

    // MARK: - French (FR)

    @Test func parse_income_fr() {
        let result = QuickAddParser.parse("300 gagné de supermarché")
        #expect(result?.amountCents == 30000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "supermarché")
    }

    @Test func parse_prefixStrip_fr() {
        let result = QuickAddParser.parse("2500 salaire depuis Entreprise")
        #expect(result?.amountCents == 250000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Entreprise")
    }

    // MARK: - Portuguese Brazil (PT-BR)

    @Test func parse_income_ptBR() {
        let result = QuickAddParser.parse("500 ganhei de mercado")
        #expect(result?.amountCents == 50000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "mercado")
    }

    @Test func parse_prefixStrip_ptBR() {
        let result = QuickAddParser.parse("3000 salário da Empresa")
        #expect(result?.amountCents == 300000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Empresa")
    }

    // MARK: - Japanese (JA)

    @Test func parse_income_ja() {
        let result = QuickAddParser.parse("50000 ボーナス")
        #expect(result?.amountCents == 5000000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == nil)
    }

    @Test func parse_prefixStrip_ja() {
        let result = QuickAddParser.parse("50000 入金 から会社")
        #expect(result?.amountCents == 5000000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "会社")
    }

    // MARK: - Chinese Simplified (zh-Hans)

    @Test func parse_income_zhHans() {
        let result = QuickAddParser.parse("5000 工资")
        #expect(result?.amountCents == 500000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == nil)
    }

    @Test func parse_prefixStrip_zhHans() {
        let result = QuickAddParser.parse("5000 赚了 从Amazon")
        #expect(result?.amountCents == 500000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Amazon")
    }
}
