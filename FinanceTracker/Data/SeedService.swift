//
//  SeedService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import Foundation
import SwiftData

enum SeedService {
    static func seedIfNeeded(modelContext: ModelContext) {
        // Проверяем, есть ли уже категории
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        let categories: [Category] = [
            Category(name: "Food",      kindRaw: "expense", icon: "fork.knife", order: 1),
            Category(name: "Gas",       kindRaw: "expense", icon: "fuelpump", order: 2),
            Category(name: "Rent",      kindRaw: "expense", icon: "house", order: 3),
            Category(name: "Supplies",  kindRaw: "expense", icon: "cart", order: 4),
            Category(name: "Other",     kindRaw: "expense", icon: "square.grid.2x2", order: 5),
            Category(name: "Income",    kindRaw: "income",  icon: "dollarsign.circle", order: 100)
        ]

        categories.forEach { modelContext.insert($0) }

        do {
            try modelContext.save()
        } catch {
            // В MVP допустим простой print. Позже заменим на нормальный логгер.
            print("Seed failed: \(error)")
        }
    }
}
