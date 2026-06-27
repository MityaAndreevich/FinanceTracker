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
        UserDefaults.appGroup.set(true, forKey: "pendingPresentQuickEntry")
        return .result()
    }
}
