//
//  SourceCreateService.swift
//  FinanceTracker
//
//  Creating an account (`Source`), as a guarded choke-point. F3 companion to
//  `CategoryLimitService` — see that file's header for why these were extracted.
//
//  The original defect, in the sheet's own words: "Dismissing regardless is what
//  made a failure invisible: the sheet closed and the user was told nothing while
//  no account had been created."
//

import Foundation
import SwiftData

@MainActor
enum SourceCreateService {

    /// Trims, inserts and commits.
    ///
    /// - Returns: the persisted `Source`, or `nil` if the name was blank or the
    ///   save threw. **Gate the dismiss and the `onAdded` callback on a non-nil
    ///   return** — `onAdded` re-reads the account list, and running it after a
    ///   failed insert shows a list that does not contain what the user just
    ///   "added".
    @discardableResult
    static func add(name: String, note: String?, in context: ModelContext) -> Source? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let trimmedNote = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(name: trimmedName, note: trimmedNote.isEmpty ? nil : trimmedNote)

        context.insert(source)
        // No `revert:` closure — an insert is a PENDING operation that
        // `rollback()` genuinely reverses. Only mutated ATTRIBUTES need one.
        guard GuardedSave.commit(context, "AddSourceSheet.add") else { return nil }
        return source
    }
}
