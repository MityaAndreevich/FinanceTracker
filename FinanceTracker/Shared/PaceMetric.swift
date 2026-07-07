//
//  PaceMetric.swift
//  FinanceTracker
//
//  Spending-velocity cue for the current period (Item 3). Compares the user's
//  day-to-date spend rate this month against their *own* recent daily baseline —
//  no budget required — so the message is framed as "faster / less than usual",
//  never an alarm. Meaning is always carried by an SF Symbol + a localized text
//  label, not by hue alone (color-blind safe); tints stay calm (no alarm-red),
//  in keeping with the Quiet-Premium positioning.
//
//  Pure evaluation lives in `evaluate(...)` and is unit-tested without any view.
//

import SwiftUI

enum PaceMetric {

    /// Where this period's spending sits relative to the user's usual pace.
    enum State: Equatable {
        /// Spending faster than the user's typical daily rate.
        case faster
        /// Roughly on the user's typical rate (within tolerance).
        case onPace
        /// Spending below the user's typical rate.
        case under
        /// Not enough history (or no elapsed time) to judge — the cue is hidden.
        case unavailable

        /// Whether the cue should render at all.
        var isShown: Bool { self != .unavailable }

        var labelKey: LocalizedStringKey {
            switch self {
            case .faster: return "analytics.pace.faster"
            case .onPace: return "analytics.pace.on"
            case .under:  return "analytics.pace.under"
            case .unavailable: return ""
            }
        }

        /// Speed/pace-flavored glyph, deliberately distinct from the money
        /// direction arrows in the Earned/Spent rows.
        var systemImage: String {
            switch self {
            case .faster: return "gauge.with.dots.needle.67percent"
            case .onPace: return "gauge.with.dots.needle.50percent"
            case .under:  return "gauge.with.dots.needle.33percent"
            case .unavailable: return "gauge.with.dots.needle.50percent"
            }
        }

        /// Calm tints — amber for faster (a nudge, not an alarm), neutral for on
        /// pace, positive for under. Never alarm-red.
        var tint: Color {
            switch self {
            case .faster: return .bcWarning
            case .onPace: return .bcTextSecondary
            case .under:  return .bcPositive
            case .unavailable: return .clear
            }
        }
    }

    /// Evaluate spending pace.
    ///
    /// - Parameters:
    ///   - spentThisPeriodCents: gross expense so far this period (≥ 0).
    ///   - elapsedDays: days elapsed in the period *including today* (the current
    ///     day-to-date window). Must be > 0 to judge — day 0 / an empty period
    ///     yields `.unavailable` (no divide-by-zero).
    ///   - baselineDailyCents: the user's typical daily expense from prior history.
    ///     Must be > 0 to judge — a brand-new user with no history has no "usual"
    ///     to compare against, so the cue stays hidden.
    ///   - tolerance: ± fraction around the baseline treated as "on pace".
    static func evaluate(
        spentThisPeriodCents: Int,
        elapsedDays: Int,
        baselineDailyCents: Double,
        tolerance: Double = 0.15
    ) -> State {
        guard elapsedDays > 0,
              baselineDailyCents > 0,
              spentThisPeriodCents >= 0 else { return .unavailable }

        let currentDaily = Double(spentThisPeriodCents) / Double(elapsedDays)
        let ratio = currentDaily / baselineDailyCents

        if ratio > 1 + tolerance { return .faster }
        if ratio < 1 - tolerance { return .under }
        return .onPace
    }
}
