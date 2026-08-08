//
//  UsageSignalOrderingTests.swift
//  FinanceTrackerTests
//
//  F4 (Overnight 2026-08-05). `usage.ever.splits` was marked BEFORE the save that
//  persists the split — the same side-effect-ahead-of-the-save shape the 2026-08
//  audit spent a night removing from twelve store-writing sites, sitting in the
//  one place where it corrupts a DECISION rather than a screen.
//
//  WHY THIS ONE IS DIFFERENT FROM A MIS-REPORTED TOAST
//
//  `usage.ever.splits` is not telemetry. It is the NUMERATOR of a pre-registered
//  kill rule (`DECISION_RECEIPT_INPUT_PRETEST.md`: build only if ≥40% ever-split
//  AND ≥15% habitual, N≥25, thresholds fixed before any data). Over-counting
//  split users pushes toward BUILD — which is the expensive direction, and the
//  direction the rule exists to guard against. The receipt already records
//  self-selection as an upward bias; this would have been a second upward bias
//  in the same direction, in an instrument whose whole purpose is to avoid
//  spending weeks on Vision against false demand.
//
//  TWO DEFECTS, not one. Both are pinned below:
//
//    1. `markUsed` fired inside `apply(...)`, which runs BEFORE `save()`. A user
//       who builds a split and whose save FAILS was counted as having split.
//    2. The failure path calls `apply(prior, ...)` a second time to revert. So an
//       edit that REMOVES splits from a transaction that had them RE-MARKED the
//       flag while failing — the one case where the flag is written by an
//       operation that is, by construction, undoing splits.
//
//  `.recurring` had the identical shape two lines below and is pinned the same way.
//
//  The rate is presumably tiny — every one of these needs a failed save. That is
//  not the point. "Small bias in the safe direction" and "small bias in the
//  expensive direction" are not the same finding, and this is the expensive one.
//
//  ISOLATION: these tests write real `UserDefaults` (that is where the instrument
//  lives, and faking it would test the fake). Every test restores the prior value
//  of the two keys it touches, and the suite is `.serialized` so no two tests race
//  on the same global.
//

import Foundation
import SwiftData
import Testing
@testable import FinanceTracker

@Suite("usage.ever.* is recorded only after the save that earns it", .serialized)
@MainActor
struct UsageSignalOrderingTests {

    // MARK: - Harness

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
            TransactionSplit.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Saves and restores the two flags this suite writes, so a run leaves the
    /// host app's defaults exactly as it found them.
    private func withCleanSignals(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let keys = ["usage.ever.splits", "usage.ever.recurring"]
        let prior = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in prior {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for (key, _) in prior { defaults.removeObject(forKey: key) }
        try body()
    }

    private func seed(in context: ModelContext) -> (Transaction, FinanceTracker.Category) {
        let category = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        context.insert(category)
        let tx = Transaction(
            typeRaw: "expense", amountCents: 5_000, currency: "USD",
            date: Date(), category: category
        )
        context.insert(tx)
        try? context.save()
        return (tx, category)
    }

    private func fields(
        _ tx: Transaction,
        category: FinanceTracker.Category,
        splits: [TransactionEditService.Fields.SplitInput] = [],
        recurrenceRaw: String? = nil
    ) -> TransactionEditService.Fields {
        TransactionEditService.Fields(
            typeRaw: tx.typeRaw, amountCents: tx.amountCents, taxCents: tx.taxCents,
            currency: tx.currency, merchant: tx.merchant, note: tx.note,
            date: tx.date, category: category, source: tx.source,
            recurrenceRaw: recurrenceRaw, splits: splits
        )
    }

    // MARK: - Defect 1: counted without persisting

    @Test("a split whose save FAILS is not counted as ever-split")
    func failedSplitSaveDoesNotCount() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            TransactionEditService._forceSaveFailureForTesting = true
            defer { TransactionEditService._forceSaveFailureForTesting = false }

            #expect(throws: (any Error).self) {
                try TransactionEditService.update(
                    tx,
                    with: fields(tx, category: category, splits: [
                        .init(amountCents: 3_000, category: category, note: nil),
                        .init(amountCents: 2_000, category: category, note: nil),
                    ]),
                    in: context
                )
            }

            #expect(
                !FeatureUsageSignals.wasUsed(.splits),
                "the split never reached disk — counting it inflates the numerator of a kill rule"
            )
        }
    }

    @Test("a recurrence whose save FAILS is not counted as ever-recurring")
    func failedRecurrenceSaveDoesNotCount() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            TransactionEditService._forceSaveFailureForTesting = true
            defer { TransactionEditService._forceSaveFailureForTesting = false }

            #expect(throws: (any Error).self) {
                try TransactionEditService.update(
                    tx,
                    with: fields(tx, category: category, recurrenceRaw: "monthly"),
                    in: context
                )
            }

            #expect(!FeatureUsageSignals.wasUsed(.recurring))
        }
    }

    // MARK: - Defect 2: the revert path re-marks

    /// The nastiest of the two. The user is REMOVING splits, the save fails, and
    /// the revert restores the splits that were already there — which used to run
    /// through the same `apply` that marks the flag. So an operation whose whole
    /// intent was "I do not want splits" wrote "has ever used splits".
    ///
    /// The split is created directly rather than through the service, so the flag
    /// starts genuinely false while the transaction genuinely has splits — the
    /// state of any user who split something before this instrument shipped.
    @Test("reverting a failed split-REMOVAL does not re-mark the flag")
    func revertOfASplitRemovalDoesNotReMark() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            let split = TransactionSplit(amountCents: 5_000, category: category, note: nil, order: 0)
            context.insert(split)
            split.parent = tx
            try context.save()
            #expect(!FeatureUsageSignals.wasUsed(.splits), "precondition: the flag starts false")

            TransactionEditService._forceSaveFailureForTesting = true
            defer { TransactionEditService._forceSaveFailureForTesting = false }

            // splits: [] — the user is taking the split OFF.
            #expect(throws: (any Error).self) {
                try TransactionEditService.update(tx, with: fields(tx, category: category), in: context)
            }

            #expect(
                !FeatureUsageSignals.wasUsed(.splits),
                "the revert path marked the flag while undoing a split removal"
            )
        }
    }

    // MARK: - The instrument still works

    /// The fix must not break what the instrument is FOR. A successful split edit
    /// still counts — otherwise the correction would bias the same rule in the
    /// other direction, which is no more honest.
    @Test("a split that SAVES is still counted")
    func successfulSplitSaveStillCounts() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            try TransactionEditService.update(
                tx,
                with: fields(tx, category: category, splits: [
                    .init(amountCents: 3_000, category: category, note: nil),
                    .init(amountCents: 2_000, category: category, note: nil),
                ]),
                in: context
            )

            #expect(FeatureUsageSignals.wasUsed(.splits))
        }
    }

    @Test("a recurrence that SAVES is still counted")
    func successfulRecurrenceSaveStillCounts() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            try TransactionEditService.update(
                tx,
                with: fields(tx, category: category, recurrenceRaw: "monthly"),
                in: context
            )

            #expect(FeatureUsageSignals.wasUsed(.recurring))
        }
    }

    /// An edit with no splits and no recurrence must touch neither flag. Guards
    /// the obvious over-correction — moving the marks past the save but firing
    /// them unconditionally.
    @Test("an ordinary edit marks nothing")
    func ordinaryEditMarksNothing() throws {
        try withCleanSignals {
            let context = try makeContext()
            let (tx, category) = seed(in: context)

            try TransactionEditService.update(tx, with: fields(tx, category: category), in: context)

            #expect(!FeatureUsageSignals.wasUsed(.splits))
            #expect(!FeatureUsageSignals.wasUsed(.recurring))
        }
    }
}
