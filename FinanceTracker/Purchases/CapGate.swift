//
//  CapGate.swift
//  FinanceTracker
//
//  The forcing gate: "you've hit the free limit" fires on intent, at the moment
//  the user reaches for a new account or category. That is the highest-converting
//  place to ask, and the only honest one — they already know what they want.
//
//  What this gate does NOT do is as important as what it does. It blocks the ADD.
//  It never deletes, hides, locks, or greys out anything that already exists. A
//  user who built nine categories during the reverse trial keeps all nine.
//

import SwiftUI

@MainActor
enum CapGate {

    /// Runs `action` if the user may create one more; otherwise raises the paywall.
    ///
    /// Re-reads StoreKit before refusing (fast, local, no network sync) so a stale
    /// cache can never show a paywall to someone who has already paid.
    static func attempt(_ capability: AppCapability,
                        currentCount: Int,
                        access: AccessManager,
                        showPaywall: Binding<Bool>,
                        action: @escaping () -> Void) {

        if access.canAdd(capability, currentCount: currentCount) {
            action()
            return
        }

        Task {
            await access.refreshFromStoreKit()
            if access.canAdd(capability, currentCount: currentCount) {
                action()
            } else {
                showPaywall.wrappedValue = true
            }
        }
    }
}
