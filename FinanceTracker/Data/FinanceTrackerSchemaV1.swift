//
//  FinanceTrackerSchemaV1.swift
//  FinanceTracker
//
//  The 1.0.0–1.0.2 store shapes, FROZEN. These replicas exist so SwiftData can
//  identify a pre-1.0.3 store (entity version hashes must match what shipped)
//  and run the V1→V2 custom migration stage against it. They are also what the
//  pre-migration export screen opens the store with, read-only — a V1-schema
//  open can never trigger a migration because it matches the disk exactly.
//
//  ⚠️ NEVER EDIT THE SHAPES IN THIS FILE. Any change breaks store-version
//  identification for every user still on 1.0.2. Evolution happens by adding
//  a V3, never by touching V1.
//
//  Design doc: outputs/DESIGN_1_0_3_MODELS_FABLE.md §1, §7.
//

import Foundation
import SwiftData

enum FinanceTrackerSchemaV1: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self]
    }

    // MARK: - Transaction (as shipped in 1.0.2)

    @Model
    final class Transaction {
        @Attribute(.unique) var uuid: UUID
        var typeRaw: String
        var amountCents: Int
        var currency: String
        var date: Date
        var taxCents: Int?
        var note: String?
        var merchant: String?
        var recurrenceRaw: String?
        var isDemo: Bool = false
        var isPossibleDuplicate: Bool = false

        // Shipped WITHOUT an inverse — which is why `.nullify` was unenforced
        // and dangling references could survive on disk (the V2 repair's job).
        @Relationship(deleteRule: .nullify) var category: Category
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

    // MARK: - Category (as shipped in 1.0.2)

    @Model
    final class Category {
        @Attribute(.unique) var uuid: UUID
        var name: String
        var nameKey: String?
        var nameCustom: String?
        var kindRaw: String
        var icon: String?
        var order: Int
        var isPrimary: Bool = true

        init(
            uuid: UUID = UUID(),
            name: String,
            kindRaw: String,
            icon: String? = nil,
            order: Int = 0,
            nameKey: String? = nil,
            nameCustom: String? = nil,
            isPrimary: Bool = true
        ) {
            self.uuid = uuid
            self.name = name
            self.kindRaw = kindRaw
            self.icon = icon
            self.order = order
            self.nameKey = nameKey
            self.nameCustom = nameCustom
            self.isPrimary = isPrimary
        }
    }

    // MARK: - Source (as shipped in 1.0.2)

    @Model
    final class Source {
        @Attribute(.unique) var uuid: UUID
        var name: String
        var note: String?
        var isActive: Bool

        init(
            uuid: UUID = UUID(),
            name: String,
            note: String? = nil,
            isActive: Bool = true
        ) {
            self.uuid = uuid
            self.name = name
            self.note = note
            self.isActive = isActive
        }
    }

    // MARK: - MerchantCategoryLearning (as shipped in 1.0.2)

    @Model
    final class MerchantCategoryLearning {
        @Attribute(.unique) var merchantNormalized: String
        var categoryName: String
        var useCount: Int
        var lastUsedAt: Date

        init(merchantNormalized: String, categoryName: String, useCount: Int = 1, lastUsedAt: Date = .now) {
            self.merchantNormalized = merchantNormalized
            self.categoryName = categoryName
            self.useCount = useCount
            self.lastUsedAt = lastUsedAt
        }
    }
}
