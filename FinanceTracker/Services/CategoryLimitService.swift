//
//  CategoryLimitService.swift
//  FinanceTracker
//
//  Setting and clearing a category's monthly limit, as a guarded choke-point.
//
//  F3 (Overnight 2026-08-05): the fix for these two sites shipped in the 2026-08
//  save-site audit, but it shipped UNTESTED because both lived inside a
//  `private struct CategoryLimitSheet` in `CategoriesSourcesView.swift` and there
//  was nothing to call. An untested fix to an ERROR path is the fix most likely
//  to be silently wrong — the error path is the one nobody exercises, so a
//  regression there is invisible until a user hits it and reports "I set a
//  budget and it vanished".
//
//  Extracting it is the same move `TransactionDeleteService` made for the two
//  destructive paths, and for the same reason: the interesting behaviour is what
//  happens when `save()` throws, and that is only assertable against something a
//  test can hold.
//
//  Not a policy object. `CategoryLimitPolicy` (Shared/) answers "is this category
//  over its limit"; this answers "did the limit reach disk".
//

import Foundation
import SwiftData

@MainActor
enum CategoryLimitService {

    /// Sets `cents` as the category's monthly limit.
    ///
    /// - Returns: whether it reached disk. **Gate every side effect on this** —
    ///   dismissing the sheet on a failed write is what made the original defect
    ///   invisible: the sheet closed and the user was told nothing while no limit
    ///   had been recorded.
    @discardableResult
    static func setLimit(_ cents: Int, on category: Category, in context: ModelContext) -> Bool {
        let prior = category.limitCents
        category.limitCents = cents
        guard GuardedSave.commit(context, "CategoryLimitSheet.save",
                                 revert: { category.limitCents = prior }) else {
            return false
        }
        // Only after the limit exists on disk. `usage.ever.*` is the pre-test
        // instrument with a pre-registered kill rule — recording "used" for a
        // feature the user did not get corrupts a number a ship decision rests
        // on. Same ordering rule as TransactionEditService; see
        // UsageSignalOrderingTests.
        FeatureUsageSignals.markUsed(.categoryLimits)
        return true
    }

    /// Removes the category's monthly limit.
    ///
    /// No usage mark: clearing a limit is not "using category limits", and
    /// marking here would let a user who only ever REMOVED a limit count toward
    /// the feature.
    @discardableResult
    static func clearLimit(on category: Category, in context: ModelContext) -> Bool {
        let prior = category.limitCents
        category.limitCents = nil
        return GuardedSave.commit(context, "CategoryLimitSheet.clear",
                                  revert: { category.limitCents = prior })
    }
}
