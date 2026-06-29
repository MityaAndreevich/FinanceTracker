import XCTest
@testable import FinanceTracker

final class NumberWordsParserTests: XCTestCase {

    // MARK: - Russian

    func test_ru_single_digit() {
        XCTAssertEqual(NumberWordsParser.normalize("семь", locale: "ru"), "7")
        XCTAssertEqual(NumberWordsParser.normalize("пять", locale: "ru"), "5")
        XCTAssertEqual(NumberWordsParser.normalize("десять", locale: "ru"), "10")
    }

    func test_ru_combined() {
        XCTAssertEqual(NumberWordsParser.normalize("двадцать пять", locale: "ru"), "25")
        XCTAssertEqual(NumberWordsParser.normalize("сто пятьдесят", locale: "ru"), "150")
        XCTAssertEqual(NumberWordsParser.normalize("две тысячи пятьсот", locale: "ru"), "2500")
    }

    func test_ru_in_sentence() {
        XCTAssertEqual(
            NumberWordsParser.normalize("Продал яйца за семь", locale: "ru"),
            "Продал яйца за 7"
        )
        XCTAssertEqual(
            NumberWordsParser.normalize("Купил кофе за пять долларов", locale: "ru"),
            "Купил кофе за 5 долларов"
        )
    }

    func test_ru_mixed_digit_and_words() {
        // Already has digit — pass through
        XCTAssertEqual(NumberWordsParser.normalize("кофе 5 долларов", locale: "ru"), "кофе 5 долларов")
    }

    func test_ru_thousands() {
        XCTAssertEqual(NumberWordsParser.normalize("пятьдесят тысяч", locale: "ru"), "50000")
    }

    // MARK: - English

    func test_en_combined() {
        XCTAssertEqual(NumberWordsParser.normalize("twenty five", locale: "en"), "25")
        XCTAssertEqual(NumberWordsParser.normalize("one hundred fifty", locale: "en"), "150")
        XCTAssertEqual(NumberWordsParser.normalize("two thousand five hundred", locale: "en"), "2500")
    }

    func test_en_in_sentence() {
        XCTAssertEqual(
            NumberWordsParser.normalize("bought coffee for twelve dollars", locale: "en"),
            "bought coffee for 12 dollars"
        )
    }

    // MARK: - Spanish

    func test_es_basic() {
        XCTAssertEqual(NumberWordsParser.normalize("siete", locale: "es"), "7")
        XCTAssertEqual(NumberWordsParser.normalize("veinticinco", locale: "es"), "25")
    }

    // MARK: - Integration with QuickAddParser

    func test_parser_integration_ru() {
        UserDefaults.standard.set("ru", forKey: "appLanguageCode")
        defer { UserDefaults.standard.removeObject(forKey: "appLanguageCode") }

        let result = QuickAddParser.parse("продал яйца за семь")
        XCTAssertEqual(result?.amountCents, 700)
        XCTAssertEqual(result?.typeRaw, "income")
    }

    func test_parser_integration_en() {
        UserDefaults.standard.set("en", forKey: "appLanguageCode")
        defer { UserDefaults.standard.removeObject(forKey: "appLanguageCode") }

        let result = QuickAddParser.parse("bought coffee for twelve dollars")
        XCTAssertEqual(result?.amountCents, 1200)
        XCTAssertEqual(result?.typeRaw, "expense")
    }

    // MARK: - Colloquial "тыщ" → 1000 (Brief 28F P1-1 / P1-7)

    func test_ru_slang_тыщ() {
        XCTAssertEqual(NumberWordsParser.normalize("пять тыщ", locale: "ru"), "5000")
        XCTAssertEqual(
            NumberWordsParser.normalize("Продал велик за пять тыщ", locale: "ru"),
            "Продал велик за 5000"
        )
    }

    func test_combined_тыщ_velik() {
        UserDefaults.standard.set("ru", forKey: "appLanguageCode")
        defer { UserDefaults.standard.removeObject(forKey: "appLanguageCode") }

        let result = QuickAddParser.parse("продал велик за пять тыщ")
        XCTAssertEqual(result?.amountCents, 500_000)
        XCTAssertEqual(result?.typeRaw, "income")
        XCTAssertEqual(result?.merchant, "Велик")   // capitalized first letter per Bug 5
    }

    // MARK: - Cross-locale number words (Bug 2)
    //
    // iOS dictation can transcribe in a different language than the app UI, so a
    // spelled-out number must parse regardless of the active app language.

    func test_crossLocale_fifteen_resolves_in_any_app_language() {
        XCTAssertEqual(NumberWordsParser.normalize("fifteen", primaryLocale: "ru"), "15")
        XCTAssertEqual(NumberWordsParser.normalize("пятнадцать", primaryLocale: "en"), "15")
        XCTAssertEqual(NumberWordsParser.normalize("quince", primaryLocale: "en"), "15")
        XCTAssertEqual(NumberWordsParser.normalize("quinze", primaryLocale: "en"), "15")
    }

    func test_crossLocale_primary_wins_when_it_matches() {
        // RU primary converts its own word; no fallback needed.
        XCTAssertEqual(NumberWordsParser.normalize("семь", primaryLocale: "ru"), "7")
    }

    func test_crossLocale_digit_present_skips_fallback() {
        // Already has a digit → no cross-language guessing on surrounding words.
        XCTAssertEqual(NumberWordsParser.normalize("una pizza 5", primaryLocale: "ru"), "una pizza 5")
    }

    func test_crossLocale_parser_ru_app_english_spoken() {
        UserDefaults.standard.set("ru", forKey: "appLanguageCode")
        defer { UserDefaults.standard.removeObject(forKey: "appLanguageCode") }

        let result = QuickAddParser.parse("bought pizza for fifteen")
        XCTAssertEqual(result?.amountCents, 1500)
        XCTAssertEqual(result?.typeRaw, "expense")
    }
}
