//
//  DashboardTeachingSlotTests.swift
//  FinanceTrackerTests
//
//  The Dashboard's single teaching-card slot (v1.0.2 review, item 2). The tip
//  reveal has leaked past its surface three times, each from a new angle: the
//  global epoch showed a fresh install the whole back-catalogue, the orphaned
//  reveal log inflated the count, and then the card sat behind a borrowed
//  DATA-maturity gate while reveals silently accumulated for two weeks. These
//  tests pin the fourth angle shut: the tip card shows from day 1, and the
//  dashboard and the hub agree on which tip today's is.
//

import Foundation
import Testing
@testable import FinanceTracker

@MainActor
struct DashboardTeachingSlotTests {

    // MARK: - The precedence, exhaustively

    /// THE regression this file exists for: a brand-new user (insights locked —
    /// under 10 transactions, under 14 days) with their day-1 tip revealed sees
    /// the tip card, not the Day-0 nudge. Tips are static content; they never
    /// wait on data maturity.
    @Test func day1UserWithATip_seesTheTipCard_notDay0() {
        let slot = DashboardTeachingSlot.decide(
            hasTransactions: true,
            tipAvailable: true,
            tipDismissedToday: false,
            insightsUnlocked: false
        )
        #expect(slot == .tip, "the tip card must not sit behind the analytics maturity gate")
    }

    /// An empty dashboard has exactly one job — the first transaction. Nothing
    /// competes with it, tip or no tip.
    @Test func noTransactions_alwaysTheEmptyState() {
        for tipAvailable in [true, false] {
            let slot = DashboardTeachingSlot.decide(
                hasTransactions: false,
                tipAvailable: tipAvailable,
                tipDismissedToday: false,
                insightsUnlocked: false
            )
            #expect(slot == .emptyState)
        }
    }

    /// Dismissing today's tip in the early window hands the slot to the Day-0
    /// nudge — the "keep tracking" CTA keeps its job for exactly the user it
    /// was written for.
    @Test func earlyUserWhoDismissedTodaysTip_getsTheDay0Nudge() {
        let slot = DashboardTeachingSlot.decide(
            hasTransactions: true,
            tipAvailable: true,
            tipDismissedToday: true,
            insightsUnlocked: false
        )
        #expect(slot == .day0)
    }

    /// An established user who dismissed today's tip gets a calm dashboard —
    /// the Day-0 nudge must never resurface once insights are unlocked.
    @Test func establishedUserWhoDismissed_getsNothing() {
        let slot = DashboardTeachingSlot.decide(
            hasTransactions: true,
            tipAvailable: true,
            tipDismissedToday: true,
            insightsUnlocked: true
        )
        #expect(slot == .none)
    }

    /// No tip content shipped (empty library): the early window still nudges,
    /// an established user still gets calm.
    @Test func noTipAvailable_fallsBackByMaturity() {
        #expect(DashboardTeachingSlot.decide(
            hasTransactions: true, tipAvailable: false,
            tipDismissedToday: false, insightsUnlocked: false
        ) == .day0)
        #expect(DashboardTeachingSlot.decide(
            hasTransactions: true, tipAvailable: false,
            tipDismissedToday: false, insightsUnlocked: true
        ) == .none)
    }

    // MARK: - Day 1, end to end: one tip, and both surfaces name the same one

    private final class InMemoryBacking: TipCollectionBacking {
        var deckSeed: UInt64?
        var revealedIDs: [String] = []
        var lastRevealDay: Int = TipDeck.neverRevealed
    }

    /// A fresh install on the real current date: `start()` reveals exactly one
    /// tip, and `todaysTip` — the ONE property both the dashboard card and the
    /// Learn & Tips hub read — is that tip. There is no second derivation to
    /// disagree with.
    @Test func freshInstallToday_revealsExactlyOneTip_andItIsTodaysTip() {
        let tips = (0..<102).map {
            DailyTip(id: "tip-\($0)", term: "t\($0)", explanation: "e", strategy: "s", category: "c")
        }
        let library = TipLibrary(base: tips, localized: tips)

        let backing = InMemoryBacking()
        let store = TipCollection(backing: backing, library: { library })
        store.start(now: .now)

        #expect(store.revealedIDs.count == 1, "day 1 unlocks exactly one tip")
        #expect(store.todaysTip?.id == store.revealedIDs.last,
                "today's hero is the day-1 reveal — on the dashboard and in the hub alike")
    }
}
