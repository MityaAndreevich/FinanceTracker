//
//  DemoSeeder.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 23.06.2026.
//
//  Seeds a deterministic, HIG-compliant dataset for App Store screenshots
//  and TestFlight demos. ONLY active when the `--demo-mode` launch argument
//  is passed (production launches use SeedService.seedIfNeeded instead).
//
//  HIG inclusion principles applied (Apple HIG → Foundations → Inclusion →
//  People and settings, sourced via NotebookLM ff5e0abc on 2026-06-23):
//   - No displays of affluence. Coffee $4.50, not $14.50. Groceries $87, not $487.
//   - Familiar merchants only (Whole Foods, Spotify, Uber, Starbucks).
//   - Amounts anchored to U.S. Bureau of Labor Statistics Consumer Expenditure
//     Survey medians (notebook 73afc9a4).
//   - One intentional spending anomaly (6 days ago, grocery run ~30% above
//     typical) so the Smart Insights screen has something to surface in
//     screenshot frame 3.
//
//  Cross-reference: APP_STORE_ASSETS.md §4 "Apple HIG inclusion principles".
//

import Foundation
import SwiftData

enum DemoSeeder {

    // MARK: - Public API

    /// Returns true if the app was launched with `--demo-mode`.
    /// Used by `ContentView` to decide whether to reset + seed demo data
    /// or run the regular `SeedService.seedIfNeeded`.
    static var isDemoMode: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-mode")
        #else
        // Production Release builds MUST NOT process --demo-mode (catastrophic data loss).
        // Guard prevents accidental scheme misconfiguration from wiping user data.
        return false
        #endif
    }

    /// Wipes ALL existing user data and replaces it with the canonical demo
    /// dataset. Idempotent — running twice produces identical state.
    ///
    /// NEVER call this in production. Guarded by `isDemoMode` check on caller side.
    static func resetAndSeedDemoData(modelContext: ModelContext) {
        do {
            try wipeAll(modelContext: modelContext)

            let categories = seedDemoCategories(modelContext: modelContext)
            let sources = seedDemoSources(modelContext: modelContext)
            seedDemoTransactions(
                modelContext: modelContext,
                categories: categories,
                sources: sources
            )

            try modelContext.save()

            #if DEBUG
            print("[DemoSeeder] ✓ Demo data seeded — \(categories.count) categories, \(sources.count) sources, ~44 transactions")
            #endif
        } catch {
            print("[DemoSeeder] ⚠️ Failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Wipe

    private static func wipeAll(modelContext: ModelContext) throws {
        // Order matters: Transaction.category uses .deny — delete transactions
        // first so categories have no referencing objects at save time.
        let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        allTransactions.forEach { modelContext.delete($0) }

        let allSources = try modelContext.fetch(FetchDescriptor<Source>())
        allSources.forEach { modelContext.delete($0) }

        let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
        allCategories.forEach { modelContext.delete($0) }

        try modelContext.save()

        #if DEBUG
        print("[DemoSeeder] ✓ wipeAll complete — \(allTransactions.count) tx, \(allSources.count) sources, \(allCategories.count) categories cleared")
        #endif
    }

    // MARK: - Categories

    /// Returns a dictionary keyed by English name (used in the transaction-seed
    /// table below). Categories carry localization keys and isPrimary so they
    /// match the production seed exactly — screenshots look identical to a fresh install.
    private static func seedDemoCategories(modelContext: ModelContext) -> [String: Category] {
        let specs: [(name: String, key: String, kind: String, icon: String, order: Int, primary: Bool)] = [
            // PRIMARY expense
            ("Food & Drink",  "category.food_drink",   "expense", "fork.knife",        1,   true),
            ("Transport",     "category.transport",     "expense", "car.fill",          2,   true),
            ("Housing",       "category.housing",       "expense", "house.fill",        3,   true),
            ("Shopping",      "category.shopping",      "expense", "bag.fill",          4,   true),
            ("Entertainment", "category.entertainment", "expense", "film",              5,   true),
            ("Other",         "category.other",         "expense", "square.grid.2x2",  6,   true),
            // PRIMARY income
            ("Income",        "category.income",        "income",  "dollarsign.circle", 100, true),
            // SECONDARY expense — visible in Settings, hidden behind "Show all" in pickers
            ("Health",        "category.health",        "expense", "heart",             10,  false),
            ("Subscriptions", "category.subscriptions", "expense", "rectangle.stack",   11,  false),
            ("Coffee",        "category.coffee",        "expense", "cup.and.saucer",    12,  false),
            ("Travel",        "category.travel",        "expense", "airplane",          13,  false),
            ("Personal Care", "category.personal_care", "expense", "scissors",          14,  false),
            ("Utilities",     "category.utilities",     "expense", "bolt",              15,  false),
        ]

        var dict: [String: Category] = [:]
        for s in specs {
            let cat = Category(
                name: s.name,
                kindRaw: s.kind,
                icon: s.icon,
                order: s.order,
                nameKey: s.key,
                isPrimary: s.primary
            )
            modelContext.insert(cat)
            dict[s.name] = cat
        }
        return dict
    }

    // MARK: - Sources (accounts)

    private static func seedDemoSources(modelContext: ModelContext) -> [String: Source] {
        let names = ["Checking", "Credit Card", "Cash"]
        var dict: [String: Source] = [:]
        for n in names {
            let s = Source(name: n)
            modelContext.insert(s)
            dict[n] = s
        }
        return dict
    }

    // MARK: - Transactions

    /// Seeds ~40 transactions spanning the last 60 days. Amounts pulled from
    /// median US household spending (BLS CES). All merchants are mainstream,
    /// non-status-signaling per HIG inclusion guidance.
    ///
    /// The 6-days-ago grocery line is intentionally ~30% above the rolling
    /// average so the Smart Insights screen has a real anomaly to surface
    /// for screenshot frame #3.
    private static func seedDemoTransactions(
        modelContext: ModelContext,
        categories: [String: Category],
        sources: [String: Source]
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let usd = "USD"

        func date(_ daysAgo: Int) -> Date {
            cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        }

        // (daysAgo, categoryKey, sourceKey?, amountCents, merchant?, type)
        struct Entry {
            let daysAgo: Int
            let category: String
            let source: String?
            let cents: Int
            let merchant: String?
            let type: String

            init(_ daysAgo: Int, _ cat: String, _ src: String?, _ cents: Int,
                 _ merchant: String? = nil, _ type: String = "expense") {
                self.daysAgo = daysAgo
                self.category = cat
                self.source = src
                self.cents = cents
                self.merchant = merchant
                self.type = type
            }
        }

        let entries: [Entry] = [
            // 60d
            Entry(60, "Income", "Checking", 280_000, "Paycheck", "income"),

            // 58d
            Entry(58, "Food & Drink",  "Credit Card", 8_700, "Whole Foods"),
            Entry(58, "Subscriptions", "Credit Card",   999, "Spotify"),

            // 55d
            Entry(55, "Coffee",    "Cash",          450, "Blue Bottle"),  // secondary category demo
            Entry(55, "Transport", "Credit Card", 4_200, "Shell"),

            // 50d
            Entry(50, "Food & Drink", "Credit Card", 5_800, "Sweetgreen"),

            // 48d
            Entry(48, "Coffee",    "Cash",          450, "Starbucks"),
            Entry(48, "Transport", "Credit Card", 1_200, "Uber"),

            // 47d
            Entry(47, "Subscriptions", "Credit Card", 1_549, "Netflix"),

            // 46d
            Entry(46, "Income", "Checking", 280_000, "Paycheck", "income"),

            // 44d
            Entry(44, "Food & Drink", "Credit Card", 9_400, "Whole Foods"),
            Entry(44, "Coffee",       "Cash",          450, "Blue Bottle"),

            // 41d
            Entry(41, "Transport", "Credit Card", 3_900, "Shell"),
            Entry(41, "Utilities", "Checking",    8_700, "Electric bill"),  // secondary category demo

            // 38d
            Entry(38, "Coffee", "Cash",          450, "Starbucks"),
            Entry(38, "Health", "Credit Card", 2_300, "Walgreens"),

            // 35d
            Entry(35, "Health",  "Credit Card",  3_500, "Gym membership"),
            Entry(35, "Housing", "Checking",   145_000, "Rent"),

            // 32d
            Entry(32, "Income", "Checking", 280_000, "Paycheck", "income"),

            // 30d
            Entry(30, "Food & Drink", "Credit Card", 10_300, "Whole Foods"),
            Entry(30, "Coffee",       "Cash",            450, "Blue Bottle"),

            // 28d
            Entry(28, "Subscriptions", "Credit Card", 999, "Spotify"),

            // 25d
            Entry(25, "Food & Drink", "Credit Card", 4_200, "Sweetgreen"),
            Entry(25, "Coffee",       "Cash",           450, "Starbucks"),

            // 22d
            Entry(22, "Transport",     "Credit Card", 4_400, "Shell"),
            Entry(22, "Entertainment", "Credit Card", 1_900, "Bookstore"),

            // 18d
            Entry(18, "Income", "Checking", 280_000, "Paycheck", "income"),

            // 16d
            Entry(16, "Food & Drink",  "Credit Card", 8_700, "Whole Foods"),
            Entry(16, "Subscriptions", "Credit Card", 1_549, "Netflix"),
            Entry(16, "Coffee",        "Cash",          450, "Blue Bottle"),

            // 14d
            Entry(14, "Entertainment", "Credit Card", 1_600, "AMC Theater"),
            Entry(14, "Transport",     "Credit Card", 1_800, "Uber"),

            // 12d
            Entry(12, "Health", "Credit Card", 3_500, "Gym membership"),

            // 10d
            Entry(10, "Housing", "Checking", 145_000, "Rent"),

            // 8d
            Entry(8, "Coffee",    "Cash",          450, "Starbucks"),
            Entry(8, "Transport", "Credit Card", 4_300, "Shell"),

            // 6d — INTENTIONAL ANOMALY (~+30% vs rolling grocery avg)
            Entry(6, "Food & Drink", "Credit Card", 11_200, "Whole Foods"),

            // 4d
            Entry(4, "Income", "Checking", 280_000, "Paycheck", "income"),

            // 3d
            Entry(3, "Coffee",       "Cash",          450, "Blue Bottle"),
            Entry(3, "Food & Drink", "Credit Card", 4_800, "Sweetgreen"),

            // 2d
            Entry(2, "Subscriptions", "Credit Card", 999, "Spotify"),

            // 1d
            Entry(1, "Coffee",    "Cash",          450, "Starbucks"),
            Entry(1, "Transport", "Credit Card", 2_400, "Uber"),

            // 0d (today) — last visible row in the list
            Entry(0, "Coffee", "Cash", 450, "Blue Bottle"),
        ]

        for e in entries {
            guard let cat = categories[e.category] else {
                #if DEBUG
                print("[DemoSeeder] ⚠️ Missing category '\(e.category)' — skipping entry")
                #endif
                continue
            }
            let src = e.source.flatMap { sources[$0] }
            let tx = Transaction(
                typeRaw: e.type,
                amountCents: e.cents,
                currency: usd,
                date: date(e.daysAgo),
                category: cat,
                source: src,
                merchant: e.merchant
            )
            modelContext.insert(tx)
        }
    }
}
