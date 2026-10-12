//
//  GuideUsageSignals.swift
//  FinanceTracker
//
//  1.0.7, the User Guide's alongside-measurement (DESIGN_USER_GUIDE.md §6;
//  brief Phase 3 "MEASUREMENT"): did the first-run walkthrough finish or get
//  skipped, and where; was it ever replayed; which Guide cards were opened.
//
//  Same contract as `FeatureUsageSignals`: on this device only, read by nothing
//  except the feedback composer the user opens and can switch off. Nothing is
//  transmitted.
//
//  LETTERS ONLY. Every value this file stores is a word (a step id, a card
//  slug), never a number. `UsageSummaryTests` rejects any digit in the rendered
//  summary that is not a bucket boundary, because that tripwire is how a count
//  or an amount leaking into the summary gets caught. A card id like "B1" would
//  have forced that tripwire open.
//

import Foundation

enum GuideUsageSignals {

    /// How the FIRST walkthrough ended. Replays never overwrite it: the
    /// question it answers is "did a new user finish the tour", and a later
    /// replay is a different person-moment.
    enum WalkthroughOutcome: Equatable {
        case completed
        /// The step the user was on when they tapped Skip: `greeting`, a
        /// `CoachmarkID` raw value, or `firstWin`.
        case skipped(at: String)

        fileprivate var stored: String {
            switch self {
            case .completed: return "completed"
            case .skipped(let step): return "skipped:" + step
            }
        }

        fileprivate init?(stored: String) {
            if stored == "completed" { self = .completed; return }
            guard stored.hasPrefix("skipped:") else { return nil }
            self = .skipped(at: String(stored.dropFirst("skipped:".count)))
        }
    }

    // camelCase on purpose. An all-lowercase dotted literal assigned to a `…Key`
    // is the shape `LocaleCompletenessTests` reads as a LOCALIZATION key; the
    // first draft used that shape and turned the whole-tree scan red
    // (2026-10-11). Storage keys keep a capital, as `debug.largeDatasetSeed.applied` does.
    static let outcomeKey = "guideUsage.walkthroughOutcome"
    static let replayedKey = "guideUsage.walkthroughReplayed"
    static let cardsOpenedKey = "guideUsage.cardsOpened"

    /// First write wins (see `WalkthroughOutcome`).
    static func recordFirstOutcome(_ outcome: WalkthroughOutcome, defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: outcomeKey) == nil else { return }
        defaults.set(outcome.stored, forKey: outcomeKey)
    }

    /// nil = not recorded: a user who finished the tour before 1.0.7, or who
    /// has not reached its end yet. Never reported as "skipped".
    static func firstOutcome(defaults: UserDefaults = .standard) -> WalkthroughOutcome? {
        defaults.string(forKey: outcomeKey).flatMap(WalkthroughOutcome.init(stored:))
    }

    static func markReplayed(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: replayedKey)
    }

    static func wasReplayed(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: replayedKey)
    }

    /// `slug` is a `GuideCard` id, letters only.
    static func markCardOpened(_ slug: String, defaults: UserDefaults = .standard) {
        var opened = Set(defaults.stringArray(forKey: cardsOpenedKey) ?? [])
        guard opened.insert(slug).inserted else { return }
        defaults.set(opened.sorted(), forKey: cardsOpenedKey)
    }

    /// Sorted, so the rendered line is stable for the same set.
    static func cardsOpened(defaults: UserDefaults = .standard) -> [String] {
        (defaults.stringArray(forKey: cardsOpenedKey) ?? []).sorted()
    }

    /// Test/debug seam only.
    static func resetAll(defaults: UserDefaults = .standard) {
        for key in [outcomeKey, replayedKey, cardsOpenedKey] { defaults.removeObject(forKey: key) }
    }
}
