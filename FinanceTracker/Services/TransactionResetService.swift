//
//  TransactionResetService.swift
//  FinanceTracker
//
//  Single, testable home for "Reset all transactions" (Settings → General).
//
//  Bug 20 (device test #7): the reset factually wiped every transaction but the
//  alert still reported an error ("Произошло несколько ошибок проверки"). The old
//  handler treated a thrown `modelContext.save()` as authoritative failure — but
//  SwiftData can surface aggregated, non-fatal validation noise on a bulk delete
//  even when the rows are actually gone. The fix: the post-delete COUNT is the
//  source of truth, not whether save() threw. If nothing remains, it succeeded.
//

import Foundation
import SwiftData

@MainActor
enum TransactionResetService {

    /// Outcome of a reset, decided by what is left in the store afterward.
    enum Outcome: Equatable {
        case success
        case failure(remaining: Int)
    }

    /// Maps a post-delete remaining count to an outcome. Pure decision rule, split
    /// out so the count-authoritative behavior (Bug 20) is directly testable.
    static func outcome(remaining: Int) -> Outcome {
        remaining == 0 ? .success : .failure(remaining: remaining)
    }

    /// Deletes every Transaction, then verifies by re-counting. A thrown save error
    /// is deliberately swallowed: it is only meaningful if rows actually survive,
    /// which the count check below catches. Returns `.success` when the store is
    /// empty afterward, `.failure(remaining:)` otherwise.
    @discardableResult
    static func reset(in context: ModelContext) -> Outcome {
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in all { context.delete(tx) }
        do {
            try context.save()
        } catch {
            // Bug 20 swallowed this with `try?`, which ATE the exact NSError the
            // save/duplication investigation needs — and, worse, a thrown save()
            // here can leave un-flushed pending DELETES in the long-lived mainContext
            // that poison every subsequent save() (the "after Reset, every save
            // fails" report). Log the full error shape (survives into Release via
            // PersistenceLog / Console.app) so the next device repro reveals the
            // domain+code. The count check below stays authoritative: if the rows
            // are actually gone, the reset still reports success (Bug 20).
            logSaveFailure("TransactionResetService.reset", error)
        }

        let remaining = (try? context.fetchCount(FetchDescriptor<Transaction>())) ?? all.count
        return outcome(remaining: remaining)
    }
}
