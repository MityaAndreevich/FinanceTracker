//
//  BulkDeleteFixMeasurementTests.swift
//  FinanceTrackerTests
//
//  Does `TransactionDeleteService.detachForBulkDelete` actually remove the
//  quadratic, on a store shaped like a real user's?
//
//  `BulkDeleteQuadraticMechanismTests` established the MECHANISM — the cost is
//  maintaining the inverse of `Category.transactions`, 62× over the `category ==
//  nil` floor. This file measures the FIX, and it deliberately fixes the gap that
//  made the original number a lower bound.
//
//  ## The seeding gap this file closes (required, not optional)
//
//  Every row in the original measurement had `source == nil` and NO splits. Real
//  users have accounts assigned, and `Source.transactions` is a second to-many with
//  an explicit inverse — same maintenance, same shape. `Category.splits` is a third:
//  `Transaction.splits` is `.cascade`, so deleting a parent deletes its splits, and
//  each cascaded child then has to be identity-removed from its own Category's
//  `splits` array.
//
//  So 49.2 s at 8k was a LOWER BOUND for the shipped app, and a fix that detached
//  only the category could not have reached the floor on real data. Here every row
//  carries a source, and a third of them carry splits.
//
//  ## The target, and the RESULT (measured 2026-08-13, iPhone 17 Pro sim, Debug)
//
//  Target was NOT 720 ms. That is case E's floor — a store with no category at all,
//  which still materializes and saves 16,000 objects. Case D (400 categories,
//  collections ~57× smaller) still came in ≈1.2 s, which is exactly why "spread the
//  collection thinner" is not the answer and "have nothing left to maintain" is.
//  Predicted: the floor plus one linear pass, **≈0.7–1.2 s at 8k**.
//
//      === 16000 table / 8000 deleted / 7 cats / 3 sources / splits every 3 ===
//      [baseline] fetch=333  loop=59   save=147530  TOTAL=147922 ms
//      [fixed   ] fetch=335  detach=1506  loop=34  save=996  TOTAL=2870 ms
//      save() 148.1x faster;  end-to-end 51.5x faster
//
//  **`save()` = 996 ms — inside the predicted band.** The prediction held.
//
//  **And the "lower bound" warning was not theoretical.** The original measurement,
//  category-only with no sources and no splits, put this case at 44,664 ms. On a
//  realistically-shaped store it is **147,530 ms — 3.3× worse**. A user with
//  accounts assigned and some split purchases was waiting nearly two and a half
//  MINUTES on a main-thread block, not the 45 s the old number implied.
//
//  **Stated honestly: end-to-end is 2.87 s, not 1 s.** The detach itself costs
//  1,506 ms — more than the save it enables — because it reads `tx.splits` for
//  every doomed row and rebuilds three sets of collections. That is the price of
//  turning O(n²) into O(n) and it is worth paying at 51×, but "≈1 s end to end"
//  would be an overclaim. If this is ever pushed further, the detach is now the
//  bigger half and the place to look.
//
//  Shape follows case B — 16k table, 8k deleted, 8k SURVIVING — because that is the
//  worst case and the one a real user hits: in a full reset the collections collapse
//  as the loop proceeds, but when half the rows survive they stay large throughout.
//
//  Same fidelity rules as the other two files: on-disk store, cold context (seeded
//  through a container that is then released), phases timed separately. Prints
//  numbers; asserts the ledger is CORRECT and that the fix is a large win, never an
//  exact millisecond figure — a wall-clock equality assertion on a simulator is a
//  flake generator.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Bulk-delete fix, measured on a realistically-shaped store", .serialized)
@MainActor
struct BulkDeleteFixMeasurementTests {

    private static let table = 16_000
    private static let deleted = 8_000
    private static let categories = 7
    private static let sources = 3
    /// Every third deleted row carries splits, so the `.cascade` axis is exercised.
    private static let splitEvery = 3

    private struct Phases {
        var fetch = 0.0, detach = 0.0, loop = 0.0, save = 0.0
        var total: Double { fetch + detach + loop + save }
    }

    // MARK: - Store

    /// Seeds a store where every row has a category AND a source, and every third
    /// row also has two splits. Returns the URL with the seeding container already
    /// released so the measurement opens cold.
    private func seed() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bulkfix-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("measure.sqlite")

        try autoreleasepool {
            let container = try makeContainer(at: url)
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false

            var cats: [FinanceTracker.Category] = []
            for i in 0..<Self.categories {
                let cat = FinanceTracker.Category(name: "Cat \(i)", kindRaw: "expense", order: i)
                ctx.insert(cat)
                cats.append(cat)
            }
            var srcs: [Source] = []
            for i in 0..<Self.sources {
                let s = Source(name: "Account \(i)")
                ctx.insert(s)
                srcs.append(s)
            }

            let daySeconds: TimeInterval = 24 * 60 * 60
            let start = Date().addingTimeInterval(-730 * daySeconds)

            for i in 0..<Self.table {
                // Flagged rows INTERLEAVED with survivors so a deleted row is not
                // systematically at one end of its collection — otherwise this
                // measures array position instead of array size.
                let isFlagged = i % 2 == 0 && i / 2 < Self.deleted
                let tx = Transaction(
                    typeRaw: "expense",
                    amountCents: 500 + (i % 300) * 37,
                    currency: "USD",
                    date: start.addingTimeInterval(Double(i % 730) * daySeconds),
                    category: cats[i % cats.count],
                    source: srcs[i % srcs.count],
                    taxCents: nil, note: nil,
                    merchant: "Merchant \(i % 40)", recurrenceRaw: nil,
                    isPossibleDuplicate: isFlagged
                )
                ctx.insert(tx)

                if i % Self.splitEvery == 0 {
                    // Two parts, under the parent total so the split is valid.
                    for part in 0..<2 {
                        // A DIFFERENT category from the parent, so the cascade has
                        // real work to do in a second collection.
                        let split = TransactionSplit(
                            amountCents: 100,
                            category: cats[(i + 1 + part) % cats.count],
                            order: part
                        )
                        split.parent = tx
                        ctx.insert(split)
                    }
                }

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

    /// `print()` inside a test is NOT forwarded to xcodebuild's stdout
    /// (ARCHITECTURE.md), so a measurement that only prints reports nothing — the
    /// run goes green and the numbers are gone. A file is the reliable channel back,
    /// and it is the same one `MainThreadStallMonitor` already uses.
    private func record(_ line: String) {
        let path = "/tmp/bulk-delete-fix-measure.txt"
        let stamped = line + "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(Data(stamped.utf8))
            try? handle.close()
        } else {
            try? stamped.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private func ms(_ body: () throws -> Void) rethrows -> Double {
        let t0 = CFAbsoluteTimeGetCurrent()
        try body()
        return (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }

    /// One run over a freshly-seeded store. `detaching` selects the fix.
    private func run(detaching: Bool) throws -> Phases {
        let url = try seed()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let container = try makeContainer(at: url)
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let splitsBefore = try ctx.fetchCount(FetchDescriptor<TransactionSplit>())

        var p = Phases()
        var rows: [Transaction] = []
        p.fetch = try ms { rows = try DuplicateReviewService.flagged(in: ctx) }
        #expect(rows.count == Self.deleted)

        if detaching {
            p.detach = ms { TransactionDeleteService.detachForBulkDelete(rows) }
        }
        p.loop = ms { for tx in rows { ctx.delete(tx) } }
        p.save = try ms { try ctx.save() }

        // CORRECTNESS, and it matters more than the milliseconds. The detach must
        // not change the outcome — only its cost.
        let remaining = try ctx.fetchCount(FetchDescriptor<Transaction>())
        #expect(remaining == Self.table - Self.deleted)

        // The `.cascade` on Transaction.splits must still have fired: no orphaned
        // TransactionSplit rows. Orphans are INVISIBLE to aggregation, so this is
        // the failure mode that would never surface on its own.
        let splitsAfter = try ctx.fetchCount(FetchDescriptor<TransactionSplit>())
        #expect(splitsAfter < splitsBefore, "deleting parents must cascade to their splits")
        let orphans = try ctx.fetch(FetchDescriptor<TransactionSplit>()).filter { $0.parent == nil }
        #expect(orphans.isEmpty, "\(orphans.count) orphaned splits survived the delete")

        withExtendedLifetime(container) {}
        return p
    }

    // MARK: - The measurement

    @Test("detachForBulkDelete removes the quadratic on a category+source+splits store")
    func fixIsMeasured() throws {
        record("=== \(Self.table) table / \(Self.deleted) deleted / \(Self.categories) cats"
               + " / \(Self.sources) sources / splits every \(Self.splitEvery) ===")

        let before = try run(detaching: false)
        record(String(
            format: "[baseline] fetch=%.0f  loop=%.0f  save=%.0f  TOTAL=%.0f ms",
            before.fetch, before.loop, before.save, before.total
        ))

        let after = try run(detaching: true)
        record(String(
            format: "[fixed   ] fetch=%.0f  detach=%.0f  loop=%.0f  save=%.0f  TOTAL=%.0f ms",
            after.fetch, after.detach, after.loop, after.save, after.total
        ))

        let saveSpeedup = before.save / max(after.save, 0.001)
        let totalSpeedup = before.total / max(after.total, 0.001)
        record(String(format: "save() %.1fx faster;  end-to-end %.1fx faster;  detach cost %.0f ms",
                      saveSpeedup, totalSpeedup, after.detach))

        // Deliberately loose. The claim under test is "the quadratic is gone", not a
        // millisecond figure a busy simulator could miss. The mechanism run measured
        // 62× between the same two conditions; anything below 5× means the fix is
        // not doing what it claims and the number needs re-deriving, not relaxing.
        #expect(saveSpeedup > 5.0, "save() must be dramatically cheaper; got \(saveSpeedup)×")
        #expect(after.total < before.total, "the detach must not cost more than it saves")
    }
}
