//
//  Source.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import Foundation
import SwiftData

@Model
final class Source {

    /// Stable external identifier (used for UI selection, export/import, future cloud sync).
    /// V2: no longer `@Attribute(.unique)` — CloudKit forbids it.
    var uuid: UUID = UUID()

    var name: String = ""
    var note: String?
    var isActive: Bool = true

    /// Explicit inverse of Transaction.source (V2). This line is the actual
    /// fix for the dangling-Source crash: with an inverse, `.nullify` is
    /// enforced by the store at delete time instead of depending on UI
    /// discipline to detach transactions first.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.source)
    var transactions: [Transaction]?

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
