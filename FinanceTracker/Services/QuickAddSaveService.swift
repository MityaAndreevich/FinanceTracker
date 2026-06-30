//
//  QuickAddSaveService.swift
//  FinanceTracker
//
//  Single source of truth for the Quick Add save path.
//  Both DashboardView's QuickAddBar and QuickEntryView use this.
//

import Foundation
import SwiftData

@MainActor
enum QuickAddSaveService {
    enum SaveError: Error { case noCategoryResolvable }

    // MARK: - Idempotency (Bug 4)

    /// Bug 4 (device test #3): a voiced "Бензин 500" created three identical
    /// transactions — the recognizer delivered repeated final results and each
    /// raced through the save path. A view-level re-entrancy guard can't cover
    /// every entry point (Dashboard auto-save, QuickEntry, the App Intent), so
    /// dedup lives here, at the single shared write.
    ///
    /// A save with the same amount + type + normalized merchant within
    /// `dedupWindowSeconds` returns the already-persisted transaction instead of
    /// inserting a duplicate. Pattern (idempotency key) validated against
    /// NotebookLM 73afc9a4 as the industry-standard quick-add dedup approach.
    static let dedupWindowSeconds: TimeInterval = 30

    private struct DedupKey: Hashable {
        let amountCents: Int
        let typeRaw: String
        let merchantNormalized: String
    }

    private static var recentSaves: [DedupKey: (uuid: UUID, at: Date)] = [:]

    /// Test seam: clears the dedup window so suites don't bleed into each other.
    static func _resetDedupCacheForTesting() { recentSaves.removeAll() }

    private static func dedupKey(for parsed: QuickAddParsedInput) -> DedupKey {
        DedupKey(
            amountCents: parsed.amountCents,
            typeRaw: parsed.typeRaw,
            merchantNormalized: (parsed.merchant ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    private static func pruneRecentSaves(now: Date) {
        recentSaves = recentSaves.filter { now.timeIntervalSince($0.value.at) < dedupWindowSeconds }
    }

    private static func transaction(uuid: UUID, in context: ModelContext) -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - save

    /// Creates and persists a Transaction from a parsed Quick Add input.
    /// Records merchant→category learning via MerchantLearningService.
    /// `now` is injectable for deterministic dedup-window tests.
    @discardableResult
    static func save(
        parsed: QuickAddParsedInput,
        modelContext: ModelContext,
        defaultCurrencyCode: String,
        overrideCategory: Category? = nil,
        now: Date = .now
    ) throws -> Transaction {
        let key = dedupKey(for: parsed)
        pruneRecentSaves(now: now)

        // Same amount/type/merchant within the window → return the existing row.
        if let recent = recentSaves[key],
           now.timeIntervalSince(recent.at) < dedupWindowSeconds,
           let existing = transaction(uuid: recent.uuid, in: modelContext) {
            return existing
        }

        guard let category = overrideCategory ?? resolveCategory(for: parsed, in: modelContext) else {
            throw SaveError.noCategoryResolvable
        }

        let tx = Transaction(
            typeRaw: parsed.typeRaw,
            amountCents: parsed.amountCents,
            currency: defaultCurrencyCode,
            date: .now,
            category: category,
            source: nil,
            taxCents: nil,
            note: nil,
            merchant: parsed.merchant,
            recurrenceRaw: nil
        )
        modelContext.insert(tx)
        try modelContext.save()

        recentSaves[key] = (tx.uuid, now)

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
