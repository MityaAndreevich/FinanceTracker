//
//  QuickAddSaveService.swift
//  FinanceTracker
//
//  Single source of truth for the Quick Add save path.
//  Both DashboardView's QuickAddBar and QuickEntryView use this.
//

import Foundation
import SwiftData
import os

@MainActor
enum QuickAddSaveService {
    enum SaveError: Error { case noCategoryResolvable }

    // Diagnostics for the on-device save/duplication investigation. One increment
    // per `save(...)` call lets the log answer "is Save firing once per tap or
    // looping?" without exposing any user value. See logSaveFailure for the error
    // shape; this only records call count + the branch taken.
    private static var saveCallCount = 0

    // MARK: - Why there is no dedup here
    //
    // There used to be: a 30-second, content-identity window (amount + type +
    // normalized merchant) that returned the already-saved row instead of inserting.
    // It was DATA LOSS. Two coffees at the same price on the same day is an ordinary
    // thing to buy, and the second one vanished — silently, because every caller
    // treats a returned Transaction as success (success haptic, toast, dismiss). The
    // device log showed it plainly: `dedup-hit (returned existing)` while the UI said
    // "saved".
    //
    // The failure is structural, not a matter of tuning the window: identical content
    // simply does not imply an accidental duplicate. Only the user knows whether they
    // bought one coffee or two, and the persistence layer must never guess. A save is
    // an explicit instruction — it always inserts.
    //
    // It was originally added for voice (Bug 4), where the recognizer can redeliver a
    // final result. That case is now handled where it belongs — at the action, not the
    // write: QuickEntryView's `isSaving` re-entrancy guard plus `SaveActionGate`'s
    // debounce. Both are content-BLIND, so neither can drop a distinct entry.
    //
    // Content dedup remains correct for IMPORT (CSVImportService), where the file may
    // genuinely restate rows the user already has and there is no human in the loop.

    /// Test seam: forces the next `save()` to throw AFTER the insert, so the
    /// anti-poison guard (delete-the-failed-insert) can be exercised deterministically.
    /// The in-memory store used in tests never throws on its own, which is precisely
    /// why the on-device duplication couldn't be reproduced in the suite before.
    static var _forceSaveFailureForTesting = false
    private struct _SimulatedSaveError: Error {}

    // MARK: - save

    /// Creates and persists a Transaction from a parsed Quick Add input. ALWAYS
    /// inserts — see "Why there is no dedup here" above.
    /// Records merchant→category learning via MerchantLearningService.
    /// `now` is the transaction's timestamp; injectable so tests can place entries
    /// deterministically in time.
    @discardableResult
    static func save(
        parsed: QuickAddParsedInput,
        modelContext: ModelContext,
        defaultCurrencyCode: String,
        overrideCategory: Category? = nil,
        now: Date = .now
    ) throws -> Transaction {
        saveCallCount += 1
        let callNo = saveCallCount

        guard let category = overrideCategory ?? resolveCategory(for: parsed, in: modelContext) else {
            throw SaveError.noCategoryResolvable
        }

        let tx = Transaction(
            typeRaw: parsed.typeRaw,
            amountCents: parsed.amountCents,
            currency: defaultCurrencyCode,
            date: now,
            category: category,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: parsed.merchant,
            recurrenceRaw: nil
        )
        modelContext.insert(tx)
        do {
            if _forceSaveFailureForTesting { throw _SimulatedSaveError() }
            try modelContext.save()
        } catch {
            // Root-cause guard for the device duplication cascade.
            //
            // A thrown save() leaves `tx` as an UNCOMMITTED pending insert in the
            // long-lived mainContext. Because the container's mainContext has
            // autosave enabled, @Query re-renders that pending row as a visible
            // "transaction" even though nothing reached disk — which is exactly why
            // the dupes vanish on force-quit (see DashboardDuplicationStressTest
            // header) and why the in-memory tests can't reproduce it (the in-memory
            // store never throws). Each retry tap adds another orphaned pending
            // insert → the ~10× fan-out, cross-screen total disagreement, and the
            // follow-on "every save fails" (the next save() re-throws trying to
            // flush the poisoned pending object).
            //
            // Removing our failed insert returns the context to a clean, saveable
            // state so no ghost leaks and later saves recover. Rethrow so the caller
            // still surfaces the error (never fail silently — Bug B2). The precise
            // NSError is logged by the caller via logSaveFailure().
            persistenceLog.error("QuickAddSave #\(callNo, privacy: .public): save() threw — discarding failed insert to keep context clean")
            modelContext.delete(tx)
            throw error
        }
        // Success-path instrumentation only — it answered "is Save firing once per
        // tap or looping?" during the duplication investigation and has no value to
        // a shipped build. DEBUG-only, unlike the failure log below it: a save that
        // THREW still needs to be root-causable off-device (see PersistenceLog.swift).
        #if DEBUG
        persistenceLog.info("QuickAddSave #\(callNo, privacy: .public): inserted 1 row")
        #endif

        MerchantLearningService.record(
            merchant: parsed.merchant,
            categoryName: category.name,
            in: modelContext
        )

        return tx
    }

    /// Category for the Quick Entry / voice preview chip (and the save it commits).
    ///
    /// Deliberately *not* the same as `resolveCategory`: per the Round 8 decision
    /// the + screen does not silently apply a keyword *guess* to expenses (it felt
    /// presumptuous and was often wrong). But a category the user explicitly TAUGHT
    /// for this merchant is a correction, not a guess — so a learned mapping is
    /// honored here. Income still resolves fully (one dedicated Income category).
    ///
    /// Bug (device test #5): the voice path computed "Other" directly and passed it
    /// as `overrideCategory`, bypassing learning entirely — so "Бензин" never picked
    /// up a previously taught "Машина". Routing the + screen through here fixes the
    /// lookup while keeping keyword guesses suppressed, matching the Dashboard path.
    static func previewCategory(for parsed: QuickAddParsedInput, in context: ModelContext) -> Category? {
        if parsed.typeRaw == TransactionType.income.raw {
            return resolveCategory(for: parsed, in: context)
        }

        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        if let merchant = parsed.merchant,
           let learnedName = MerchantLearningService.suggestedCategoryName(for: merchant, in: context),
           let learned = all.first(where: {
               $0.kindRaw == parsed.typeRaw && $0.name.lowercased() == learnedName.lowercased()
           }) {
            return learned
        }

        return all.first { $0.name == "Other" && $0.kindRaw == parsed.typeRaw }
            ?? all.first { $0.name == "Other" }
    }

    /// Priority: learned merchant mapping → parser suggestion → category named "Other".
    static func resolveCategory(for parsed: QuickAddParsedInput, in context: ModelContext) -> Category? {
        let suggestedName = parsed.merchant.flatMap {
            CategorySuggestionService.suggest(forMerchant: $0, in: context)
        } ?? parsed.suggestedCategoryName

        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        if let name = suggestedName {
            let target = name.lowercased()
            let subset = all.filter { $0.kindRaw == parsed.typeRaw }
            if let match = subset.first(where: { cat in
                let localized = cat.nameKey.map { NSLocalizedString($0, comment: "").lowercased() }
                return cat.name.lowercased() == target
                    || cat.displayName().lowercased() == target
                    || localized == target
            }) {
                return match
            }
        }

        return all.first { $0.name == "Other" }
    }
}
