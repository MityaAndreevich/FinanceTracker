//
//  TipLibraryTests.swift
//  FinanceTrackerTests
//
//  Translations lag: `en` is complete, other locales are partial. These tests pin
//  the two rules that keep a lagging locale from corrupting the rotation — the
//  canonical count comes from the base file, and fallback happens per field.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipLibraryTests {

    private func tip(
        _ id: String,
        term: String = "term",
        explanation: String = "explanation",
        strategy: String = "strategy"
    ) -> DailyTip {
        DailyTip(id: id, term: term, explanation: explanation,
                 strategy: strategy, category: "sample")
    }

    // MARK: - Canonical count

    @Test func canonicalCountComesFromBaseNotLocale() {
        // A locale with 1 of 3 tips translated must still cycle through 3, or it
        // would show a different tip than every other locale on the same day.
        let library = TipLibrary(
            base: [tip("a"), tip("b"), tip("c")],
            localized: [tip("a", term: "término")]
        )
        #expect(library.canonicalCount == 3)
    }

    @Test func aLocaleWithExtraTipsStillUsesTheBaseCount() {
        let library = TipLibrary(
            base: [tip("a")],
            localized: [tip("a"), tip("b"), tip("c")]
        )
        #expect(library.canonicalCount == 1)
        #expect(library.allTips.count == 1)
    }

    // MARK: - Per-field fallback

    @Test func translatedTipIsUsedWhenPresent() {
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund")],
            localized: [tip("a", term: "Fondo de reserva")]
        )
        #expect(library.tip(at: 0)?.term == "Fondo de reserva")
    }

    @Test func missingLocaleEntryFallsBackToBase() {
        let library = TipLibrary(
            base: [tip("a"), tip("b", term: "Base B")],
            localized: [tip("a")]           // index 1 not translated yet
        )
        #expect(library.tip(at: 1)?.term == "Base B")
    }

    @Test func blankFieldFallsBackPerFieldNotWholeTip() {
        // The point of per-field fallback: an untranslated `strategy` must not
        // discard a perfectly good translated `term`.
        let library = TipLibrary(
            base: [tip("a", term: "Base term", strategy: "Base strategy")],
            localized: [tip("a", term: "Translated term", strategy: "   ")]
        )
        let result = library.tip(at: 0)
        #expect(result?.term == "Translated term")
        #expect(result?.strategy == "Base strategy")
    }

    @Test func idMismatchDistrustsTheWholeLocaleEntry() {
        // Files drifted out of sync: the entry at this index is a translation of
        // some *other* tip, so none of its fields can be trusted here.
        let library = TipLibrary(
            base: [tip("a", term: "Base A")],
            localized: [tip("z", term: "Translation of Z")]
        )
        #expect(library.tip(at: 0)?.term == "Base A")
        #expect(library.tip(at: 0)?.id == "a")
    }

    // MARK: - Empty and out-of-range

    @Test func emptyBaseIsAnEmptyLibrary() {
        let library = TipLibrary(base: [], localized: [])
        #expect(library.isEmpty)
        #expect(library.canonicalCount == 0)
        #expect(library.tip(at: 0) == nil)
        #expect(library.allTips.isEmpty)
    }

    @Test func outOfRangeIndexIsNil() {
        let library = TipLibrary(base: [tip("a")], localized: [tip("a")])
        #expect(library.tip(at: 5) == nil)
        #expect(library.tip(at: -1) == nil)
    }

    // MARK: - Search

    @Test func searchMatchesTheTerm() {
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund"), tip("b", term: "Lifestyle creep")],
            localized: []
        )
        #expect(library.search("sinking").map(\.id) == ["a"])
    }

    @Test func searchIsCaseInsensitive() {
        let library = TipLibrary(base: [tip("a", term: "Presupuesto")], localized: [])
        #expect(library.search("PRESUPUESTO").count == 1)
        #expect(library.search("presupuesto").count == 1)
    }

    @Test func searchAlsoMatchesExplanationAndStrategy() {
        let library = TipLibrary(
            base: [tip("a", term: "Term", explanation: "about compounding", strategy: "move 20")],
            localized: []
        )
        #expect(library.search("compounding").count == 1)
        #expect(library.search("move 20").count == 1)
    }

    @Test func searchSearchesTheLocalizedTextNotTheBaseText() {
        // A Spanish user searching a Spanish word must find the tip, even though the
        // base text is English.
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund")],
            localized: [tip("a", term: "Fondo de reserva")]
        )
        #expect(library.search("fondo").count == 1)
        #expect(library.search("sinking").isEmpty)
    }

    @Test func emptyQueryReturnsEverything() {
        let library = TipLibrary(base: [tip("a"), tip("b")], localized: [])
        #expect(library.search("").count == 2)
        #expect(library.search("   ").count == 2)
    }

    @Test func aQueryMatchingNothingReturnsNothing() {
        let library = TipLibrary(base: [tip("a", term: "Sinking fund")], localized: [])
        #expect(library.search("zzzz").isEmpty)
    }

    // MARK: - Decoding

    @Test func malformedJSONDecodesToEmptyRatherThanThrowing() {
        let data = Data("{ this is not valid json".utf8)
        #expect(TipLibrary.decodeTips(from: data).isEmpty)
    }

    @Test func validJSONDecodes() {
        let json = """
        [{"id":"a","term":"T","explanation":"E","strategy":"S","category":"sample"}]
        """
        let tips = TipLibrary.decodeTips(from: Data(json.utf8))
        #expect(tips.count == 1)
        #expect(tips.first?.id == "a")
    }

    @Test func categoryIsOptional() {
        let json = """
        [{"id":"a","term":"T","explanation":"E","strategy":"S"}]
        """
        let tips = TipLibrary.decodeTips(from: Data(json.utf8))
        #expect(tips.first?.category == nil)
    }
}
