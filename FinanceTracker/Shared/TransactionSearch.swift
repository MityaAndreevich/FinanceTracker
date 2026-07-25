//
//  TransactionSearch.swift
//  FinanceTracker
//
//  Pure, testable search matching for the Transactions list. Extracted from
//  TransactionsView so the semantics can be unit-tested without SwiftData
//  (device QA round 2 #3).
//
//  Semantics (documented, per brief):
//    • Diacritic- and case-insensitive ("Cafe" matches "Café").
//    • Multi-token: the query is split on whitespace; EVERY token must be found
//      as a substring of at least one searchable field (AND across tokens, OR
//      across fields). So a whole-string substring is NOT required — the stale
//      device query "Футболка 550" now matches the "Футболка" row when that
//      purchase was 550, instead of matching nothing and reading as data loss.
//    • Amount IS searchable, by its major unit: "550" matches a 550.00
//      transaction (also the cents form "55000" and "550.00").
//    • An empty / whitespace-only query matches everything.
//

import Foundation
import SwiftData

enum TransactionSearch {

    // MARK: - Model adapter

    /// The text haystack for one purchase.
    ///
    /// Category names come from `CategoryAttribution.shares(for:)` — the SAME
    /// decomposition Analytics aggregates — and never from `tx.category` plus
    /// the raw split list. That is the whole point (2026-07-23 hands-on report):
    ///
    ///   A 3,500 "Кошачий корм" filed under Питомцы and split 1500/2000 into two
    ///   other categories contributes NOTHING to Питомцы. Analytics excludes it
    ///   from that category (`CategoryDetailView` requires attributed > 0);
    ///   search used to include it because the parent's own category field still
    ///   said Питомцы. Two surfaces, two totals for one category — the numbers
    ///   were each defensible and the pair was not.
    ///
    /// Reading shares makes the two agree BY CONSTRUCTION rather than by two
    /// rules that happen to coincide: a fully-split purchase stops matching its
    /// zero-remainder category, a partially-split one still matches through its
    /// remainder share, and an unsplit one is untouched (`shares` returns
    /// exactly one share = the old (amount, category) pair).
    ///
    /// Split NOTES stay searchable regardless of attribution: "HDMI cable" is a
    /// label the user typed on this purchase, not a claim about where money went.
    static func searchableFields(for tx: Transaction) -> [String?] {
        var fields: [String?] = [tx.merchant, tx.source?.name, tx.note]

        for share in CategoryAttribution.shares(for: tx) {
            fields.append(share.category.displayNameOrFallback())
            fields.append(share.category?.name)
        }
        for split in CategoryAttribution.orderedSplits(of: tx) {
            fields.append(split.note)
        }
        return fields
    }

    /// Returns whether a transaction with these fields matches `query`.
    /// - Parameters:
    ///   - query: raw user search text (may contain multiple tokens).
    ///   - fields: text haystack (merchant, category, source, note, …); nils skipped.
    ///   - amountCents: signed amount in cents; made searchable by major unit.
    static func matches(query: String, fields: [String?], amountCents: Int) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        var haystack = fields.compactMap { $0?.folded() }

        // Amount forms so a digit query finds a purchase by its price.
        let cents = abs(amountCents)
        haystack.append("\(cents / 100)")                              // "550"
        haystack.append(String(format: "%d.%02d", cents / 100, cents % 100)) // "550.00"
        haystack.append("\(cents)")                                    // "55000"

        let tokens = trimmed.folded()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        return tokens.allSatisfy { token in
            haystack.contains { $0.contains(token) }
        }
    }
}

extension String {
    /// Lowercase + strip diacritics for substring search.
    func folded() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
