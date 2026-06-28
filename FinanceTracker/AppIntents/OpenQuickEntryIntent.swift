//
//  OpenQuickEntryIntent.swift
//  FinanceTracker
//
//  "Hey Siri, open Quick Entry in Budget Crab" → app opens directly to the
//  Quick Entry sheet. Sets a flag in App Group UserDefaults; ContentView
//  reads it on foreground and presents the sheet.
//

import AppIntents

struct OpenQuickEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Quick Entry"
    static var description = IntentDescription(
        "Open Budget Crab Quick Entry to add a transaction.",
        categoryName: "Money"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.appGroup
        defaults.set(true, forKey: "pendingPresentQuickEntry")
        // Clear the sibling analytics flag so the two intents can never
        // cross-contaminate (a missed-consumption race would otherwise let a
        // stale flag fire on the next unrelated launch).
        defaults.set(false, forKey: "pendingNavigateToAnalytics")
        NotificationCenter.default.post(name: .budgetCrabPendingIntent, object: nil)
        return .result()
    }
}
