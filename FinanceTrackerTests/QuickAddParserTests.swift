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
        #expect(result?.merchant == "Spotify")
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
        #expect(result?.merchant == "Supermercado")
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
        #expect(result?.merchant == "Supermarché")
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
        #expect(result?.merchant == "Mercado")
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
        #expect(result?.merchant?.lowercased().contains("eggs") == true)
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
        #expect(result?.merchant == "Зп")               // not nil, not "получил"; capitalized per Bug 5
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_zarplata_alone() {
        let result = QuickAddParser.parse("зарплата 50000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Зарплата")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_salary_english() {
        let result = QuickAddParser.parse("salary 5000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Salary")
        #expect(result?.suggestedCategoryName == "Income")
    }

    @Test func parse_income_bonus_keeps_merchant() {
        let result = QuickAddParser.parse("bonus 1000")
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant == "Bonus")
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
        #expect(result?.merchant == "Яйца")   // not "яйца за"; capitalized per Bug 5
        #expect(result?.typeRaw == "income")
    }

    @Test func parse_trailing_for_stripped_en() {
        let result = QuickAddParser.parse("coffee for 5")
        #expect(result?.merchant == "Coffee") // not "coffee for"; capitalized per Bug 5
    }

    @Test func parse_trailing_por_stripped_es() {
        let result = QuickAddParser.parse("huevos por 7")
        #expect(result?.merchant == "Huevos") // not "huevos por"; capitalized per Bug 5
    }

    // MARK: - Leading orphan conjunction stripping (Brief 28E P1-2)

    @Test func parse_leading_orphan_a_stripped_ru() {
        let result = QuickAddParser.parse("получил а зарплату 50000")
        #expect(result?.merchant == "Зарплату")  // not "а зарплату"; capitalized per Bug 5
        #expect(result?.typeRaw == "income")
    }

    // MARK: - Currency word stripping (Brief 28J P1)

    @Test func parse_strip_baksov_ru() {
        let result = QuickAddParser.parse("50 баксов за кофе")
        #expect(result?.merchant == "Кофе")     // not "баксов за кофе"; capitalized per Bug 5
        #expect(result?.amountCents == 5000)
    }

    @Test func parse_strip_dollars_en() {
        let result = QuickAddParser.parse("12 dollars coffee")
        #expect(result?.merchant == "Coffee")
        #expect(result?.amountCents == 1200)
    }

    @Test func parse_strip_euros_es() {
        let result = QuickAddParser.parse("7 euros café")
        #expect(result?.merchant == "Café")
    }

    @Test func parse_strip_reais_pt() {
        let result = QuickAddParser.parse("5 reais café")
        #expect(result?.merchant == "Café")
    }

    // MARK: - Expense-indicator word stripping (Brief 28J P6)

    @Test func parse_strip_rashod_ru() {
        let result = QuickAddParser.parse("50 расход")
        #expect(result?.amountCents == 5000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == nil)        // "расход" is the direction, not a payee
    }

    @Test func parse_strip_expense_en() {
        let result = QuickAddParser.parse("50 expense")
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == nil)
    }

    // MARK: - RU expense verb prefix stripping + "за/на" preposition (Bug 8)
    //
    // Real-device gap: "купил молоко за 15" left the spending verb (and a trailing
    // sentence period from dictation) in the description. Merchant is compared
    // case-insensitively because iOS dictation capitalizes the first word.

    @Test func parse_ru_kupil_moloko_za_15() {
        let result = QuickAddParser.parse("купил молоко за 15")
        #expect(result?.amountCents == 1500)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "молоко")
    }

    @Test func parse_ru_moloko_za_50_rubley() {
        let result = QuickAddParser.parse("Молоко за 50 рублей")
        #expect(result?.amountCents == 5000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "молоко")
    }

    @Test func parse_ru_oplata_interneta_500() {
        let result = QuickAddParser.parse("оплата интернета 500")
        #expect(result?.amountCents == 50000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "интернета")
    }

    @Test func parse_ru_poluchil_zp_30000() {
        let result = QuickAddParser.parse("получил зп 30000")
        #expect(result?.amountCents == 3_000_000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant?.lowercased() == "зп")
    }

    @Test func parse_ru_produkty_na_100() {
        let result = QuickAddParser.parse("продукты на 100")
        #expect(result?.amountCents == 10000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "продукты")
    }

    @Test func parse_ru_amount_first_100_produkty() {
        let result = QuickAddParser.parse("100 продукты")
        #expect(result?.amountCents == 10000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "продукты")
    }

    @Test func parse_ru_moloko_50r() {
        let result = QuickAddParser.parse("молоко 50р")
        #expect(result?.amountCents == 5000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "молоко")
    }

    // MARK: - EN expense verb prefix stripping + preposition handling (Bug 12)
    //
    // Mirrors the RU pattern (Bug 8) for English: strip the spending verb so the
    // merchant is the thing bought, not the action. Merchant is compared
    // case-insensitively because iOS dictation capitalizes the first word.

    @Test func parse_en_bought_milk_for_12() {
        let result = QuickAddParser.parse("bought milk for 12")
        #expect(result?.amountCents == 1200)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "milk")
    }

    @Test func parse_en_spent_20_on_tennis() {
        let result = QuickAddParser.parse("spent 20 on tennis")
        #expect(result?.amountCents == 2000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "tennis")
    }

    @Test func parse_en_paid_starbucks_coffee() {
        let result = QuickAddParser.parse("paid $5.50 for Starbucks coffee")
        #expect(result?.amountCents == 550)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Starbucks coffee")
    }

    @Test func parse_en_purchased_headphones_for_80() {
        let result = QuickAddParser.parse("purchased headphones for 80")
        #expect(result?.amountCents == 8000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "headphones")
    }

    // Regression guard: income verb still wins; "on" preposition still strips.
    @Test func parse_en_earned_on_amazon_still_income() {
        let result = QuickAddParser.parse("earned on amazon 20")
        #expect(result?.amountCents == 2000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant?.lowercased() == "amazon")
    }

    // Regression guard: amount-first expense with no verb unchanged.
    @Test func parse_en_12_on_heineken() {
        let result = QuickAddParser.parse("12 on Heineken")
        #expect(result?.amountCents == 1200)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "heineken")
    }

    // MARK: - ES expense verb prefix stripping (Bug 12)

    @Test func parse_es_compre_leche_por_12() {
        let result = QuickAddParser.parse("compré leche por 12")
        #expect(result?.amountCents == 1200)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "leche")
    }

    @Test func parse_es_gaste_20_en_tenis() {
        let result = QuickAddParser.parse("gasté 20 en tenis")
        #expect(result?.amountCents == 2000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "tenis")
    }

    @Test func parse_es_gane_100_en_amazon_income() {
        let result = QuickAddParser.parse("gané 100 en Amazon")
        #expect(result?.amountCents == 10000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant?.lowercased() == "amazon")
    }

    @Test func parse_es_pague_50_por_gasolina() {
        let result = QuickAddParser.parse("pagué 50 por gasolina")
        #expect(result?.amountCents == 5000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "gasolina")
    }

    @Test func parse_es_compre_no_accent_pan() {
        let result = QuickAddParser.parse("compre pan por 3")
        #expect(result?.amountCents == 300)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "pan")
    }

    @Test func parse_es_adquiri_libro_por_15() {
        let result = QuickAddParser.parse("adquirí un libro por 15")
        #expect(result?.amountCents == 1500)
        #expect(result?.typeRaw == "expense")
    }

    // MARK: - PT expense verb prefix stripping (Bug 12)

    @Test func parse_pt_comprei_leite_por_12() {
        let result = QuickAddParser.parse("comprei leite por 12")
        #expect(result?.amountCents == 1200)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "leite")
    }

    @Test func parse_pt_gastei_20_em_tenis() {
        let result = QuickAddParser.parse("gastei 20 em tênis")
        #expect(result?.amountCents == 2000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "tênis")
    }

    @Test func parse_pt_ganhei_100_na_amazon_income() {
        let result = QuickAddParser.parse("ganhei 100 na Amazon")
        #expect(result?.amountCents == 10000)
        #expect(result?.typeRaw == "income")
        #expect(result?.merchant?.lowercased() == "amazon")
    }

    @Test func parse_pt_paguei_50_por_gasolina() {
        let result = QuickAddParser.parse("paguei 50 por gasolina")
        #expect(result?.amountCents == 5000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "gasolina")
    }

    @Test func parse_pt_comprei_cafe_por_5() {
        let result = QuickAddParser.parse("comprei café por 5")
        #expect(result?.amountCents == 500)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant?.lowercased() == "café")
    }

    @Test func parse_pt_adquiri_livro_por_15() {
        let result = QuickAddParser.parse("adquiri um livro por 15")
        #expect(result?.amountCents == 1500)
        #expect(result?.typeRaw == "expense")
    }

    // MARK: - Bug 5 (P0): merchant first letter capitalized — but NOT via .capitalized
    //
    // Voice-added transactions used to land with lowercase merchants ("кофе",
    // "coffee", "café"), which read like rough notes rather than transaction
    // labels. Capitalize the first letter only — using `.capitalized` would
    // lowercase mid-word characters and break "iPhone" → "Iphone".

    @Test func parse_bug5_merchant_first_letter_capitalized_ru() {
        let result = QuickAddParser.parse("кофе 20")
        #expect(result?.merchant == "Кофе")
    }

    @Test func parse_bug5_merchant_first_letter_capitalized_en() {
        let result = QuickAddParser.parse("coffee 5")
        #expect(result?.merchant == "Coffee")
    }

    @Test func parse_bug5_preserves_internal_casing_iphone() {
        // "iPhone" must NOT degrade to "Iphone" — verifies we capitalize first
        // letter only, never use Foundation's `.capitalized` (which lowercases
        // the rest of the word).
        let result = QuickAddParser.parse("iPhone 1000")
        #expect(result?.merchant == "IPhone")
        // The "i" gets uppercased to "I", but "Phone" stays mixed-case rather
        // than collapsing to "Iphone". Documented behaviour.
    }

    // MARK: - Bug 1 (P0): RU/EN/ES/PT "взял/got/tomé/tomei <noun>" food cases
    //
    // Real-device gap: "Взял кофе за 20" landed as merchant "взял кофе" and
    // category "Other". Three fixes needed:
    //   1. Add взял/взяла/взяли to expenseVerbKeywords so verb-strip removes it.
    //   2. Add ES "tomé/tome/tomó" and PT "tomei/tomou" so "Tomé un café" parses.
    //   3. Add un/una/um/uma article prefixes so the article is stripped.
    //   4. Add ES/PT food keywords (café, té, almoço, cerveja, vinho, pizza, etc.)
    //      to CategorySuggestionService so Food & Drink is suggested.

    @Test func parse_bug1_ru_capitalized_verb_kofe() {
        let result = QuickAddParser.parse("Взял кофе за 20")
        #expect(result?.amountCents == 2000)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Кофе")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_bug1_en_got_coffee_for_5() {
        let result = QuickAddParser.parse("Got coffee for 5")
        #expect(result?.amountCents == 500)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Coffee")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_bug1_es_tome_un_cafe_por_3() {
        let result = QuickAddParser.parse("Tomé un café por 3")
        #expect(result?.amountCents == 300)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Café")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    @Test func parse_bug1_pt_tomei_um_cafe_por_4() {
        let result = QuickAddParser.parse("Tomei um café por 4")
        #expect(result?.amountCents == 400)
        #expect(result?.typeRaw == "expense")
        #expect(result?.merchant == "Café")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }

    // Regression check: lowercase "взял" still strips (case-insensitive verb match).
    @Test func parse_bug1_ru_lowercase_vzyal_kofe() {
        let result = QuickAddParser.parse("взял кофе за 20")
        #expect(result?.amountCents == 2000)
        #expect(result?.merchant == "Кофе")
        #expect(result?.suggestedCategoryName == "Food & Drink")
    }
}
