//
//  Category.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var kindRaw: String
    var icon: String?
    var order: Int

    init(
        id: UUID = UUID(),
        name: String,
        kindRaw: String,
        icon: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kindRaw
        self.icon = icon
        self.order = order
    }
}
