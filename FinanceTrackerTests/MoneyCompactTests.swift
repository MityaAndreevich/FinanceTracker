//
//  MoneyCompactTests.swift
//  FinanceTrackerTests
//
//  Money.formatCompact — the glance/widget currency path. Whole dollars below
//  $10K stay legible with grouping separators; larger values fold to locale-aware
//  short notation so nothing truncates on a Home Screen widget.
//

import Testing
import Foundation
@testable import FinanceTracker

@Suite("Money.formatCompact")
struct MoneyCompactTests {

    private let en = Locale(identifier: "en_US")
    private let ru = Locale(identifier: "ru_RU")
    private let ptBR = Locale(identifier: "pt_BR")

    // MARK: - Threshold behaviour

    @Test func belowThreshold_showsGroupedWholeDollars_noCents() {
        // 123_400 cents == $1,234.00 → grouped, no cents.
        let s = Money.formatCompact(cents: 123_400, currencyCode: "USD", locale: en)
        #expect(s.contains("1,234"))
        #expect(!s.contains(".00"))
        #expect(!s.contains("."))   // no decimal point at all below threshold
    }

    @Test func atOrAboveThreshold_foldsToCompactK() {
        // 1_234_500 cents == $12,345 → compact "$12.3K".
        let s = Money.formatCompact(cents: 1_234_500, currencyCode: "USD", locale: en)
        #expect(s.contains("12"))
        #expect(s.localizedCaseInsensitiveContains("K"))
    }

    @Test func millions_foldToCompactM() {
        // 900_000_000 cents == $9,000,000 → compact millions.
        let s = Money.formatCompact(cents: 900_000_000, currencyCode: "USD", locale: en)
        #expect(s.localizedCaseInsensitiveContains("M"))
        // Compact output stays short — never a 7-digit run that would truncate.
        #expect(!s.contains("9,000,000"))
    }

    @Test func zero_isClean() {
        let s = Money.formatCompact(cents: 0, currencyCode: "USD", locale: en)
        #expect(s.contains("0"))
        #expect(!s.contains(".00"))
    }

    @Test func negative_isSupported() {
        // Over-budget remainder can be negative before the builder takes abs().
        let s = Money.formatCompact(cents: -5_000, currencyCode: "USD", locale: en)
        #expect(s.contains("50"))
    }

    // MARK: - Locale correctness (round-trip)

    @Test func groupingSeparators_areLocaleSpecific() {
        // en_US groups with "," ; ru_RU groups with a space — same value, different string.
        let enStr = Money.formatCompact(cents: 123_400, currencyCode: "USD", locale: en)
        let ruStr = Money.formatCompact(cents: 123_400, currencyCode: "RUB", locale: ru)
        #expect(!enStr.isEmpty)
        #expect(!ruStr.isEmpty)
        #expect(enStr != ruStr)
        #expect(!enStr.contains("1 234")) // en never uses a space group
    }

    @Test func ptBR_and_ru_bothRenderNonEmptyCompact() {
        for locale in [ru, ptBR] {
            let code = locale == ru ? "RUB" : "BRL"
            let s = Money.formatCompact(cents: 5_000_000, currencyCode: code, locale: locale)
            #expect(!s.isEmpty)
            #expect(s.contains("5"))
        }
    }
}
