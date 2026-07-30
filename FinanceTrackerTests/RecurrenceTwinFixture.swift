//
//  RecurrenceTwinFixture.swift
//  FinanceTrackerTests
//
//  Builds the post-union store shape that iCloud sync introduces and that no
//  test could express before: TWO Transaction rows carrying the SAME `uuid`.
//
//  Why this is now possible — and therefore now testable: V2 dropped
//  `@Attribute(.unique)` from `Transaction.uuid` because CloudKit forbids it
//  (Transaction.swift:22). Twins arise in exactly one shape, the
//  "existing + existing" first sync where two already-populated devices union
//  (AUDIT_UUID_UNIQUENESS_SYNC_1_0_4 §0). Replication alone never mints one.
//
//  The fixture deliberately lets the two twins DIVERGE (amount, merchant,
//  updatedAt), because the interesting failures are not "there are two rows"
//  but "the two rows disagree and each device silently picks a different one".
//

import Foundation
import SwiftData
@testable import FinanceTracker

enum RecurrenceTwinFixture {

    /// One recurring series as it exists after a union: two rows, one uuid.
    struct Twins {
        let uuid: UUID
        let older: Transaction      // earlier `updatedAt`
        let newer: Transaction      // later `updatedAt`
    }

    /// Holds the container for the caller's lifetime — returning only the
    /// context yields a message-less EXC_BREAKPOINT once the container drops.
    static func makeStore() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
            TransactionSplit.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    /// A single recurring template — the one-device baseline.
    @discardableResult
    static func insertTemplate(
        in ctx: ModelContext,
        uuid: UUID = UUID(),
        recurrence: RecurrenceType = .monthly,
        anchor: Date,
        amountCents: Int = 5200,
        merchant: String? = "Netflix",
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> Transaction {
        let tx = Transaction(
            typeRaw: "expense",
            amountCents: amountCents,
            currency: "USD",
            date: anchor,
            category: nil,
            merchant: merchant,
            recurrenceRaw: recurrence.rawValue,
            createdAt: createdAt ?? anchor,
            updatedAt: updatedAt ?? anchor
        )
        tx.uuid = uuid
        ctx.insert(tx)
        return tx
    }

    /// Two rows sharing one `uuid`, both flagged recurring — one series as far
    /// as the user is concerned, two rows as far as `dueRecurring` is concerned.
    ///
    /// - Parameter insertNewerFirst: inserts the twins in the opposite order.
    ///   A fetch's row order is not a promise, and two devices have no reason to
    ///   agree on it; flipping this is how a test proves a rule does not secretly
    ///   depend on `.first`.
    static func insertTwins(
        in ctx: ModelContext,
        uuid: UUID = UUID(),
        recurrence: RecurrenceType = .monthly,
        anchor: Date,
        olderAmountCents: Int = 5200,
        newerAmountCents: Int = 5200,
        olderMerchant: String? = "Netflix",
        newerMerchant: String? = "Netflix",
        editGap: TimeInterval = 3600,
        insertNewerFirst: Bool = false
    ) -> Twins {
        func makeOlder() -> Transaction {
            insertTemplate(
                in: ctx, uuid: uuid, recurrence: recurrence, anchor: anchor,
                amountCents: olderAmountCents, merchant: olderMerchant,
                createdAt: anchor, updatedAt: anchor
            )
        }
        func makeNewer() -> Transaction {
            insertTemplate(
                in: ctx, uuid: uuid, recurrence: recurrence, anchor: anchor,
                amountCents: newerAmountCents, merchant: newerMerchant,
                createdAt: anchor, updatedAt: anchor.addingTimeInterval(editGap)
            )
        }

        let older: Transaction
        let newer: Transaction
        if insertNewerFirst {
            newer = makeNewer()
            older = makeOlder()
        } else {
            older = makeOlder()
            newer = makeNewer()
        }
        try? ctx.save()
        return Twins(uuid: uuid, older: older, newer: newer)
    }
}
