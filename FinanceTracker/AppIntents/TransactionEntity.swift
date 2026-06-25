//
//  TransactionEntity.swift
//  FinanceTracker
//
//  Returned by AddTransactionIntent so Siri shows a confirmation card
//  with the saved amount, category, and merchant.
//

import AppIntents
import SwiftData

struct TransactionEntity: AppEntity {
    let id: UUID
    let amountCents: Int
    let currency: String
    let typeRaw: String
    let categoryName: String
    let merchant: String?
    let occurredAt: Date

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Transaction")

    var displayRepresentation: DisplayRepresentation {
        let amount = Money.format(cents: amountCents, currencyCode: currency)
        return DisplayRepresentation(
            title: "\(amount) — \(categoryName)",
            subtitle: merchant.map { "\($0)" } ?? "",
            image: .init(systemName: "checkmark.circle.fill")
        )
    }

    static var defaultQuery = TransactionEntityQuery()
}

extension TransactionEntity {
    init(from tx: Transaction) {
        self.id = tx.uuid
        self.amountCents = tx.amountCents
        self.currency = tx.currency
        self.typeRaw = tx.typeRaw
        self.categoryName = tx.category.displayName()
        self.merchant = tx.merchant
        self.occurredAt = tx.date
    }
}

// MARK: - Query

struct TransactionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TransactionEntity] {
        await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            let all = (try? ctx.fetch(FetchDescriptor<Transaction>())) ?? []
            return identifiers.compactMap { id in
                all.first { $0.uuid == id }.map { TransactionEntity(from: $0) }
            }
        }
    }
}
