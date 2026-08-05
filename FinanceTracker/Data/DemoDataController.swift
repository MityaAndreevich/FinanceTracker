//
//  DemoDataController.swift
//  FinanceTracker
//
//  Manages opt-in sample data that users can add/clear from Settings or the
//  tutorial's last page. All seeded transactions carry isDemo == true so they
//  can be removed atomically without touching real user data.
//
//  Unlike DemoSeeder (which wipes everything for screenshots), this controller
//  only inserts demo transactions alongside the existing store.
//

import Foundation
import SwiftData

@MainActor
enum DemoDataController {
    private static let demoFlagKey = "hasDemoDataActive"

    static var isDemoDataActive: Bool {
        get { UserDefaults.standard.bool(forKey: demoFlagKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoFlagKey) }
    }

    /// Seeds demo transactions into the existing store. Idempotent — no-op if
    /// sample data is already active.
    ///
    /// The flag is written only if the rows actually landed. It lives in
    /// UserDefaults — outside the store, beyond `rollback()`'s reach — so setting
    /// it on a failed save desynchronises it from the ledger permanently: the app
    /// believes demo data is present, `clearDemoData` finds nothing to remove, and
    /// the banner cannot be dismissed by clearing.
    @discardableResult
    static func seedDemoData() -> Bool {
        guard !isDemoDataActive else { return true }
        let ctx = SharedModelContainer.shared.mainContext
        guard seedTransactionsIntoExistingStore(modelContext: ctx) else { return false }
        isDemoDataActive = true
        return true
    }

    /// Atomically removes all demo-flagged transactions.
    ///
    /// Same rule, and the worse direction: clearing the flag after a failed save
    /// leaves demo rows in the store while the app believes there are none — and
    /// `seedDemoData` then re-seeds on the next request, putting a SECOND set of
    /// sample transactions into the user's real ledger.
    @discardableResult
    static func clearDemoData(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.isDemo == true })
        guard let demoTxs = try? modelContext.fetch(descriptor) else { return false }
        demoTxs.forEach { modelContext.delete($0) }
        guard GuardedSave.commit(modelContext, "DemoDataController.clearDemoData") else { return false }
        isDemoDataActive = false
        return true
    }

    // MARK: - Private seeding

    /// Inserts demo transactions, reusing existing seeded categories and sources.
    /// Skips insertion if matching category is not found (prevents orphaned data).
    /// - Returns: whether the rows reached disk. `seedDemoData` gates the
    ///   UserDefaults flag on this.
    private static func seedTransactionsIntoExistingStore(modelContext: ModelContext) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let usd = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "USD"

        func date(_ daysAgo: Int) -> Date {
            cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        }

        guard let allCategories = try? modelContext.fetch(FetchDescriptor<Category>()),
              let allSources = try? modelContext.fetch(FetchDescriptor<Source>()) else {
            return false
        }

        func cat(_ name: String) -> Category? {
            allCategories.first { $0.name == name }
        }
        func src(_ name: String) -> Source? {
            allSources.first { $0.name == name }
        }

        struct Entry {
            let daysAgo: Int; let catName: String; let srcName: String?
            let cents: Int; let merchant: String?; let type: String
        }

        let entries: [Entry] = [
            Entry(daysAgo: 60, catName: "Income",        srcName: nil,            cents: 280_000, merchant: "Paycheck",      type: "income"),
            Entry(daysAgo: 58, catName: "Food & Drink",  srcName: nil,            cents: 8_700,   merchant: "Whole Foods",   type: "expense"),
            Entry(daysAgo: 58, catName: "Subscriptions", srcName: nil,            cents: 999,     merchant: "Spotify",       type: "expense"),
            Entry(daysAgo: 55, catName: "Transport",     srcName: nil,            cents: 4_200,   merchant: "Shell",         type: "expense"),
            Entry(daysAgo: 50, catName: "Food & Drink",  srcName: nil,            cents: 5_800,   merchant: "Sweetgreen",    type: "expense"),
            Entry(daysAgo: 46, catName: "Income",        srcName: nil,            cents: 280_000, merchant: "Paycheck",      type: "income"),
            Entry(daysAgo: 44, catName: "Food & Drink",  srcName: nil,            cents: 9_400,   merchant: "Whole Foods",   type: "expense"),
            Entry(daysAgo: 41, catName: "Transport",     srcName: nil,            cents: 3_900,   merchant: "Shell",         type: "expense"),
            Entry(daysAgo: 35, catName: "Housing",       srcName: nil,            cents: 145_000, merchant: "Rent",          type: "expense"),
            Entry(daysAgo: 32, catName: "Income",        srcName: nil,            cents: 280_000, merchant: "Paycheck",      type: "income"),
            Entry(daysAgo: 30, catName: "Food & Drink",  srcName: nil,            cents: 10_300,  merchant: "Whole Foods",   type: "expense"),
            Entry(daysAgo: 25, catName: "Food & Drink",  srcName: nil,            cents: 4_200,   merchant: "Sweetgreen",    type: "expense"),
            Entry(daysAgo: 22, catName: "Transport",     srcName: nil,            cents: 4_400,   merchant: "Shell",         type: "expense"),
            Entry(daysAgo: 22, catName: "Entertainment", srcName: nil,            cents: 1_900,   merchant: "Bookstore",     type: "expense"),
            Entry(daysAgo: 18, catName: "Income",        srcName: nil,            cents: 280_000, merchant: "Paycheck",      type: "income"),
            Entry(daysAgo: 16, catName: "Food & Drink",  srcName: nil,            cents: 8_700,   merchant: "Whole Foods",   type: "expense"),
            Entry(daysAgo: 16, catName: "Subscriptions", srcName: nil,            cents: 1_549,   merchant: "Netflix",       type: "expense"),
            Entry(daysAgo: 14, catName: "Entertainment", srcName: nil,            cents: 1_600,   merchant: "AMC Theater",   type: "expense"),
            Entry(daysAgo: 10, catName: "Housing",       srcName: nil,            cents: 145_000, merchant: "Rent",          type: "expense"),
            Entry(daysAgo: 8,  catName: "Transport",     srcName: nil,            cents: 4_300,   merchant: "Shell",         type: "expense"),
            Entry(daysAgo: 6,  catName: "Food & Drink",  srcName: nil,            cents: 11_200,  merchant: "Whole Foods",   type: "expense"),
            Entry(daysAgo: 4,  catName: "Income",        srcName: nil,            cents: 280_000, merchant: "Paycheck",      type: "income"),
            Entry(daysAgo: 3,  catName: "Food & Drink",  srcName: nil,            cents: 4_800,   merchant: "Sweetgreen",    type: "expense"),
            Entry(daysAgo: 2,  catName: "Subscriptions", srcName: nil,            cents: 999,     merchant: "Spotify",       type: "expense"),
            Entry(daysAgo: 1,  catName: "Transport",     srcName: nil,            cents: 2_400,   merchant: "Uber",          type: "expense"),
        ]

        for e in entries {
            guard let category = cat(e.catName) else { continue }
            let source = e.srcName.flatMap { src($0) }
            let tx = Transaction(
                typeRaw: e.type,
                amountCents: e.cents,
                currency: usd,
                date: date(e.daysAgo),
                category: category,
                source: source,
                merchant: e.merchant,
                isDemo: true
            )
            modelContext.insert(tx)
        }

        guard GuardedSave.commit(modelContext, "DemoDataController.seed") else { return false }

        #if DEBUG
        print("[DemoDataController] ✓ Demo transactions seeded — \(entries.count) entries")
        #endif
        return true
    }
}
