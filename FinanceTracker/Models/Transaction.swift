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

    /// ✅ Стабильный внешний идентификатор (не SwiftData PersistentIdentifier)
    var uuid: UUID

    var typeRaw: String           // "income" or "expense"
    var amountCents: Int          // ВАЖНО: храним деньги как Int (центы)
    var currency: String          // "USD"
    var date: Date
    var taxCents: Int?
    var note: String?
    var merchant: String?

    // Relationships
    var category: Category
    var source: Source?

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
