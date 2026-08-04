//
//  BulkDeleteQuadraticMechanismTests.swift
//  FinanceTrackerTests
//
//  WHY save() is quadratic — a controlled 2×2 plus two mechanism probes, run to
//  TEST a hypothesis rather than to confirm it.
//
//  Hypothesis under test: saving a deletion has to maintain the inverse of every
//  relationship the deleted row participates in — removing the row from its
//  Category's to-many `transactions` collection. If that removal is by identity
//  over a large array, it is O(collection size) per deleted row, and the
//  collection is large. That yields the quadratic. Under this hypothesis the
//  asymmetry the cost curve found is not a side signal but the cause: in reset()
//  everything goes, so the collections collapse as the loop proceeds and there is
//  little left to maintain; in deleteAll() half the rows survive, so the
//  collections stay large throughout.
//
//  The previous run could not separate "rows that survive" from "size of the
//  table", because both moved together. This breaks that confound:
//
//    A   8 000 table /  8 000 deleted  — no survivors
//    B  16 000 table /  8 000 deleted  — SAME deletions as A, 8 000 survivors
//    C  16 000 table / 16 000 deleted  — SAME table as B, no survivors
//
//    B ≫ A and B ≫ C  ⇒ survivors are the cost (hypothesis holds)
//    C ≥ B            ⇒ table size is the cost (hypothesis dead)
//
//  Then two probes of the mechanism itself, both holding deletions AND table
//  AND survivors fixed at B's values, varying only the size of the inverse
//  collection each deleted row belongs to:
//
//    D  16 000 / 8 000 across 400 categories  — collections ~57× smaller than B
//    E  16 000 / 8 000 with category == nil   — no inverse collection at all
//
//    D ≪ B  ⇒ cost scales with collection size
//    E ≪ B  ⇒ the relationship maintenance IS the cost
//    E ≈ B  ⇒ relationships are not the driver; look elsewhere
//
//  Same fidelity rules as BulkDeleteCostMeasurementTests: on-disk store, cold
//  context (seeded through a container that is then dropped), phases timed
//  separately. Prints numbers; asserts only that the work happened.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Why bulk-delete save() is quadratic", .serialized)
@MainActor
struct BulkDeleteQuadraticMechanismTests {

    private struct Case {
        let label: String
        let table: Int          // total rows seeded
        let deleted: Int        // how many of them are flagged for deletion
        let categories: Int     // distinct categories the rows spread across
        let attachCategory: Bool
    }

    private struct Phases {
        var fetch = 0.0, loop = 0.0, save = 0.0
        var total: Double { fetch + loop + save }
    }

    // MARK: - Store

    /// Seeds `table` rows, of which `deleted` carry `isPossibleDuplicate`, spread
    /// across `categories` categories (or with no category at all). Returns the
    /// URL with the seeding container already released, so the measurement opens
    /// cold.
    private func seed(_ c: Case) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("quadratic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("measure.sqlite")

        try autoreleasepool {
            let container = try makeContainer(at: url)
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false

            var cats: [FinanceTracker.Category] = []
            if c.attachCategory {
                for i in 0..<c.categories {
                    let cat = FinanceTracker.Category(name: "Cat \(i)", kindRaw: "expense", order: i)
                    ctx.insert(cat)
                    cats.append(cat)
                }
            }

            let daySeconds: TimeInterval = 24 * 60 * 60
            let start = Date().addingTimeInterval(-730 * daySeconds)

            // Flagged rows are INTERLEAVED with survivors rather than appended, so
            // a deleted row is not systematically at one end of its category's
            // collection — otherwise the probe would measure array position
            // instead of array size.
            for i in 0..<c.table {
                let isFlagged = c.deleted == c.table || (c.deleted > 0 && i % 2 == 0 && i / 2 < c.deleted)
                let tx = Transaction(
                    typeRaw: "expense",
                    amountCents: 500 + (i % 300) * 37,
                    currency: "USD",
                    date: start.addingTimeInterval(Double(i % 730) * daySeconds),
                    category: c.attachCategory ? cats[i % cats.count] : nil,
                    source: nil, taxCents: nil, note: nil,
                    merchant: "Merchant \(i % 40)", recurrenceRaw: nil,
                    isPossibleDuplicate: isFlagged
                )
                ctx.insert(tx)
                if i % 500 == 0 { try ctx.save() }
            }
            try ctx.save()
        }
        return url
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    private func ms(_ body: () throws -> Void) rethrows -> Double {
        let t0 = CFAbsoluteTimeGetCurrent()
        try body()
        return (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }

    /// Runs one case: cold-opens the seeded store, times fetch / delete loop /
    /// save separately, and verifies the intended number of rows actually went.
    private func run(_ c: Case) throws -> Phases {
        let url = try seed(c)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let container = try makeContainer(at: url)
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        var p = Phases()
        var rows: [Transaction] = []
        p.fetch = try ms { rows = try DuplicateReviewService.flagged(in: ctx) }
        #expect(rows.count == c.deleted)
        p.loop = ms { for tx in rows { ctx.delete(tx) } }
        p.save = try ms { try ctx.save() }

        let remaining = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(remaining == c.table - c.deleted)
        withExtendedLifetime(container) {}
        return p
    }

    // MARK: - The experiment

    @Test("Break the confound: survivors vs table size, then probe the mechanism")
    func mechanism() throws {
        let cases: [Case] = [
            .init(label: "A  8k table /  8k deleted /   7 cats  (no survivors)",
                  table: 8_000, deleted: 8_000, categories: 7, attachCategory: true),
            .init(label: "B 16k table /  8k deleted /   7 cats  (8k survivors)",
                  table: 16_000, deleted: 8_000, categories: 7, attachCategory: true),
            .init(label: "C 16k table / 16k deleted /   7 cats  (no survivors)",
                  table: 16_000, deleted: 16_000, categories: 7, attachCategory: true),
            .init(label: "D 16k table /  8k deleted / 400 cats  (8k survivors)",
                  table: 16_000, deleted: 8_000, categories: 400, attachCategory: true),
            .init(label: "E 16k table /  8k deleted / NO category (8k survivors)",
                  table: 16_000, deleted: 8_000, categories: 0, attachCategory: false),
        ]

        var results: [(Case, Phases)] = []
        for c in cases {
            let p = try run(c)
            results.append((c, p))
            print(String(format: "[case] %@  fetch=%.0f ms  loop=%.0f ms  save=%.0f ms  total=%.0f ms",
                         c.label, p.fetch, p.loop, p.save, p.total))
        }

        print("\n=== 2×2 + mechanism probes (save() phase is the one that matters) ===")
        for (c, p) in results {
            let perDeleted = p.save / Double(c.deleted) * 1000
            print(String(format: "%@\n      save=%9.0f ms   %7.1f µs per deleted row",
                         c.label, p.save, perDeleted))
        }

        func save(_ i: Int) -> Double { results[i].1.save }
        print("\n--- discriminators ---")
        print(String(format: "B/A = %.2f×  (same deletions, +8k survivors)      → survivors cost this much",
                     save(1) / save(0)))
        print(String(format: "B/C = %.2f×  (B deletes HALF as many as C)        → >1 means survivors beat volume",
                     save(1) / save(2)))
        print(String(format: "C/A = %.2f×  (2× the deletions, both empty out)   → ~2 means linear in deletions",
                     save(2) / save(0)))
        print(String(format: "B/D = %.2f×  (7 cats vs 400, all else identical)  → >1 means collection SIZE is the cost",
                     save(1) / save(3)))
        print(String(format: "B/E = %.2f×  (with category vs none at all)       → >1 means relationship upkeep is the cost",
                     save(1) / save(4)))
    }
}
