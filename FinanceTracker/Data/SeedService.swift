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
            var descriptor = FetchDescriptor<Category>()
            descriptor.fetchLimit = 1
            let existing = try modelContext.fetch(descriptor)

            if existing.isEmpty {
                seedFreshDatabase(modelContext: modelContext)
            } else {
                let all = try modelContext.fetch(FetchDescriptor<Category>())
                migrateLegacyCategoriesIfNeeded(all, modelContext: modelContext)
                let refreshed = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? all
                addMissingDefaultCategoriesIfNeeded(refreshed, modelContext: modelContext)
            }
        } catch {
            print("SeedService failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Spec table

    private struct CategorySpec {
        let name: String
        let nameKey: String
        let kindRaw: String
        let icon: String
        let order: Int
        let isPrimary: Bool
    }

    private static let defaultCategorySpecs: [CategorySpec] = [
        // PRIMARY — expense (6)
        CategorySpec(name: "Food & Drink",  nameKey: "category.food_drink",   kindRaw: "expense", icon: "fork.knife",         order: 1,   isPrimary: true),
        CategorySpec(name: "Transport",     nameKey: "category.transport",     kindRaw: "expense", icon: "car.fill",           order: 2,   isPrimary: true),
        CategorySpec(name: "Housing",       nameKey: "category.housing",       kindRaw: "expense", icon: "house.fill",         order: 3,   isPrimary: true),
        CategorySpec(name: "Shopping",      nameKey: "category.shopping",      kindRaw: "expense", icon: "bag.fill",           order: 4,   isPrimary: true),
        CategorySpec(name: "Entertainment", nameKey: "category.entertainment", kindRaw: "expense", icon: "film",               order: 5,   isPrimary: true),
        CategorySpec(name: "Other",         nameKey: "category.other",         kindRaw: "expense", icon: "square.grid.2x2",   order: 6,   isPrimary: true),
        // PRIMARY — income (1)
        CategorySpec(name: "Income",        nameKey: "category.income",        kindRaw: "income",  icon: "dollarsign.circle",  order: 100, isPrimary: true),
        // SECONDARY — expense (6); parser still matches these; picker hides behind "Show all"
        CategorySpec(name: "Health",        nameKey: "category.health",        kindRaw: "expense", icon: "heart",              order: 10,  isPrimary: false),
        CategorySpec(name: "Subscriptions", nameKey: "category.subscriptions", kindRaw: "expense", icon: "rectangle.stack",   order: 11,  isPrimary: false),
        CategorySpec(name: "Coffee",        nameKey: "category.coffee",        kindRaw: "expense", icon: "cup.and.saucer",    order: 12,  isPrimary: false),
        CategorySpec(name: "Travel",        nameKey: "category.travel",        kindRaw: "expense", icon: "airplane",           order: 13,  isPrimary: false),
        CategorySpec(name: "Personal Care", nameKey: "category.personal_care", kindRaw: "expense", icon: "scissors",           order: 14,  isPrimary: false),
        CategorySpec(name: "Utilities",     nameKey: "category.utilities",     kindRaw: "expense", icon: "bolt",               order: 15,  isPrimary: false),
    ]

    // MARK: - Fresh seed

    private static func seedFreshDatabase(modelContext: ModelContext) {
        for spec in defaultCategorySpecs {
            let cat = Category(
                name: spec.name,
                kindRaw: spec.kindRaw,
                icon: spec.icon,
                order: spec.order,
                nameKey: spec.nameKey,
                isPrimary: spec.isPrimary
            )
            modelContext.insert(cat)
        }
        do {
            try modelContext.save()
        } catch {
            print("Seed failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Add missing categories (idempotent)

    static func addMissingDefaultCategoriesIfNeeded(
        _ existing: [Category],
        modelContext: ModelContext
    ) {
        let existingKeys = Set(existing.compactMap { $0.nameKey })
        var added = false
        for spec in defaultCategorySpecs where !existingKeys.contains(spec.nameKey) {
            let cat = Category(
                name: spec.name,
                kindRaw: spec.kindRaw,
                icon: spec.icon,
                order: spec.order,
                nameKey: spec.nameKey,
                isPrimary: spec.isPrimary
            )
            modelContext.insert(cat)
            added = true
        }
        if added {
            try? modelContext.save()
        }
    }

    // MARK: - Migration (existing users)

    private static func migrateLegacyCategoriesIfNeeded(
        _ categories: [Category],
        modelContext: ModelContext
    ) {
        var didChange = false

        // Build lookup by nameKey
        var byKey: [String: Category] = [:]
        for cat in categories {
            if let k = cat.nameKey { byKey[k] = cat }
        }

        // 1:1 renames: old nameKey → (new nameKey, new English name)
        let renames: [(old: String, newKey: String, newName: String)] = [
            ("category.food",     "category.food_drink", "Food & Drink"),
            ("category.gas",      "category.transport",  "Transport"),
            ("category.rent",     "category.housing",    "Housing"),
            ("category.supplies", "category.shopping",   "Shopping"),
        ]

        for (old, newKey, newName) in renames {
            guard let cat = byKey[old] else { continue }
            if byKey[newKey] != nil {
                // Target already exists — this old entry is a duplicate; will be merged below
                continue
            }
            cat.nameKey = newKey
            cat.name = newName
            byKey[newKey] = cat
            byKey.removeValue(forKey: old)
            didChange = true
        }

        // Merge: these old keys should fold into an already-renamed (or existing) category
        // Key = old nameKey, Value = target nameKey
        let mergeTargets: [String: String] = [
            "category.coffee":  "category.food_drink",
            "category.transit": "category.transport",
            // Also handle the case where rename above left a duplicate
            "category.food":    "category.food_drink",
            "category.gas":     "category.transport",
            "category.rent":    "category.housing",
            "category.supplies":"category.shopping",
        ]

        // Re-build lookup after renames
        byKey = [:]
        for cat in categories { if let k = cat.nameKey { byKey[k] = cat } }

        for (oldKey, targetKey) in mergeTargets {
            guard let loser = byKey[oldKey] else { continue }
            guard let winner = byKey[targetKey], winner.uuid != loser.uuid else { continue }

            // Re-point all transactions from loser to winner
            let allTxs = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
            for tx in allTxs where tx.category.uuid == loser.uuid {
                tx.category = winner
                didChange = true
            }

            modelContext.delete(loser)
            byKey.removeValue(forKey: oldKey)
            didChange = true
        }

        // For categories with no nameKey (and not user-defined), try to assign one
        let refreshedCats = categories.filter { !$0.hasNameKey && !$0.isUserDefined }
        for cat in refreshedCats {
            if let key = mapLegacyNameToKey(cat.name) {
                cat.nameKey = key
                didChange = true
            }
        }

        guard didChange else { return }
        do {
            try modelContext.save()
        } catch {
            print("Category migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy name → new nameKey

    private static func mapLegacyNameToKey(_ name: String) -> String? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "food", "groceries", "restaurants", "coffee": return "category.food_drink"
        case "gas", "auto", "car", "transit":              return "category.transport"
        case "rent", "mortgage", "utilities":              return "category.housing"
        case "supplies", "shopping":                       return "category.shopping"
        case "entertainment", "recreation":                return "category.entertainment"
        case "health", "medical", "fitness":               return "category.health"
        case "subscriptions":                              return "category.subscriptions"
        case "other":                                      return "category.other"
        case "income", "salary":                           return "category.income"
        default:                                           return nil
        }
    }
}
