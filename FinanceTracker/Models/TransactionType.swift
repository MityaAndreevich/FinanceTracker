//
//  TransactionType.swift
//  FinanceTracker
//
//  Strongly-typed wrapper around Transaction.typeRaw to prevent
//  stringly-typed bugs like "Income" vs "income".
//

import Foundation

enum TransactionType: String, CaseIterable, Identifiable, Sendable {
    case income
    case expense

    var id: String { rawValue }

    /// The raw storage value used in SwiftData (`typeRaw`).
    var raw: String { rawValue }

    static func from(_ raw: String) -> TransactionType {
        TransactionType(rawValue: raw.lowercased()) ?? .expense
    }
}
