//
//  TipSeenHistoryTests.swift
//  FinanceTrackerTests
//
//  The Learn hub shows only tips the user has already seen — a tip is seen iff its
//  rotation day-index is ≤ today's. These tests pin that the "seen" set is derived
//  correctly (count, order, and the day-1 edge) and that search can't leak an
//  unseen future tip through the hub's search field.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipSeenHistoryTests {

    private func tip(
        _ id: String,
        term: String = "term",
        explanation: String = "explanation",
        strategy: String = "strategy"
    ) -> DailyTip {
        DailyTip(id: id, term: term, explanation: explanation,
                 strategy: strategy, category: "sample")
    }

    private func library(_ ids: [String]) -> TipLibrary {
        let tips = ids.map { tip($0) }
        return TipLibrary(base: tips, localized: tips)
    }

    // MARK: - Count

    /// Before a full cycle has elapsed, only `todayDayIndex + 1` tips have been
    /// shown. This is the property that makes the hub grow one tip per day instead
    /// of dumping the whole library on day 1.
    @Test func onlyTipsUpToTodayAreSeenBeforeAFullCycle() {
        let lib = library((0..<10).map(String.init))   // 10-tip library
        #expect(lib.seenTips(todayDayIndex: 0).count == 1)   // day 1
        #expect(lib.seenTips(todayDayIndex: 3).count == 4)   // day 4
        #expect(lib.seenTips(todayDayIndex: 8).count == 9)
    }

    /// Once the rotation has cycled, every tip is seen — but each appears once, not
    /// once per lap.
    @Test func afterAFullCycleEveryTipIsSeenExactlyOnce() {
        let lib = library(["a", "b", "c"])
        let seen = lib.seenTips(todayDayIndex: 100)   // long after cycling
        #expect(seen.count == 3)
        #expect(Set(seen.map(\.id)).count == 3)
    }

    // MARK: - Order

    /// Most-recent first: today's tip leads, then yesterday's, and so on. The hub
    /// renders this as a reverse-chronological history.
    @Test func seenTipsAreMostRecentFirst() {
        let lib = library(["a", "b", "c", "d", "e"])
        // dayIndex 4 → tip e; 3 → d; 2 → c. Most-recent-first.
        let ids = lib.seenTips(todayDayIndex: 4).map(\.id)
        #expect(ids == ["e", "d", "c", "b", "a"])

        // Partial history keeps the same ordering, just truncated at the start.
        #expect(lib.seenTips(todayDayIndex: 2).map(\.id) == ["c", "b", "a"])
    }

    // MARK: - Edges

    @Test func emptyLibraryHasNoSeenTips() {
        #expect(library([]).seenTips(todayDayIndex: 50).isEmpty)
    }

    /// A device clock set before the 2026-01-01 epoch yields a negative day-index.
    /// That must degrade to "nothing seen" (the day-1 state), never index nonsense.
    @Test func aClockBeforeTheEpochSeesNothing() {
        #expect(library(["a", "b"]).seenTips(todayDayIndex: -1).isEmpty)
    }

    // MARK: - Search cannot leak the future

    /// The core guarantee. A term that exists only in an unseen tip must not be
    /// findable through a search scoped to the seen set — otherwise the search
    /// field becomes a spoiler for tomorrow's tip.
    @Test func searchScopedToSeenCannotFindAnUnseenTip() {
        let seenTip = tip("a", term: "Sinking fund")
        let futureTip = tip("b", term: "Zero-based budget")
        let real = TipLibrary(base: [seenTip, futureTip],
                              localized: [seenTip, futureTip])

        // Day 1: only "a" (Sinking fund) is seen; "b" is tomorrow's tip.
        let seen = real.seenTips(todayDayIndex: 0)
        #expect(real.matching("Sinking", in: seen).map(\.id) == ["a"])
        #expect(real.matching("Zero-based", in: seen).isEmpty)   // not leaked
    }

    /// An empty query returns the whole seen set unchanged, so browsing (no query)
    /// and searching share one scope.
    @Test func emptyQueryReturnsAllSeen() {
        let lib = library(["a", "b", "c"])
        let seen = lib.seenTips(todayDayIndex: 100)
        #expect(lib.matching("", in: seen).count == 3)
        #expect(lib.matching("   ", in: seen).count == 3)
    }
}
