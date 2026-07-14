//
//  DailyTip.swift
//  FinanceTracker
//
//  One educational tip: a term, a plain-language explanation, and one actionable
//  strategy. Content is authored outside the app and ships as `tips.json` per
//  locale, so the 365-item library lands without a code change.
//

import Foundation

struct DailyTip: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let term: String
    let explanation: String
    let strategy: String
    let category: String?
}
