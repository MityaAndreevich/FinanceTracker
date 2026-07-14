//
//  TipCollection.swift
//  FinanceTracker
//
//  The stateful owner of the per-user tip collection: the per-device deck seed and
//  the persisted reveal log. All the interesting decisions live in `TipDeck` (pure,
//  tested); this layer only plumbs persistence and the clock, then drives one reveal
//  per launch. Mirrors AccessManager: pure logic + an @MainActor ObservableObject
//  singleton, `start()` at launch, injectable persistence for tests.
//

import Foundation

/// The persisted state behind the collection. A protocol so tests can drive the
/// store with an in-memory double instead of UserDefaults.
protocol TipCollectionBacking: AnyObject {
    /// The per-device shuffle seed. Generated once, on first launch, then fixed —
    /// so the user's deck order is stable for the life of the install.
    var deckSeed: UInt64? { get set }
    /// The revealed tip ids, in reveal order (oldest first). The source of truth for
    /// the collection; only ever appended to.
    var revealedIDs: [String] { get set }
    /// The calendar-day integer of the last reveal, or `TipDeck.neverRevealed`.
    var lastRevealDay: Int { get set }
}

/// Production backing: standard `UserDefaults`. This is deliberately *not* the App
/// Group / widget store — the collection is a main-app concept the widget never
/// reads, and a reinstall resetting it is the correct behaviour (a fresh install is
/// a fresh collection).
final class UserDefaultsTipCollectionBacking: TipCollectionBacking {

    private enum Key {
        static let seed = "tipDeckSeed"
        static let revealed = "tipRevealedIDs"
        static let lastRevealDay = "tipLastRevealDay"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    // UInt64 has no native UserDefaults representation, so it round-trips as its
    // decimal string. (An Int bit-cast would also work but reads as noise.)
    var deckSeed: UInt64? {
        get { defaults.string(forKey: Key.seed).flatMap(UInt64.init) }
        set { defaults.set(newValue.map(String.init), forKey: Key.seed) }
    }

    var revealedIDs: [String] {
        get { defaults.stringArray(forKey: Key.revealed) ?? [] }
        set { defaults.set(newValue, forKey: Key.revealed) }
    }

    var lastRevealDay: Int {
        // `object(forKey:) as? Int` (not `integer(forKey:)`) so a missing key reads
        // as "never revealed", not 0 — day 0 is a real calendar day.
        get { defaults.object(forKey: Key.lastRevealDay) as? Int ?? TipDeck.neverRevealed }
        set { defaults.set(newValue, forKey: Key.lastRevealDay) }
    }
}

@MainActor
final class TipCollection: ObservableObject {

    static let shared = TipCollection()

    /// The revealed tip ids, oldest first. Published so the Dashboard card and the
    /// hub re-render the instant a launch reveals a new tip.
    @Published private(set) var revealedIDs: [String] = []

    private let backing: TipCollectionBacking
    private let library: @MainActor () -> TipLibrary

    init(backing: TipCollectionBacking = UserDefaultsTipCollectionBacking(),
         library: (@MainActor () -> TipLibrary)? = nil) {
        self.backing = backing
        // Resolved here rather than as a default argument: `TipLibraryCache.current`
        // is @MainActor, and default-argument expressions are evaluated nonisolated.
        self.library = library ?? { TipLibraryCache.current }
        self.revealedIDs = backing.revealedIDs
    }

    /// Call once at app launch (and again on foreground) to run the day's reveal.
    func start(now: Date = .now) {
        _ = seed            // materialise the seed on first ever launch
        refresh(now: now)
    }

    /// Reveal at most one new tip if the calendar day advanced. Idempotent within a
    /// day, so calling it on every foreground is safe.
    func refresh(now: Date = .now) {
        let today = TipRotation.dayIndex(for: now, in: .current)
        let decision = TipDeck.evaluate(
            ids: library().canonicalIDs,
            seed: seed,
            revealed: backing.revealedIDs,
            lastRevealDay: backing.lastRevealDay,
            today: today
        )
        backing.revealedIDs = decision.revealed
        backing.lastRevealDay = decision.lastRevealDay
        revealedIDs = decision.revealed
    }

    /// Today's hero tip, localized — the most-recently unlocked tip, or a daily
    /// rotation through the deck once everything is unlocked. Nil when the library
    /// is empty (no content shipped yet).
    var todaysTip: DailyTip? {
        let lib = library()
        let today = TipRotation.dayIndex(for: .now, in: .current)
        return TipDeck.hero(ids: lib.canonicalIDs, seed: seed, revealed: revealedIDs, today: today)
            .flatMap(lib.tip(forID:))
    }

    /// The unlocked collection, most-recent first (today's hero leads).
    var collection: [DailyTip] {
        library().tips(forIDs: revealedIDs.reversed())
    }

    /// How many tips are unlocked, and the total in the library — drives the hub's
    /// "X of Y unlocked" progress line without revealing any locked content.
    var unlockedCount: Int { revealedIDs.count }
    var totalCount: Int { library().canonicalCount }
    var isComplete: Bool { totalCount > 0 && unlockedCount >= totalCount }

    // MARK: - Seed

    /// The per-device seed, generated and persisted on first access.
    private var seed: UInt64 {
        if let existing = backing.deckSeed { return existing }
        let fresh = UInt64.random(in: .min ... .max)
        backing.deckSeed = fresh
        return fresh
    }

    // MARK: - DEBUG seam

    #if DEBUG
    /// Forgets the collection entirely, so the next `start` behaves like a fresh
    /// install — the honest way to device-verify "new user sees exactly one tip"
    /// without reinstalling. Driven by `--reset-tip-collection` at launch.
    func resetForDebugIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--reset-tip-collection") else { return }
        backing.deckSeed = nil
        backing.revealedIDs = []
        backing.lastRevealDay = TipDeck.neverRevealed
        revealedIDs = []
    }
    #endif
}
