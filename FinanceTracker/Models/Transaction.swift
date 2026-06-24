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

    // Relationships
    // .deny: if you try to delete a Category that still has transactions, SwiftData throws.
    // CategoriesSourcesView already blocks deletion UX-side; this is a safety net.
    @Relationship(deleteRule: .deny) var category: Category

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

    /// Signed amount in cents. Income is positive, expense is negative.
    var signedAmountCents: Int {
        isIncome ? amountCents : -amountCents
    }
}
