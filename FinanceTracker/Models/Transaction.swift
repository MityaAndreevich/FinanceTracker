//
//  Transaction.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//
//  V2 (1.0.3): CloudKit-shaped — every attribute defaulted, every relationship
//  optional with an explicit inverse, no `.unique` (design doc §1.2). iCloud
//  sync itself stays OFF until 1.0.4; this release ships the sync-compatible
//  schema so the flip is a config change, not a migration.
//

import Foundation
import SwiftData

@Model
final class Transaction {

    /// Stable external identifier (not the SwiftData PersistentIdentifier).
    /// Used for UI selection, exports, imports, and future cloud sync.
    ///
    /// V2: no longer `@Attribute(.unique)` — CloudKit forbids it. Uniqueness is
    /// enforced at the write sites instead (the importer fetches-by-uuid before
    /// insert; SeedService is idempotent by nameKey).
    var uuid: UUID = UUID()

    /// Stored as raw string for SwiftData stability. Use `.type` for safe access.
    var typeRaw: String = "expense"

    var amountCents: Int = 0      // Money stored as Int cents — avoids float drift
    var currency: String = "USD"
    var date: Date = Date()
    var taxCents: Int?
    var note: String?
    var merchant: String?

    /// nil = one-time transaction. Otherwise "weekly" | "monthly" | "yearly".
    var recurrenceRaw: String?

    /// True for transactions seeded by DemoDataController (opt-in sample data).
    /// Allows atomic removal without touching user data.
    var isDemo: Bool = false

    /// Set by the importer on a FOREIGN row (a CSV with no stable `id` column)
    /// whose content matches a transaction already in the store. Such a row is
    /// imported anyway — we cannot tell a re-import apart from two genuinely
    /// identical real spends, and silently dropping a real transaction is the
    /// worse failure. The flag is what lets the user find and resolve it later:
    /// it drives the row badge and the review flow (DuplicateReviewService).
    ///
    /// Rows carrying our own export's UUID are never flagged — an exact UUID
    /// match is skipped outright, which is why an own-export re-import stays
    /// idempotent.
    var isPossibleDuplicate: Bool = false

    // Relationships — inverse macros live on the far side (Category.transactions,
    // Source.transactions); SwiftData wants `@Relationship(inverse:)` declared on
    // exactly one side of each pair.

    /// OPTIONAL as of V2 (CloudKit rule, and a sync reality: with iCloud on, a
    /// Transaction record can land on a second device before its Category
    /// record). nil renders as "Uncategorized" via the Optional<Category>
    /// fallback helpers — never force-unwrap this.
    var category: Category?

    /// Deleting a Source now genuinely nullifies this: the explicit inverse on
    /// Source.transactions gives the store the back-reference it needs to
    /// enforce `.nullify` at delete time (the pre-V2 dangling-reference crash).
    var source: Source?

    /// Child splits of this purchase ("one Amazon order, three categories").
    /// Cascade: a split cannot outlive its purchase. Optional array per the
    /// CloudKit shape; nil and empty are equivalent (use
    /// `CategoryAttribution.orderedSplits`).
    @Relationship(deleteRule: .cascade, inverse: \TransactionSplit.parent)
    var splits: [TransactionSplit]?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        uuid: UUID = UUID(),
        typeRaw: String,
        amountCents: Int,
        currency: String = "USD",
        date: Date,
        category: Category?,
        source: Source? = nil,
        taxCents: Int? = nil,
        note: String? = nil,
        merchant: String? = nil,
        recurrenceRaw: String? = nil,
        isDemo: Bool = false,
        isPossibleDuplicate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.uuid = uuid
        self.typeRaw = typeRaw
        self.amountCents = amountCents
        self.currency = currency
        self.date = date
        self.category = category
        self.source = source
        self.taxCents = taxCents
        self.note = note
        self.merchant = merchant
        self.recurrenceRaw = recurrenceRaw
        self.isDemo = isDemo
        self.isPossibleDuplicate = isPossibleDuplicate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Typed accessors

extension Transaction {

    /// Strongly-typed view over `typeRaw`. Always prefer this in new code.
    var type: TransactionType {
        get { TransactionType.from(typeRaw) }
        set { typeRaw = newValue.raw }
    }

    var isIncome: Bool { type == .income }
    var isExpense: Bool { type == .expense }

    /// Strongly-typed view over `recurrenceRaw`. nil == one-time.
    var recurrence: RecurrenceType? {
        get { RecurrenceType.from(recurrenceRaw) }
        set { recurrenceRaw = newValue?.raw }
    }

    var isRecurring: Bool { recurrence != nil }

    /// Signed amount in cents. Income is positive, expense is negative.
    var signedAmountCents: Int {
        isIncome ? amountCents : -amountCents
    }
}
