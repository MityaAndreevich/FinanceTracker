//
//  VelaShortcuts.swift
//  FinanceTracker
//
//  Surfaces three shortcuts automatically in the Shortcuts app, Siri suggestions,
//  Spotlight, and the Action Button — no user setup required.
//

import AppIntents

struct VelaShortcuts: AppShortcutsProvider {
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
