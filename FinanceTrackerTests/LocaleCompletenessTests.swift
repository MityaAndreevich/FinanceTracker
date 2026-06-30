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
        // Bumped 2026-06-29 (Bug 12/Q1-C): +1 auto-save toast key
        // (quickadd.saved.tap_to_edit). Was 493.
        // Bumped 2026-06-29 (Quick Add sensitivity setting): +5 keys — label,
        // caption, and 3 segment labels (confirm/balanced/instant). The brief
        // estimated +3, but a 3-position picker plus its label and caption needs
        // 5 distinct strings. Was 494.
        // Bumped 2026-06-29 (shake-to-undo): +1 undo confirmation toast key
        // (quickadd.undo.confirmed). Was 499.
        // Bumped 2026-06-30 (Bug 17): +4 add-transaction error keys referenced via
        // showErrorKey(...) but missing from ALL locales — they leaked raw to the
        // user (add.error.unknown/select_category/invalid_amount/save_failed). Was 500.
        // Bumped 2026-06-30 (Bug 7): +2 pre-purchase trial disclosure modal keys
        // (paywall.trial.modal.title, paywall.trial.modal.body). Was 504.
        // Bumped 2026-06-30 (Sprint B Bug 18): +1 duplicate-category-name error key
        // (category.error.duplicate_name). Was 506.
        // Bumped 2026-06-30 (Sprint B patch Bug 6): +1 DEBUG-only redeem-code hint
        // documenting the local-StoreKit code-redemption limitation
        // (premium.redeem.debug_hint). Was 507.
        // Bumped 2026-06-30 (Brief 35 Bug 19): +3 general.* keys that leaked raw in the
        // Reset alert — referenced via the showInfo(titleKey:messageKey:) helper and the
        // infoMessageKey @State default, so the old scanner never saw them
        // (general.reset_success.message, general.reset_failed.message,
        // general.info.default). testAllLocalizedKeysExist was also strengthened to
        // catch the `…Key:` argument / `…Key =` assignment class. Was 508.
        // Bumped 2026-06-30 (Brief 36 Bug 34.5): +1 category-specific save-error key
        // (category.error.save_failed). AddCategorySheet was showing the TRANSACTION
        // error (add.error.save_failed → "Не удалось сохранить транзакцию") when a
        // category save failed. Was 511.
        XCTAssertEqual(enKeys.count, 512, "English baseline changed; update the expected count.")

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

    /// Stronger sibling of `testNoMissingLocalizationKeys`: every key referenced
    /// in code must exist in **every** shipping locale, not just the EN master.
    /// This is what would have caught the Bug 17 leak in non-EN locales too.
    func testAllLocalizedKeysExist() throws {
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FinanceTracker")

        let referenced = scanCodebaseForLocalizationKeys(in: sourceDir)
        XCTAssertFalse(referenced.isEmpty, "Scanner found no keys — path wrong? \(sourceDir.path)")

        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let present = Set(dict.keys)
            let missing = referenced.subtracting(present)
            XCTAssertTrue(missing.isEmpty,
                "\(locale) is missing localization keys referenced in code:\n" +
                missing.sorted().joined(separator: "\n"))
        }
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
        // Codebase-specific helpers that take a localization key as a plain String
        // — these are how the add.error.* leak shipped (Bug 17): showErrorKey("…")
        // and fail(key: "…").
        let helperCallSite = try! NSRegularExpression(pattern:
            #"(?:showErrorKey\s*\(|fail\s*\(\s*key:)\s*"([^"]+)""#)
        // Bug 19: the Reset alert leaked raw keys because they flow through a
        // showInfo(titleKey:messageKey:) helper and an `infoMessageKey` @State
        // default — neither a recognized localizing construct nor a
        // showErrorKey/fail call, so the scanner above never saw them. Generalize
        // to the whole class: any argument label OR stored property whose name ends
        // in `Key` carrying a dotted-key string literal. The dotted-shape filter
        // (isDotted) below discards non-localization matches like
        // `forKey: "AppleLanguages"`. Covers titleKey:/messageKey:/nameKey:/
        // labelKey:/textKey: arguments and `saveErrorKey =` / `infoMessageKey:
        // String = …` assignments and comparisons.
        let keyTypedArg = try! NSRegularExpression(pattern:
            #"[A-Za-z_]*[Kk]ey\s*:\s*"([^"]+)""#)
        let keyTypedAssign = try! NSRegularExpression(pattern:
            #"[A-Za-z_]*[Kk]ey[^"\n]*=\s*"([^"]+)""#)
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
            for regex in [callSite, helperCallSite, keyTypedArg, keyTypedAssign] {
                regex.enumerateMatches(in: src, range: range) { match, _, _ in
                    guard let m = match, let r = Range(m.range(at: 1), in: src) else { return }
                    let key = String(src[r])
                    if isDotted(key) { keys.insert(key) }
                }
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
