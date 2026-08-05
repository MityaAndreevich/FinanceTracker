//
//  GuardedSave.swift
//  FinanceTracker
//
//  One `save()` guard for the call sites that are too small to deserve a service
//  of their own — a sheet toggling one attribute, a seeder clearing its own rows.
//  The services that DO have their own guard (TransactionEditService,
//  TransactionDeleteService, DuplicateReviewService, TransactionResetService,
//  QuickAddSaveService, MerchantLearningService) keep it; this is for the rest.
//
//  It exists because of a shape the 2026-08 audit found at twelve sites, and the
//  shape — not the swallowed error — is the dangerous part:
//
//      mutate → try? save() → do the side effect anyway
//
//  A side effect that lives OUTSIDE the store (a UserDefaults flag, a dismiss, a
//  toast, a usage signal) is beyond `rollback()`'s reach, so committing it
//  unconditionally makes a failed save indistinguishable from a successful one —
//  permanently. Callers here get a Bool and are expected to gate their side
//  effects on it.
//
//  `revert` exists because `rollback()` does NOT reliably restore a mutated
//  attribute on a live SwiftData object (verified in TransactionEditServiceTests,
//  which is why TransactionEditService carries a full snapshot). Inserts and
//  deletes are pending operations that rollback genuinely reverses and need no
//  revert closure; a changed attribute does.
//

import Foundation
import SwiftData

@MainActor
enum GuardedSave {

    /// Commits, or leaves the store exactly as it was and returns false.
    ///
    /// - Parameters:
    ///   - label: names the call site in the unified log (`logSaveFailure`).
    ///   - revert: restores any ATTRIBUTE this operation mutated. Runs before
    ///     `rollback()`, mirroring `TransactionEditService.update`. Omit for
    ///     pure insert/delete work.
    /// - Returns: whether the change reached disk. Gate every side effect on it.
    @discardableResult
    static func commit(
        _ context: ModelContext,
        _ label: String,
        revert: () -> Void = {}
    ) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            revert()
            context.rollback()
            logSaveFailure(label, error)
            return false
        }
    }
}
