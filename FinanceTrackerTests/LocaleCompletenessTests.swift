//
//  LocaleCompletenessTests.swift
//  FinanceTrackerTests
//
//  Guards the Brief 28E decision: v1.0 ships exactly 4 fully-translated
//  locales (EN, RU, ES, pt-BR), each with the same key set as English.
//  A drifting count means a key was added without translating it — which
//  would surface raw keys (e.g. "common.done") in the UI and risk rejection.
//

import XCTest
@testable import FinanceTracker

final class LocaleCompletenessTests: XCTestCase {

    private let locales = ["en", "ru", "es", "pt-BR"]

    private func strings(for localization: String) -> [String: String]? {
        guard let path = Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: localization
        ), let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return nil
        }
        return dict
    }

    func test_all_four_locales_match_english_key_set() throws {
        guard let en = strings(for: "en") else {
            return XCTFail("Missing English Localizable.strings")
        }
        let enKeys = Set(en.keys)
        XCTAssertEqual(enKeys.count, 410, "English baseline changed; update the expected count.")

        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let keys = Set(dict.keys)
            let missing = enKeys.subtracting(keys)
            let extra = keys.subtracting(enKeys)
            XCTAssertTrue(missing.isEmpty, "\(locale) missing keys: \(missing.sorted())")
            XCTAssertTrue(extra.isEmpty, "\(locale) has extra keys not in EN: \(extra.sorted())")
            XCTAssertEqual(dict.count, enKeys.count, "\(locale) has \(dict.count) keys (expected \(enKeys.count))")
        }
    }

    func test_common_done_present_and_not_raw_in_all_locales() {
        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let value = dict["common.done"]
            XCTAssertNotNil(value, "common.done missing in \(locale)")
            XCTAssertFalse((value ?? "").isEmpty, "common.done empty in \(locale)")
            XCTAssertNotEqual(value, "common.done", "common.done is a raw key in \(locale)")
        }
    }

    func test_supported_language_enum_has_exactly_five_cases() {
        // System + EN + RU + ES + pt — anything else means a locale crept back in.
        XCTAssertEqual(SupportedLanguage.allCases.count, 5)
        XCTAssertEqual(Set(SupportedLanguage.allCases.map(\.id)),
                       ["system", "en", "ru", "es", "pt"])
    }
}
