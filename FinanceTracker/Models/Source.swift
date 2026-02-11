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

    /// ✅ Стабильный внешний идентификатор
    var uuid: UUID

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
