//
//  TransactionSplit.swift
//  FinanceTracker
//
//  One category-attributed piece of one purchase (1.0.3 Item 4): the Amazon
//  order stays ONE Transaction in the ledger, with child splits carrying
//  amount + category. The parent's amount/date/direction stay authoritative —
//  a split holds only its portion.
//
//  Invariant (remainder model, design doc §2.2): the editor enforces
//  Σ splits ≤ parent total; the unassigned remainder implicitly belongs to the
//  parent's own category. Exact-sum is deliberately NOT required — child
//  records sync independently once iCloud ships, so partial arrival must
//  degrade gracefully, and `CategoryAttribution` is the single place that
//  interprets the decomposition.
//
//  CloudKit-shaped: all attributes defaulted, both relationships optional,
//  inverses declared exactly once per pair (cascade on Transaction.splits,
//  nullify on Category.splits).
//

import Foundation
import SwiftData

@Model
final class TransactionSplit {

    /// Stable external id (export/import, sync debugging). Not `.unique` —
    /// CloudKit forbids it.
    var uuid: UUID = UUID()

    /// This split's portion of the parent's amountCents. > 0 by editor
    /// validation; aggregation defensively ignores non-positive values.
    var amountCents: Int = 0

    /// Optional label ("book", "HDMI cable"). Purely descriptive.
    var note: String?

    /// Stable display order within the purchase.
    var order: Int = 0

    /// nil = orphan (parent deleted mid-flight, or — once sync ships — the
    /// parent record hasn't arrived yet). Orphans are invisible to aggregation:
    /// attribution derives from the parent, never from a bare split fetch.
    var parent: Transaction?

    /// nil = the split's category was deleted (or hasn't synced). Attribution
    /// falls back to the parent's own category — money never vanishes.
    var category: Category?

    var createdAt: Date = Date()

    init(
        uuid: UUID = UUID(),
        amountCents: Int,
        category: Category?,
        note: String? = nil,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.amountCents = amountCents
        self.category = category
        self.note = note
        self.order = order
        self.createdAt = createdAt
    }
}
