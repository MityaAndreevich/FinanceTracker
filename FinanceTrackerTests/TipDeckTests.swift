//
//  TipDeckTests.swift
//  FinanceTrackerTests
//
//  The per-user tip "collection under lock". These pin the properties that make
//  the reveal a real surprise for a NEW user — the thing the old global-epoch
//  rotation destroyed (a fresh install on day ~195 saw the whole back-catalogue).
//
//  The engine is pure math over explicit inputs (ids, seed, revealed set, a
//  calendar-day integer), so every property below is verifiable without a clock,
//  UserDefaults, or a UI.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipDeckTests {

    private let ids = (0..<20).map { "tip-\($0)" }

    // MARK: - Deck ordering

    /// The user's deck order must be stable across launches (same seed → same
    /// order), or "yesterday's tip" would move under them.
    @Test func deckOrderIsStableForAFixedSeed() {
        #expect(TipDeck.ordered(ids: ids, seed: 42) == TipDeck.ordered(ids: ids, seed: 42))
    }

    /// Different users (different seeds) get different orders — that per-user
    /// unpredictability is the surprise.
    @Test func differentSeedsProduceDifferentOrders() {
        #expect(TipDeck.ordered(ids: ids, seed: 1) != TipDeck.ordered(ids: ids, seed: 2))
    }

    /// The deck is a permutation: every tip appears exactly once, none invented.
    @Test func deckIsAPermutationOfTheLibrary() {
        let deck = TipDeck.ordered(ids: ids, seed: 777)
        #expect(deck.count == ids.count)
        #expect(Set(deck) == Set(ids))
    }

    @Test func emptyAndSingleDecksAreHandled() {
        #expect(TipDeck.ordered(ids: [], seed: 5).isEmpty)
        #expect(TipDeck.ordered(ids: ["only"], seed: 5) == ["only"])
    }

    // MARK: - First launch (the regression that proves the epoch bug is gone)

    /// A brand-new user, on ANY real calendar date, sees exactly ONE tip on first
    /// launch — never the back-catalogue. `today` is deliberately large (a late
    /// install date) to catch the old "seen == everything up to today" behaviour.
    @Test func firstLaunchRevealsExactlyOneTipOnAnyDate() {
        for today in [0, 1, 195, 5_000] {
            let r = TipDeck.evaluate(ids: ids, seed: 9, revealed: [],
                                     lastRevealDay: TipDeck.neverRevealed, today: today)
            #expect(r.revealed.count == 1, "day \(today) should reveal exactly one")
            #expect(r.lastRevealDay == today)
        }
    }

    // MARK: - Cadence: at most one reveal per calendar day, no backlog

    @Test func revealsOneNewTipPerCalendarDay() {
        var revealed: [String] = []
        var lastDay = TipDeck.neverRevealed
        for (offset, day) in [100, 101, 102].enumerated() {
            let r = TipDeck.evaluate(ids: ids, seed: 3, revealed: revealed,
                                     lastRevealDay: lastDay, today: day)
            revealed = r.revealed
            lastDay = r.lastRevealDay
            #expect(revealed.count == offset + 1)   // day 1 → 1, day 2 → 2, day 3 → 3
        }
    }

    /// Opening the app again the same day reveals nothing more.
    @Test func sameDayReopenRevealsNothing() {
        let first = TipDeck.evaluate(ids: ids, seed: 3, revealed: [],
                                     lastRevealDay: TipDeck.neverRevealed, today: 100)
        let again = TipDeck.evaluate(ids: ids, seed: 3, revealed: first.revealed,
                                     lastRevealDay: first.lastRevealDay, today: 100)
        #expect(again.revealed == first.revealed)   // unchanged
    }

    /// Skipping days does not dump a backlog: returning after 5 idle days reveals
    /// ONE, not five. This is what preserves the one-a-day ritual.
    @Test func skippingDaysRevealsOnlyOneOnReturn() {
        let day1 = TipDeck.evaluate(ids: ids, seed: 3, revealed: [],
                                    lastRevealDay: TipDeck.neverRevealed, today: 100)
        #expect(day1.revealed.count == 1)
        let day6 = TipDeck.evaluate(ids: ids, seed: 3, revealed: day1.revealed,
                                    lastRevealDay: day1.lastRevealDay, today: 105)   // +5 days
        #expect(day6.revealed.count == 2)   // +1, never +5
        #expect(day6.lastRevealDay == 105)
    }

    /// A rewound clock (today < lastRevealDay) never removes a revealed tip and,
    /// because the day differs, reveals at most one — the set only ever grows.
    @Test func seenSetOnlyGrowsEvenWhenClockMovesBackward() {
        let ahead = TipDeck.evaluate(ids: ids, seed: 3, revealed: [],
                                     lastRevealDay: TipDeck.neverRevealed, today: 200)
        let back = TipDeck.evaluate(ids: ids, seed: 3, revealed: ahead.revealed,
                                    lastRevealDay: ahead.lastRevealDay, today: 100)
        #expect(Set(ahead.revealed).isSubset(of: Set(back.revealed)))
        #expect(back.revealed.count == ahead.revealed.count + 1)   // still at most one
    }

    // MARK: - No repeats; reveals follow deck order

    /// Revealing day-by-day walks the deck in order and never repeats an id.
    @Test func revealsWalkTheDeckWithoutRepeating() {
        let deck = TipDeck.ordered(ids: ids, seed: 55)
        var revealed: [String] = []
        var lastDay = TipDeck.neverRevealed
        for day in 0..<ids.count {
            let r = TipDeck.evaluate(ids: ids, seed: 55, revealed: revealed,
                                     lastRevealDay: lastDay, today: day)
            revealed = r.revealed
            lastDay = r.lastRevealDay
        }
        #expect(revealed == deck)                       // in deck order
        #expect(Set(revealed).count == revealed.count)  // no repeats
    }

    /// Once the whole deck is revealed, no further calendar day unlocks anything.
    @Test func exhaustedDeckRevealsNothingNew() {
        let deck = TipDeck.ordered(ids: ids, seed: 55)
        let r = TipDeck.evaluate(ids: ids, seed: 55, revealed: deck,
                                 lastRevealDay: 900, today: 901)
        #expect(r.revealed == deck)   // complete: unchanged
    }

    // MARK: - Hero

    @Test func heroIsTheMostRecentlyRevealedBeforeCompletion() {
        let deck = TipDeck.ordered(ids: ids, seed: 8)
        let revealed = Array(deck.prefix(3))
        #expect(TipDeck.hero(ids: ids, seed: 8, revealed: revealed, today: 42) == revealed.last)
    }

    /// After the deck is complete there is nothing new to unlock, so the hero
    /// rotates daily through the full deck — always a real tip, changing by day.
    @Test func heroRotatesThroughDeckAfterCompletion() {
        let deck = TipDeck.ordered(ids: ids, seed: 8)
        let a = TipDeck.hero(ids: ids, seed: 8, revealed: deck, today: 500)
        let b = TipDeck.hero(ids: ids, seed: 8, revealed: deck, today: 501)
        #expect(a != nil && b != nil)
        #expect(deck.contains(a!) && deck.contains(b!))
        #expect(a != b)   // a different tip each day
    }

    @Test func emptyLibraryHasNoHeroAndNeverReveals() {
        let r = TipDeck.evaluate(ids: [], seed: 8, revealed: [],
                                 lastRevealDay: TipDeck.neverRevealed, today: 10)
        #expect(r.revealed.isEmpty)
        #expect(TipDeck.hero(ids: [], seed: 8, revealed: [], today: 10) == nil)
    }

    /// A one-tip library must not divide by zero or crash: it reveals its single
    /// tip, and that tip is the hero forever after.
    @Test func singleTipLibraryDoesNotCrash() {
        let one = ["solo"]
        let r = TipDeck.evaluate(ids: one, seed: 8, revealed: [],
                                 lastRevealDay: TipDeck.neverRevealed, today: 10)
        #expect(r.revealed == ["solo"])
        #expect(TipDeck.hero(ids: one, seed: 8, revealed: ["solo"], today: 11) == "solo")
        #expect(TipDeck.hero(ids: one, seed: 8, revealed: ["solo"], today: 99) == "solo")
    }

    // MARK: - Library growth is safe

    /// Growing the library later cannot corrupt the collection: already-revealed
    /// ids stay revealed, in place, and no reveal ever re-shows a seen tip.
    @Test func growingTheLibraryKeepsRevealedIntactAndNeverReReveals() {
        let smallDeck = TipDeck.ordered(ids: ids, seed: 12)
        let revealed = Array(smallDeck.prefix(4))   // 4 tips already collected

        // Ship more tips: same ids plus new ones.
        let grown = ids + (0..<10).map { "new-\($0)" }

        let r = TipDeck.evaluate(ids: grown, seed: 12, revealed: revealed,
                                 lastRevealDay: 300, today: 301)

        // Every previously-revealed id survives, unchanged and in order.
        #expect(Array(r.revealed.prefix(revealed.count)) == revealed)
        // Exactly one new reveal, and it is an id not seen before.
        #expect(r.revealed.count == revealed.count + 1)
        #expect(!revealed.contains(r.revealed.last!))
        // No duplicates anywhere.
        #expect(Set(r.revealed).count == r.revealed.count)
    }

    // MARK: - Library REPLACEMENT is safe (orphaned reveal log)

    /// v1.0.2 replaced the placeholder catalogue wholesale, so a live install's
    /// entire log can point at ids the library no longer ships. That user sees an
    /// empty collection, so they are effectively fresh: the same-day gate must not
    /// hold today's first real tip hostage behind a reveal of a tip that no longer
    /// exists. The log itself is never rewritten — orphans stay, the reveal appends.
    @Test func fullyOrphanedLogStillRevealsOneTodayEvenOnTheSameDay() {
        let orphans = (1...5).map { "placeholder-00\($0)" }
        let r = TipDeck.evaluate(ids: ids, seed: 3, revealed: orphans,
                                 lastRevealDay: 100, today: 100)
        #expect(Array(r.revealed.prefix(orphans.count)) == orphans)
        #expect(r.revealed.count == orphans.count + 1)
        #expect(ids.contains(r.revealed.last!))
        #expect(r.lastRevealDay == 100)

        // And the reveal makes the hero resolvable again.
        #expect(TipDeck.hero(ids: ids, seed: 3, revealed: r.revealed, today: 100)
                == r.revealed.last)
    }

    /// The hero is the newest RESOLVABLE reveal — an orphaned id at the end of the
    /// log must never blank the hero card.
    @Test func orphanedIdsNeverBecomeTheHero() {
        let revealed = ["placeholder-001", ids[0], "placeholder-002"]
        #expect(TipDeck.hero(ids: ids, seed: 3, revealed: revealed, today: 7) == ids[0])
    }

    /// Orphans must not count toward completion: a log longer than the library is
    /// not "everything unlocked" if some entries resolve to nothing — flipping into
    /// the daily rotation early would leak tips the user never revealed.
    @Test func orphanedIdsDoNotCountTowardCompletion() {
        let deck = TipDeck.ordered(ids: ids, seed: 3)
        let orphans = (1...5).map { "placeholder-00\($0)" }
        let revealed = orphans + deck.dropLast()   // 5 orphans + 19 valid ≥ 20 ids
        #expect(TipDeck.hero(ids: ids, seed: 3, revealed: revealed, today: 9)
                == deck[deck.count - 2])
    }
}
