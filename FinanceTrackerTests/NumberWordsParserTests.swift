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
}
