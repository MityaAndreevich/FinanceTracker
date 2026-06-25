//
//  RatingPromptCoordinator.swift
//  FinanceTracker
//
//  Fires the native rating prompt at two "moment of success" triggers:
//    A) 5th saved transaction
//    B) 3rd distinct calendar day the app is opened
//
//  Research basis — Notebook 04c87827: prompts during onboarding measurably
//  depress avg rating; prompts at meaningful milestones secure 4.0+ required
//  for editorial featuring. 90-day cooldown matches Apple's 3/year cap.
//

import Foundation
import StoreKit
import UIKit

@MainActor
enum RatingPromptCoordinator {
    private static let lastPromptDateKey     = "ratingPrompt.lastDate"
    private static let savedTxCountKey       = "ratingPrompt.savedTxCount"
    private static let distinctDaysSeenKey   = "ratingPrompt.distinctDaysSeen"
    private static let lastDaySeenKey        = "ratingPrompt.lastDaySeen"

    // MARK: - Public API

    /// Call after every successful transaction save (Add / Edit / Quick Entry).
    /// Trigger A fires on the 5th save.
    static func recordTransactionSaved() {
        let count = UserDefaults.standard.integer(forKey: savedTxCountKey) + 1
        UserDefaults.standard.set(count, forKey: savedTxCountKey)
        if count == 5 { requestReviewIfEligible() }
    }

    /// Call from ContentView .task on every cold launch / foreground.
    /// Trigger B fires on the 3rd distinct calendar day.
    static func recordSessionOpen() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if let last = UserDefaults.standard.object(forKey: lastDaySeenKey) as? Date,
           cal.isDate(last, inSameDayAs: today) {
            return  // already recorded today
        }

        let days = UserDefaults.standard.integer(forKey: distinctDaysSeenKey) + 1
        UserDefaults.standard.set(days, forKey: distinctDaysSeenKey)
        UserDefaults.standard.set(today, forKey: lastDaySeenKey)

        if days == 3 { requestReviewIfEligible() }
    }

    /// Call when the user replays the tutorial from Settings.
    /// Resets milestone counters so the triggers can fire again for a first-time
    /// feel — the quarterly cooldown is intentionally preserved.
    static func resetForTutorialReplay() {
        UserDefaults.standard.removeObject(forKey: savedTxCountKey)
        UserDefaults.standard.removeObject(forKey: distinctDaysSeenKey)
        UserDefaults.standard.removeObject(forKey: lastDaySeenKey)
    }

    // MARK: - Eligibility + request

    private static func requestReviewIfEligible() {
        // Quarterly cooldown — Apple rate-limits to 3/year; we add our own gate for control.
        if let last = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
            guard days >= 90 else { return }
        }

        // Don't prompt before the user has finished the tutorial
        guard UserDefaults.standard.bool(forKey: "hasSeenFeatureTour") else { return }

        // Don't prompt when the user is exploring with synthetic demo data
        guard !DemoDataController.isDemoDataActive else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        AppStore.requestReview(in: scene)
        UserDefaults.standard.set(Date.now, forKey: lastPromptDateKey)
    }
}
