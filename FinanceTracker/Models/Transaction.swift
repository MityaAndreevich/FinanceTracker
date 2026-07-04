//
//  Transaction.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import Foundation
import SwiftData

@Model
final class Transaction {

    /// Stable external identifier (not the SwiftData PersistentIdentifier).
    /// Used for UI selection, exports, imports, and future cloud sync.
    @Attribute(.unique) var uuid: UUID

    /// Stored as raw string for SwiftData stability. Use `.type` for safe access.
    var typeRaw: String

    var amountCents: Int          // Money stored as Int cents — avoids float drift
    var currency: String
    var date: Date
    var taxCents: Int?
    var note: String?
    var merchant: String?

    /// nil = one-time transaction. Otherwise "weekly" | "monthly" | "yearly".
    /// Optional with no default → SwiftData lightweight migration handles existing stores.
    var recurrenceRaw: String?

    /// True for transactions seeded by DemoDataController (opt-in sample data).
    /// Allows atomic removal without touching user data.
    var isDemo: Bool = false

    // Relationships
    // .nullify (SwiftData default): deleting a Transaction simply detaches it from its
    // Category. It must NOT be `.deny`: a delete rule governs deletion of the object
    // that OWNS the relationship (the Transaction), so `.deny` here denied deleting ANY
    // transaction whose `category` was set — and since `category` is non-optional, that
    // was every transaction. That surfaced on device as NSCocoaError 1600
    // (NSValidationRelationshipDeniedDeleteError) on "Reset transactions", whose
    // un-committable pending deletes then poisoned every later save. Protecting a
    // Category that still has transactions is a UX concern handled in CategoriesSourcesView
    // (there is no inverse relationship here for a delete rule to enforce anyway).
    @Relationship(deleteRule: .nullify) var category: Category

    // .nullify: deleting a Source clears the back-reference on transactions.
    @Relationship(deleteRule: .nullify) var source: Source?

    var createdAt: Date
    var updatedAt: Date

    init(
        uuid: UUID = UUID(),
        typeRaw: String,
        amountCents: Int,
        currency: String = "USD",
        date: Date,
        category: Category,
        source: Source? = nil,
        taxCents: Int? = nil,
        note: String? = nil,
        merchant: String? = nil,
        recurrenceRaw: String? = nil,
        isDemo: Bool = false,
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
