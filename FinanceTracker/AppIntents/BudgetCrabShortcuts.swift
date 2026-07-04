//
//  BudgetCrabShortcuts.swift
//  FinanceTracker
//
//  Surfaces three shortcuts automatically in the Shortcuts app, Siri suggestions,
//  Spotlight, and the Action Button — no user setup required.
//

import AppIntents
import Foundation

extension Notification.Name {
    /// Posted by app-opening intents right after they write their pending-navigation
    /// flag. ContentView observes it so consumption happens *after* the write, even
    /// when the app is already foreground and no scenePhase change fires.
    static let budgetCrabPendingIntent = Notification.Name("budgetCrabPendingIntent")

    /// Posted by Settings → "Replay tutorial" so ContentView re-runs the first-run
    /// coach-mark flow immediately (jumping to the Dashboard) without a relaunch.
    static let budgetCrabReplayOnboarding = Notification.Name("budgetCrabReplayOnboarding")

    /// Posted by the Dashboard "Recent → See all" link so ContentView switches to the
    /// Transactions tab (device QA round 1 #7).
    static let budgetCrabNavigateToTransactions = Notification.Name("budgetCrabNavigateToTransactions")
}

struct BudgetCrabShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Add transaction to \(.applicationName)",
                "Add expense to \(.applicationName)",
                "Record transaction in \(.applicationName)",
                "Записать трату в \(.applicationName)",
                "Добавить транзакцию в \(.applicationName)",
            ],
            shortTitle: "Add Transaction",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenQuickEntryIntent(),
            phrases: [
                "Open Quick Entry in \(.applicationName)",
                "Quick add in \(.applicationName)",
                "Открыть быстрый ввод в \(.applicationName)",
            ],
            shortTitle: "Quick Entry",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ShowSpendingIntent(),
            phrases: [
                "Show spending in \(.applicationName)",
                "How much did I spend in \(.applicationName)",
                "Сколько я потратил в \(.applicationName)",
            ],
            shortTitle: "Show Spending",
            systemImageName: "chart.pie.fill"
        )
    }
}
