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
        // Bug #4: an income noun that is the only content is kept as the merchant.
        #expect(result?.merchant == "ボーナス")
        #expect(result?.suggestedCategoryName == "Income")
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
        // Bug #4: an income noun that is the only content is kept as the merchant.
        #expect(result?.merchant == "工资")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_prefixStrip_zhHans() {
        let result = QuickAddParser.parse("5000 赚了 从Amazon")
        #expect(result?.amountCents == 500000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Amazon")
    }

    // MARK: - RU colloquial / real-device gaps (Bug #1)

    @Test func parse_income_ru_получилЗп() {
        let result = QuickAddParser.parse("получил зп 50000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 5_000_000)
    }

    @Test func parse_income_ru_shortЗп() {
        let result = QuickAddParser.parse("зп 50000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 5_000_000)
    }

    @Test func parse_expense_яйца() {
        let result = QuickAddParser.parse("яйца 5 баксов")
        #expect(result?.typeRaw == "expense")
        #expect(result?.amountCents == 500)
    }

    @Test func parse_income_ru_amountFirstThenЗп() {
        let result = QuickAddParser.parse("5 баксов зп")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 500)
    }

    @Test func parse_income_transliteration_poluchilZp() {
        let result = QuickAddParser.parse("poluchil zp 5000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 500000)
    }

    @Test func parse_income_ru_премия() {
        let result = QuickAddParser.parse("премия 2000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 200000)
    }

    @Test func parse_income_ru_аванс() {
        let result = QuickAddParser.parse("аванс 5000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 500000)
    }

    // MARK: - "sold" income verbs (Bug #2)

    @Test func parse_income_prodal_basic() {
        let result = QuickAddParser.parse("продал яйца за 7")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 700)
    }

    @Test func parse_income_prodala() {
        let result = QuickAddParser.parse("продала велик 5000")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 500000)
    }

    @Test func parse_income_sold_english() {
        let result = QuickAddParser.parse("sold my bike 200")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 20000)
    }

    @Test func parse_income_sold_es() {
        let result = QuickAddParser.parse("vendí mi coche 3000")
        #expect(result?.typeRaw == "income")
    }

    @Test func parse_income_sold_de() {
        let result = QuickAddParser.parse("verkauft Fahrrad 200")
        #expect(result?.typeRaw == "income")
    }

    // MARK: - Multi-number amount detection (Bug #3)

    @Test func parse_multinumber_bought_3_eggs_for_7() {
        let result = QuickAddParser.parse("bought 3 eggs for 7")
        #expect(result?.amountCents == 700)   // price after "for", not the quantity 3
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.contains("eggs") == true)
    }

    @Test func parse_multinumber_kupil_5_eggs_for_7() {
        let result = QuickAddParser.parse("купил 5 яиц за 7 евро")
        #expect(result?.amountCents == 700)
        #expect(result?.typeRaw == "expense")
    }

    @Test func parse_multinumber_currency_symbol_priority() {
        let result = QuickAddParser.parse("5 coffee $7")
        #expect(result?.amountCents == 700)   // $7 wins on currency-symbol adjacency
    }

    @Test func parse_single_number_unchanged() {
        let result = QuickAddParser.parse("яйца 5 баксов")
        #expect(result?.amountCents == 500)
    }

    @Test func parse_multinumber_no_preposition_takes_last() {
        let result = QuickAddParser.parse("получил 3 яйца 200")
        #expect(result?.amountCents == 20000)  // last number when no price marker
        #expect(result?.typeRaw == "income")
    }

    // MARK: - Income nouns keep merchant + map to the Income category (Bug #4)
    //
    // The taxonomy has a single income category ("Income"), so income nouns suggest
    // that rather than inventing per-noun categories or falling back to "Other".

    @Test func parse_income_zp_keeps_merchant_and_maps_income() {
        let result = QuickAddParser.parse("получил зп 200")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 20000)
        #expect(result?.merchant == "зп")               // not nil, not "получил"
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_zarplata_alone() {
        let result = QuickAddParser.parse("зарплата 50000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "зарплата")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_salary_english() {
        let result = QuickAddParser.parse("salary 5000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "salary")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_bonus_keeps_merchant() {
        let result = QuickAddParser.parse("bonus 1000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "bonus")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_refund_es() {
        let result = QuickAddParser.parse("reembolso 50 euros")
        #expect(result?.typeRaw == "income")
        #expect(result?.amountCents == 5000)
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_expense_does_not_match_income_noun() {
        let result = QuickAddParser.parse("яйца 5 баксов")
        #expect(result?.typeRaw == "expense")
        // "яйца" (eggs) is an expense, never an income noun. Since Brief 28D Bug #4
        // it also maps to Food & Drink rather than no category.
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    // MARK: - Trailing preposition stripping (Brief 28E P1-1)

    @Test func parse_trailing_za_stripped_ru() {
        let result = QuickAddParser.parse("продал яйца за 7")
        #expect(result?.merchant == "яйца")   // not "яйца за"
        #expect(result?.typeRaw == "income")
    }

    @Test func parse_trailing_for_stripped_en() {
        let result = QuickAddParser.parse("coffee for 5")
        #expect(result?.merchant == "coffee") // not "coffee for"
    }

    @Test func parse_trailing_por_stripped_es() {
        let result = QuickAddParser.parse("huevos por 7")
        #expect(result?.merchant == "huevos") // not "huevos por"
    }

    // MARK: - Leading orphan conjunction stripping (Brief 28E P1-2)

    @Test func parse_leading_orphan_a_stripped_ru() {
        let result = QuickAddParser.parse("получил а зарплату 50000")
        #expect(result?.merchant == "зарплату")  // not "а зарплату"
        #expect(result?.typeRaw == "income")
    }
}
