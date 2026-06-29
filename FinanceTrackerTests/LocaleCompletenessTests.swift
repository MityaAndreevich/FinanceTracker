//
//  LocaleCompletenessTests.swift
//  FinanceTrackerTests
//
//  Guards the locale parity decision: v1.0 ships 5 fully-translated locales
//  (EN, RU, ES, pt-BR, UK), each with the same key set as English (491 keys ×
//  5 locales = 2,455 entries). A drifting count means a key was added without
//  translating it — which would surface raw keys (e.g. "common.done") in the UI
//  and risk rejection.
//

import XCTest
@testable import FinanceTracker

final class LocaleCompletenessTests: XCTestCase {

    private let locales = ["en", "ru", "es", "pt-BR", "uk"]

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
        // Bumped 2026-06-28 (Wave 1 Fix #3): +3 yearly plan framing keys
        // (paywall.yearly.best_value, paywall.yearly.save_amount, paywall.yearly.per_month). Was 461 before this pass.
        // Lowered 2026-06-28 (Wave 3 Fix #14 prune): −4 onboarding keys made dead by
        // language auto-detect (onboarding.language.title/subtitle, onboarding.next/back). Was 464.
        // Bumped 2026-06-28 (Fix 1): +4 Horizon mode-toggle keys
        // (analytics.horizon.mode.net/expenses/income/combined). Was 460.
        // Bumped 2026-06-28 (Fix 5): +4 restored onboarding language-screen keys
        // (onboarding.language.title/subtitle, onboarding.next/back). Was 464.
        // Bumped 2026-06-28 (Round 10 i18n leak fix): +21 keys referenced in code but
        // missing from ALL locales — 10 tx_detail.* (raw-key leak in TransactionDetailView),
        // 10 data.* import/export results (DataSettingsView), premium.section.manage. Was 468.
        // Bumped 2026-06-29 (Bug 9): +2 add-confirmation toast keys
        // (cs.toast.category_added, cs.toast.source_added). Was 489.
        // Bumped 2026-06-29 (Bug 5): +1 Apple §3.1.2(a) trial disclosure key
        // (paywall.trial.disclosure). Was 491.
        // Bumped 2026-06-29 (Bug 7): +1 voice fallback key
        // (voice.unavailable_for_lang). Was 492.
        XCTAssertEqual(enKeys.count, 493, "English baseline changed; update the expected count.")

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

    // MARK: - Code ↔ strings completeness (catches the Round 10 raw-key leak)

    /// The parity tests above only compare locales to *each other*. They cannot
    /// catch a key that is referenced in code but missing from **every** locale —
    /// which is exactly how `tx_detail.*` shipped as raw keys. This test scans the
    /// Swift source for localization call-sites and asserts every referenced key
    /// exists in the EN master `.strings`.
    func testNoMissingLocalizationKeys() throws {
        let sourceDir = URL(fileURLWithPath: #filePath)   // …/FinanceTrackerTests/LocaleCompletenessTests.swift
            .deletingLastPathComponent()                  // …/FinanceTrackerTests
            .deletingLastPathComponent()                  // …/ (repo root)
            .appendingPathComponent("FinanceTracker")     // …/FinanceTracker (app sources)

        let referenced = scanCodebaseForLocalizationKeys(in: sourceDir)
        XCTAssertFalse(referenced.isEmpty, "Scanner found no keys — path wrong? \(sourceDir.path)")

        let masterURL = sourceDir.appendingPathComponent("en.lproj/Localizable.strings")
        let master = parseStringsFile(try String(contentsOf: masterURL, encoding: .utf8))

        let missing = referenced.subtracting(master)
        XCTAssertTrue(missing.isEmpty,
            "Localization keys referenced in code but absent from en.lproj/Localizable.strings:\n" +
            missing.sorted().joined(separator: "\n"))
    }

    /// Extracts dotted localization keys from Swift localization call-sites.
    /// `systemImage:` / `systemName:` arguments are stripped first so SF Symbol
    /// names (e.g. "house.fill") are never mistaken for keys. Only the first
    /// string argument of a known localizing construct is considered, and only
    /// when it matches a dotted `a.b.c` key shape.
    private func scanCodebaseForLocalizationKeys(in directory: URL) -> Set<String> {
        // swiftlint:disable:next force_try
        let callSite = try! NSRegularExpression(pattern:
            #"(?:NSLocalizedString|String\(localized:|LocalizedStringKey|Text|Section|Button|Label|Toggle|Picker|row|navigationTitle|navigationBarTitle|confirmationDialog|alert|tabItem|header:\s*Text)\s*\(\s*"([^"]+)""#)
        let symbolArg = try! NSRegularExpression(pattern: #"system(?:Image|Name):\s*"[^"]+""#)
        let dotted = try! NSRegularExpression(pattern: #"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$"#)

        func isDotted(_ s: String) -> Bool {
            dotted.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        var keys = Set<String>()
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else { return keys }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard var src = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // Neutralize SF Symbol args so they can't be read as keys.
            src = symbolArg.stringByReplacingMatches(
                in: src, range: NSRange(src.startIndex..., in: src), withTemplate: "systemImage: SYMBOL")
            let range = NSRange(src.startIndex..., in: src)
            callSite.enumerateMatches(in: src, range: range) { match, _, _ in
                guard let m = match, let r = Range(m.range(at: 1), in: src) else { return }
                let key = String(src[r])
                if isDotted(key) { keys.insert(key) }
            }
        }
        return keys
    }

    /// Parses the keys out of a `.strings` file (`"key" = "value";`).
    private func parseStringsFile(_ content: String) -> Set<String> {
        // swiftlint:disable:next force_try
        let keyLine = try! NSRegularExpression(pattern: #"^\s*"([^"]+)"\s*="#, options: [.anchorsMatchLines])
        var keys = Set<String>()
        let range = NSRange(content.startIndex..., in: content)
        keyLine.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let m = match, let r = Range(m.range(at: 1), in: content) else { return }
            keys.insert(String(content[r]))
        }
        return keys
    }

    func test_supported_language_enum_has_exactly_six_cases() {
        // System + EN + RU + ES + pt + uk — anything else means a locale drifted.
        XCTAssertEqual(SupportedLanguage.allCases.count, 6)
        XCTAssertEqual(Set(SupportedLanguage.allCases.map(\.id)),
                       ["system", "en", "ru", "es", "pt", "uk"])
    }
}
