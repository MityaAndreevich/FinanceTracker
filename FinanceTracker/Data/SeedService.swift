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
        do {
            // ✅ дешевле, чем fetch всех объектов: нам важно только "есть ли хоть одна категория"
            var descriptor = FetchDescriptor<Category>()
            descriptor.fetchLimit = 1

            let existing = try modelContext.fetch(descriptor)

            if existing.isEmpty {
                seedFreshDatabase(modelContext: modelContext)
            } else {
                // Миграция legacy-имен -> nameKey (uuid тут вообще не при чем)
                let all = try modelContext.fetch(FetchDescriptor<Category>())
                migrateLegacyCategoriesIfNeeded(all, modelContext: modelContext)
            }
        } catch {
            print("SeedService failed: \(error)")
        }
    }

    // MARK: - Fresh seed (new install)

    private static func seedFreshDatabase(modelContext: ModelContext) {

        let categories: [Category] = [
            Category(
                name: "Food",
                kindRaw: "expense",
                icon: "fork.knife",
                order: 1,
                nameKey: "category.food"
            ),
            Category(
                name: "Gas",
                kindRaw: "expense",
                icon: "fuelpump",
                order: 2,
                nameKey: "category.gas"
            ),
            Category(
                name: "Rent",
                kindRaw: "expense",
                icon: "house",
                order: 3,
                nameKey: "category.rent"
            ),
            Category(
                name: "Supplies",
                kindRaw: "expense",
                icon: "cart",
                order: 4,
                nameKey: "category.supplies"
            ),
            Category(
                name: "Other",
                kindRaw: "expense",
                icon: "square.grid.2x2",
                order: 5,
                nameKey: "category.other"
            ),
            Category(
                name: "Income",
                kindRaw: "income",
                icon: "dollarsign.circle",
                order: 100,
                nameKey: "category.income"
            )
        ]

        categories.forEach { modelContext.insert($0) }

        do {
            try modelContext.save()
        } catch {
            print("Seed failed: \(error)")
        }
    }

    // MARK: - Migration (existing users)

    /// Если у пользователя уже есть категории, но они были созданы
    /// в старой версии (без nameKey) — аккуратно проставляем ключи.
    private static func migrateLegacyCategoriesIfNeeded(
        _ categories: [Category],
        modelContext: ModelContext
    ) {
        var didChange = false

        for category in categories {

            // 1) пользовательская категория — не трогаем
            if let custom = category.nameCustom, !custom.isEmpty {
                continue
            }

            // 2) если ключ уже есть — не трогаем
            if category.hasNameKey {
                continue
            }

            // 3) пытаемся промаппить старое имя на ключ
            if let key = mapLegacyNameToKey(category.name) {
                category.nameKey = key
                didChange = true
            }
        }

        guard didChange else { return }

        do {
            try modelContext.save()
        } catch {
            print("Category migration failed: \(error)")
        }
    }

    // MARK: - Legacy mapping

    /// Маппинг старых англ. названий → стабильные localization keys
    private static func mapLegacyNameToKey(_ name: String) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch n {
        case "food":     return "category.food"
        case "gas":      return "category.gas"
        case "rent":     return "category.rent"
        case "supplies": return "category.supplies"
        case "other":    return "category.other"
        case "income":   return "category.income"
        default:         return nil
        }
    }
}
