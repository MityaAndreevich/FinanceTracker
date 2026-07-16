//
//  TipDeck.swift
//  FinanceTracker
//
//  The per-user "collection under lock". Pure math — no I/O, no Bundle, no clock —
//  so the whole reveal contract is unit-testable.
//
//  Why per-user, not a global calendar index: the old rotation derived "seen" from
//  a fixed epoch, so today's day-index (~195 and climbing) meant a brand-new user
//  saw the entire back-catalogue the instant they installed. The surprise the
//  feature exists to protect was gone for exactly the users we care about. Here the
//  reveal is driven by the user's OWN usage against a per-device shuffled deck and
//  an explicitly-persisted set of revealed ids.
//
//  Two ideas carry the whole design:
//
//  1. A per-device seed shuffles the library into a *deck* — a stable, private
//     order. Stable across launches (same seed → same order), unknown to the user
//     (real surprise), and independent of the install date.
//  2. The revealed ids are persisted as an ORDERED log, not recomputed. Reveals go
//     one-per-calendar-day in deck order, so the log is the source of truth for the
//     collection and for "today's hero" (its last entry).
//
//  Because the log is explicit and never rewritten, GROWING THE LIBRARY LATER IS
//  SAFE: new tips are just ids the deck hasn't reached yet. `evaluate` skips any id
//  already in the log, so a bigger library can only change which *unseen* tip comes
//  next — it can never re-show a revealed tip or drop one from the collection. This
//  removes the old "mid-cycle growth remaps the sequence" limitation; we can extend
//  the library post-launch without disturbing anyone's collection.
//

import Foundation

enum TipDeck {

    /// `lastRevealDay` sentinel meaning "never revealed anything yet". No real
    /// calendar-day integer collides with it, so the first launch always counts as
    /// a new day and reveals exactly one tip.
    static let neverRevealed = Int.min

    /// The result of evaluating a launch: the (possibly grown-by-one) reveal log
    /// and the day it was last advanced.
    struct Reveal: Equatable {
        let revealed: [String]
        let lastRevealDay: Int
    }

    /// The user's private deck: `ids` deterministically shuffled by `seed`.
    ///
    /// A hand-rolled seeded Fisher–Yates (below), not `Array.shuffled(using:)`, so
    /// the order is fully specified here rather than riding on stdlib shuffle
    /// internals that a toolchain update could quietly change.
    static func ordered(ids: [String], seed: UInt64) -> [String] {
        guard ids.count > 1 else { return ids }
        var rng = SplitMix64(seed: seed)
        var deck = ids
        for i in stride(from: deck.count - 1, through: 1, by: -1) {
            let j = Int(rng.next(upperBound: UInt64(i + 1)))
            deck.swapAt(i, j)
        }
        return deck
    }

    /// Evaluate a launch. Reveals AT MOST ONE new tip, and only when the calendar
    /// day has advanced past the last reveal *and* the deck still has an unseen
    /// entry. Never removes anything — the log only grows.
    ///
    /// The one-per-day gate is `today != lastRevealDay`, so:
    ///   - reopening the app the same day reveals nothing more;
    ///   - returning after several idle days reveals ONE, not a backlog;
    ///   - a rewound clock still can't dump multiple (different day ⇒ one reveal),
    ///     and can never shrink the log.
    static func evaluate(
        ids: [String],
        seed: UInt64,
        revealed: [String],
        lastRevealDay: Int,
        today: Int
    ) -> Reveal {
        // A log whose EVERY id has left the library (the placeholder catalogue was
        // replaced wholesale in v1.0.2) unlocks nothing the user can see. Treat
        // that user as fresh: the same-day gate must not hold their first real tip
        // hostage behind a reveal of a tip that no longer exists.
        let known = Set(ids)
        let hasResolvableReveal = revealed.contains(where: known.contains)
        guard today != lastRevealDay || !hasResolvableReveal else {
            return Reveal(revealed: revealed, lastRevealDay: lastRevealDay)
        }
        let seen = Set(revealed)
        // The next unseen tip in deck order. Skipping ids already in the log is what
        // makes library growth safe: a reshuffled deck can only reorder the unseen
        // tail, never resurface a revealed id.
        guard let next = ordered(ids: ids, seed: seed).first(where: { !seen.contains($0) }) else {
            // Deck exhausted (or empty library): nothing new to unlock. Leave the
            // marker untouched — there is nothing to gate.
            return Reveal(revealed: revealed, lastRevealDay: lastRevealDay)
        }
        return Reveal(revealed: revealed + [next], lastRevealDay: today)
    }

    /// Today's hero tip id, or nil when the library is empty.
    ///
    /// Before the deck is complete this is simply the most-recently revealed id —
    /// today's unlock. Once every tip is revealed there is nothing new to unlock, so
    /// the hero rotates daily through the full deck (by calendar day) so there is
    /// still a fresh-feeling tip each day.
    static func hero(ids: [String], seed: UInt64, revealed: [String], today: Int) -> String? {
        guard !ids.isEmpty else { return nil }
        // Only ids the library still contains count. An orphaned id (revealed from
        // a catalogue since replaced) resolves to no tip — surfacing it would blank
        // the hero, and counting it would flip the "complete" branch early and leak
        // unrevealed tips through the daily rotation.
        let known = Set(ids)
        let resolvable = revealed.filter(known.contains)
        if resolvable.count < ids.count {
            return resolvable.last
        }
        let deck = ordered(ids: ids, seed: seed)
        // Reuse the rotation's wrap-safe modulo (handles a clock before the epoch,
        // i.e. a negative `today`) rather than re-deriving it here.
        return TipRotation.tipIndex(dayIndex: today, canonicalCount: deck.count).map { deck[$0] }
    }
}

/// A tiny deterministic PRNG (SplitMix64). Seeded, pure UInt64 arithmetic with
/// wrapping operators, so it produces the same stream on every platform and run —
/// which is what makes a user's deck reproducible across launches.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
