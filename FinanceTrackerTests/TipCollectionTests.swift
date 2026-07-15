//
//  TipCollectionTests.swift
//  FinanceTrackerTests
//
//  The stateful store around TipDeck: it owns the per-device seed and the persisted
//  reveal log, and drives one reveal per launch. TipDeck already pins the reveal
//  math; these pin the wiring — that the seed is generated once and kept, that a
//  launch persists exactly what TipDeck decided, and that the collection reads back
//  most-recent-first — using an in-memory backing and a stub library so no test
//  touches UserDefaults or the app bundle.
//

import Foundation
import Testing
@testable import FinanceTracker

@MainActor
struct TipCollectionTests {

    // MARK: - Test doubles

    private final class InMemoryBacking: TipCollectionBacking {
        var deckSeed: UInt64?
        var revealedIDs: [String] = []
        var lastRevealDay: Int = TipDeck.neverRevealed
    }

    private func tip(_ id: String) -> DailyTip {
        DailyTip(id: id, term: id, explanation: "e", strategy: "s", category: "c")
    }

    private func lib(_ ids: [String]) -> TipLibrary {
        let t = ids.map(tip)
        return TipLibrary(base: t, localized: t)
    }

    /// Two instants a whole calendar day apart, well after the reference epoch.
    private let dayA = Date(timeIntervalSince1970: 1_780_000_000)
    private var dayB: Date { dayA.addingTimeInterval(24 * 60 * 60) }
    private var dayC: Date { dayA.addingTimeInterval(2 * 24 * 60 * 60) }

    // MARK: - Seed

    @Test func seedIsGeneratedOnceAndPersisted() {
        let backing = InMemoryBacking()
        let store = TipCollection(backing: backing, library: { self.lib(["a", "b", "c"]) })
        store.start(now: dayA)

        let seed = backing.deckSeed
        #expect(seed != nil)

        // A second store sharing the same backing reuses the seed — the deck must
        // not reshuffle under the user on a later launch.
        let store2 = TipCollection(backing: backing, library: { self.lib(["a", "b", "c"]) })
        store2.start(now: dayB)
        #expect(backing.deckSeed == seed)
    }

    // MARK: - Reveal wiring

    @Test func firstLaunchRevealsExactlyOneTipAndPersistsIt() {
        let backing = InMemoryBacking()
        let store = TipCollection(backing: backing, library: { self.lib(["a", "b", "c"]) })
        store.start(now: dayA)

        #expect(store.revealedIDs.count == 1)
        #expect(backing.revealedIDs == store.revealedIDs)   // persisted
        #expect(backing.lastRevealDay != TipDeck.neverRevealed)
    }

    @Test func eachNewCalendarDayRevealsOneMore() {
        let backing = InMemoryBacking()
        let store = TipCollection(backing: backing, library: { self.lib((0..<10).map(String.init)) })
        store.start(now: dayA)
        #expect(store.revealedIDs.count == 1)

        store.refresh(now: dayB)
        #expect(store.revealedIDs.count == 2)

        // Reopening the same day does not add another.
        store.refresh(now: dayB)
        #expect(store.revealedIDs.count == 2)

        store.refresh(now: dayC)
        #expect(store.revealedIDs.count == 3)
    }

    // MARK: - Collection read-back

    @Test func collectionIsMostRecentFirstAndTodaysTipIsTheHero() {
        let backing = InMemoryBacking()
        let store = TipCollection(backing: backing, library: { self.lib((0..<10).map(String.init)) })
        store.start(now: dayA)
        store.refresh(now: dayB)
        store.refresh(now: dayC)

        // Most-recent first: reversed reveal log.
        #expect(store.collection.map(\.id) == store.revealedIDs.reversed())
        // The hero is the most-recently revealed tip (before completion).
        #expect(store.todaysTip?.id == store.revealedIDs.last)
    }

    // MARK: - Library growth

    @Test func growingTheLibraryDoesNotDisturbTheExistingCollection() {
        let backing = InMemoryBacking()
        var ids = Array((0..<5).map(String.init))
        let store = TipCollection(backing: backing, library: { self.lib(ids) })

        store.start(now: dayA)
        store.refresh(now: dayB)
        let before = store.revealedIDs
        #expect(before.count == 2)

        // Ship more tips, then launch on a new day.
        ids += ["new-1", "new-2", "new-3"]
        store.refresh(now: dayC)

        // The previously revealed tips are untouched and still lead the log.
        #expect(Array(store.revealedIDs.prefix(before.count)) == before)
        #expect(store.revealedIDs.count == before.count + 1)      // exactly one new
        #expect(Set(store.revealedIDs).count == store.revealedIDs.count)   // no dup
    }
}
