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
            // Set the monthly budget so the Dashboard hero shows the redesigned
            // "safe to spend" (remaining + $/day + budget bar), not the net fallback.
            applyDemoBudget(seed.budgetMinor)

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

            // Teach the merchant→category mappings so the app "knows" this demo
            // user's merchants — makes the Quick Entry parsed-preview screenshot show
            // a real colored category tile. Runs AFTER the primary save (record()
            // rolls back its own context on failure).
            seedMerchantLearnings(seed: seed, modelContext: modelContext)

            #if DEBUG
            print("[DemoSeeder] ✓ Seeded '\(seed.locale)' (\(seed.currencyCode)) — \(categories.count) categories, \(sources.count) sources, \(seed.transactions.count) transactions")
            #endif
        } catch {
            #if DEBUG
            print("[DemoSeeder] ⚠️ Failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Onboarding demo sandbox (guarded, reversible)

    /// Test seam: forces the guarded onboarding seed to throw AFTER inserting, so the
    /// delete-on-failure cleanup can be exercised deterministically (the in-memory
    /// store never throws on its own). Mirrors QuickAddSaveService._forceSaveFailureForTesting.
    static var _forceOnboardingSeedFailureForTesting = false
    private struct _SimulatedSeedError: Error {}

    /// Adds the locale-appropriate demo transactions to the CURRENT store (marked
    /// `isDemo`) for the onboarding "Explore with demo data" sandbox — WITHOUT wiping
    /// the user's data, unlike `resetAndSeedDemoData`.
    ///
    /// Part C safety: every insert is committed by a SINGLE guarded `save()`. If it
    /// throws, the just-inserted rows are deleted so no poisoned/ghost pending inserts
    /// leak into the long-lived mainContext (the mid-fix save bug). Reversible: the
    /// rows are `isDemo`, cleared by `clearDemoData` or Settings → Reset Transactions.
    @MainActor
    @discardableResult
    static func seedOnboardingDemoGuarded(modelContext: ModelContext) throws -> Int {
        let seed = loadSeed(localeCode: onboardingSeedLocaleCode())
        let currency = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? seed.currencyCode

        // Map to the categories already seeded on launch (by canonical English name);
        // never insert duplicate categories.
        let existing = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        var byName: [String: Category] = [:]
        for cat in existing where byName[cat.name] == nil { byName[cat.name] = cat }

        var inserted: [Transaction] = []
        for e in seed.transactions {
            guard let cat = byName[e.category] else { continue }
            let tx = Transaction(
                typeRaw: e.type,
                amountCents: e.minor,
                currency: currency,
                date: demoDate(dayOfMonth: e.dayOfMonth),
                category: cat,
                source: nil,
                merchant: e.merchant,
                isDemo: true
            )
            modelContext.insert(tx)
            inserted.append(tx)
        }

        do {
            if _forceOnboardingSeedFailureForTesting { throw _SimulatedSeedError() }
            try modelContext.save()
        } catch {
            // Delete-on-failure: return the context to a clean, saveable state.
            for tx in inserted { modelContext.delete(tx) }
            throw error
        }
        return inserted.count
    }

    /// Removes only the demo sandbox rows, leaving any real transactions untouched.
    @MainActor
    static func clearDemoData(modelContext: ModelContext) {
        let demo = (try? modelContext.fetch(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo })
        )) ?? []
        for tx in demo { modelContext.delete(tx) }
        try? modelContext.save()
    }

    /// True when any demo sandbox rows are present (drives the Dashboard "Demo data" banner).
    @MainActor
    static func hasDemoData(modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo })
        descriptor.fetchLimit = 1
        return ((try? modelContext.fetch(descriptor)) ?? []).isEmpty == false
    }

    /// Maps the active app language to a bundled DemoSeed file code (falls back to en
    /// inside loadSeed when the file is missing, e.g. uk).
    private static func onboardingSeedLocaleCode() -> String {
        switch UserDefaults.standard.string(forKey: "appLanguageCode") ?? "system" {
        case "pt": return "pt-BR"
        case "ru": return "ru"
        case "es": return "es"
        default:   return "en"
        }
    }

    /// Day N of the current month at local noon, clamped to now (never future) — the
    /// same anchoring `seedDemoTransactions` uses, hoisted so the guarded seeder shares it.
    private static func demoDate(dayOfMonth: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? cal.startOfDay(for: now)
        let day = max(1, min(dayOfMonth, 28))
        let base = cal.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
        return min(noon, now)
    }

    // MARK: - Locale-appropriate seed loading

    /// Decoded shape of `DemoSeeds/DemoSeed_<locale>.json`.
    struct Seed: Decodable {
        let locale: String
        let currencyCode: String
        let budgetMinor: Int       // overall monthly budget → @AppStorage("monthlyBudgetCents")
        let sources: [SourceSpec]
        let transactions: [TxSpec]

        struct SourceSpec: Decodable {
            let key: String
            let name: String
        }
        struct TxSpec: Decodable {
            let dayOfMonth: Int    // 1…28, anchored inside the CURRENT month
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
        return Seed(locale: "en", currencyCode: "USD", budgetMinor: 0, sources: [], transactions: [])
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

    /// Writes the demo monthly budget (minor units → cents) that the Dashboard hero
    /// reads via `@AppStorage("monthlyBudgetCents")`.
    private static func applyDemoBudget(_ minor: Int) {
        UserDefaults.standard.set(minor, forKey: "monthlyBudgetCents")
        UserDefaults.appGroup.set(minor, forKey: "monthlyBudgetCents")
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

    /// Inserts the ~33 transactions from the locale seed, anchored to day-of-month
    /// inside the CURRENT month so the redesigned current-month Dashboard/Analytics
    /// always look full (regardless of capture date). Amounts are localized per
    /// currency but follow the same anchored, non-status-signaling profile (median
    /// household spending, HIG inclusion).
    private static func seedDemoTransactions(
        modelContext: ModelContext,
        seed: Seed,
        categories: [String: Category],
        sources: [String: Source],
        markAsDemo: Bool = false
    ) {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? cal.startOfDay(for: now)

        /// Day N of the current month at local noon. Clamped to `now` so a date is
        /// never in the future — keeps every row inside the analytics
        /// [monthStart, today] window even when captured early in the month.
        func date(dayOfMonth: Int) -> Date {
            let day = max(1, min(dayOfMonth, 28))
            let base = cal.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
            return min(noon, now)
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
                date: date(dayOfMonth: e.dayOfMonth),
                category: cat,
                source: src,
                merchant: e.merchant,
                isDemo: markAsDemo
            )
            modelContext.insert(tx)
        }
    }

    /// Records the demo user's merchant→category choices so `previewCategory`
    /// resolves a real colored category in the Quick Entry parsed-preview capture.
    private static func seedMerchantLearnings(seed: Seed, modelContext: ModelContext) {
        for e in seed.transactions where e.type == "expense" {
            MerchantLearningService.record(
                merchant: e.merchant,
                categoryName: e.category,
                in: modelContext
            )
        }
    }
}
