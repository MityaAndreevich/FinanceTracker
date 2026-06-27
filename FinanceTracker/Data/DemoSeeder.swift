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

    /// Returns true if the app was launched in demo mode.
    /// Accepts either `--demo-mode-debug-only` (used by the screenshot capture
    /// script) or the legacy `--demo-mode` alias. Used by `ContentView` to decide
    /// whether to reset + seed demo data or run `SeedService.seedIfNeeded`.
    static var isDemoMode: Bool {
        #if DEBUG
        let args = CommandLine.arguments
        return args.contains("--demo-mode-debug-only") || args.contains("--demo-mode")
        #else
        // Production Release builds MUST NOT process demo flags (catastrophic data
        // loss). This guard prevents an accidental scheme misconfiguration or a
        // stray launch argument from wiping real user data.
        return false
        #endif
    }

    /// Wipes ALL existing user data and replaces it with the canonical demo
    /// dataset. Idempotent — running twice produces identical state.
    ///
    /// NEVER call this in production without `markAsDemo: true`. When called from
    /// DemoDataController the transactions are flagged so they can be cleared atomically.
    static func resetAndSeedDemoData(modelContext: ModelContext, markAsDemo: Bool = false) {
        do {
            // Pick the locale-appropriate seed (currency + merchants + account names).
            // Falls back to the bundled English seed if the requested locale is missing.
            let seed = loadSeed(localeCode: ScreenshotMode.demoLocaleCode)

            try wipeAll(modelContext: modelContext)

            // Mirror the seed currency into the app-wide default so every aggregation
            // (Dashboard, Analytics, AppIntents) renders in the in-frame currency.
            applyDemoCurrency(seed.currencyCode)

            let categories = seedDemoCategories(modelContext: modelContext)
            let sources = seedDemoSources(modelContext: modelContext, specs: seed.sources)
            seedDemoTransactions(
                modelContext: modelContext,
                seed: seed,
                categories: categories,
                sources: sources,
                markAsDemo: markAsDemo
            )

            try modelContext.save()

            #if DEBUG
            print("[DemoSeeder] ✓ Seeded '\(seed.locale)' (\(seed.currencyCode)) — \(categories.count) categories, \(sources.count) sources, \(seed.transactions.count) transactions")
            #endif
        } catch {
            #if DEBUG
            print("[DemoSeeder] ⚠️ Failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Locale-appropriate seed loading

    /// Decoded shape of `DemoSeeds/DemoSeed_<locale>.json`.
    struct Seed: Decodable {
        let locale: String
        let currencyCode: String
        let sources: [SourceSpec]
        let transactions: [TxSpec]

        struct SourceSpec: Decodable {
            let key: String
            let name: String
        }
        struct TxSpec: Decodable {
            let daysAgo: Int
            let category: String   // English category name — maps to seedDemoCategories keys
            let source: String?    // source key, matches SourceSpec.key
            let minor: Int         // amount in minor currency units (cents/kopecks/centavos)
            let merchant: String?
            let type: String       // "income" | "expense"
        }
    }

    /// Loads `DemoSeed_<localeCode>.json` from the app bundle, falling back to the
    /// English seed (and finally a hardcoded USD seed) if a resource is missing.
    private static func loadSeed(localeCode: String) -> Seed {
        if let seed = decodeSeed(named: "DemoSeed_\(localeCode)") { return seed }
        #if DEBUG
        print("[DemoSeeder] ⚠️ No seed for '\(localeCode)' — falling back to en")
        #endif
        if let fallback = decodeSeed(named: "DemoSeed_en") { return fallback }
        // Last-resort empty USD seed so a missing-resource build never crashes.
        return Seed(locale: "en", currencyCode: "USD", sources: [], transactions: [])
    }

    private static func decodeSeed(named name: String) -> Seed? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Seed.self, from: data)
    }

    /// Writes the demo currency to both the standard and App Group defaults so
    /// `@AppStorage("defaultCurrencyCode")` views and AppIntents agree.
    private static func applyDemoCurrency(_ code: String) {
        UserDefaults.standard.set(code, forKey: "defaultCurrencyCode")
        UserDefaults.appGroup.set(code, forKey: "defaultCurrencyCode")
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

    /// Inserts the locale-appropriate accounts and returns them keyed by their
    /// stable seed `key` (e.g. "checking") so transactions can reference them
    /// regardless of the localized display name.
    private static func seedDemoSources(
        modelContext: ModelContext,
        specs: [Seed.SourceSpec]
    ) -> [String: Source] {
        var dict: [String: Source] = [:]
        for spec in specs {
            let s = Source(name: spec.name)
            modelContext.insert(s)
            dict[spec.key] = s
        }
        return dict
    }

    // MARK: - Transactions

    /// Inserts the ~44 transactions from the locale seed, spanning the last 60
    /// days. Amounts are localized per currency but follow the same anchored,
    /// non-status-signaling profile (median household spending, HIG inclusion).
    ///
    /// The 6-days-ago grocery line is intentionally ~30% above the rolling
    /// average so the Smart Insights screen has a real anomaly to surface
    /// for screenshot frame #4.
    private static func seedDemoTransactions(
        modelContext: ModelContext,
        seed: Seed,
        categories: [String: Category],
        sources: [String: Source],
        markAsDemo: Bool = false
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func date(_ daysAgo: Int) -> Date {
            cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        }

        for e in seed.transactions {
            guard let cat = categories[e.category] else {
                #if DEBUG
                print("[DemoSeeder] ⚠️ Missing category '\(e.category)' — skipping entry")
                #endif
                continue
            }
            let src = e.source.flatMap { sources[$0] }
            let tx = Transaction(
                typeRaw: e.type,
                amountCents: e.minor,
                currency: seed.currencyCode,
                date: date(e.daysAgo),
                category: cat,
                source: src,
                merchant: e.merchant,
                isDemo: markAsDemo
            )
            modelContext.insert(tx)
        }
    }
}
