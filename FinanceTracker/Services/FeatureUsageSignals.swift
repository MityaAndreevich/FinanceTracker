//
//  FeatureUsageSignals.swift
//  FinanceTracker
//
//  "Has this person ever touched feature X?" — six booleans in UserDefaults,
//  written at the moment the feature is actually exercised.
//
//  WHY FLAGS AND NOT A QUERY: three of the six leave no trace in the ledger.
//  Dictating a transaction produces an ordinary Transaction; exporting a CSV
//  produces a file outside the app; importing one produces rows that look
//  hand-typed. There is nothing to count afterwards. The other three (splits,
//  recurrence, category limits) ARE derivable, but only as *current* state —
//  a user who split a purchase in March and deleted it in April reads as
//  "never used", which is the wrong answer to "ever touched". So the flag is
//  the primary signal and the ledger query is the backfill (see
//  `UsageSummaryBuilder`), which is what makes this correct for users who
//  already split something before this build existed.
//
//  This is NOT analytics. Nothing here is transmitted, aggregated across
//  users, or read by anything except the feedback composer the user opens
//  themselves. Six bits, on one device, that the user can look at and switch
//  off before they send anything. See `APP_PRIVACY_ANSWERS.md` §3.12.1.
//

import Foundation

enum FeatureUsageSignals {

    /// The features the 1.0.3 pre-test asks about. Raw values are the
    /// UserDefaults suffixes and must stay stable — renaming one silently
    /// resets every existing install to "never used".
    enum Feature: String, CaseIterable {
        case splits
        case recurring
        case categoryLimits = "category_limits"
        case voiceEntry = "voice_entry"
        case csvImport = "csv_import"
        case export
    }

    private static let prefix = "usage.ever."

    private static func key(_ feature: Feature) -> String {
        prefix + feature.rawValue
    }

    /// Idempotent, and deliberately cheap enough to call on every use rather
    /// than needing a "have I already recorded this?" dance at the call site.
    static func markUsed(_ feature: Feature) {
        let key = key(feature)
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    static func wasUsed(_ feature: Feature) -> Bool {
        UserDefaults.standard.bool(forKey: key(feature))
    }

    /// Test/debug seam only — the app never clears these in normal operation.
    /// (A ledger reset does not clear them either: "ever used" outlives the
    /// data, which is the whole point of the flag.)
    static func resetAll() {
        for feature in Feature.allCases {
            UserDefaults.standard.removeObject(forKey: key(feature))
        }
    }
}
