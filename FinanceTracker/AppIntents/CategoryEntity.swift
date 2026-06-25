//
//  CategoryEntity.swift
//  FinanceTracker
//
//  AppEntity wrapping the SwiftData Category model so Siri and Shortcuts can
//  present a disambiguation picker ("Food & Drink or Transport?") and so
//  AddTransactionIntent can carry a typed category parameter.
//

import AppIntents
import SwiftData

struct CategoryEntity: AppEntity {
    let id: UUID
    let name: String
    let isPrimary: Bool

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = CategoryQuery()
}

extension CategoryEntity {
    init(from category: Category) {
        self.id = category.uuid
        self.name = category.displayName()
        self.isPrimary = category.isPrimary
    }
}

// MARK: - Query

struct CategoryQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            let all = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
            return identifiers.compactMap { id in
                all.first { $0.uuid == id }.map { CategoryEntity(from: $0) }
            }
        }
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            return Self.sortedEntities(from: ctx)
        }
    }

    func defaultResult() async -> CategoryEntity? {
        await MainActor.run {
            let ctx = SharedModelContainer.shared.mainContext
            let all = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
            return all.first { $0.isPrimary }.map { CategoryEntity(from: $0) }
        }
    }

    // MARK: - Testable helper

    /// Fetches and sorts categories: primary first, then by order. Extracted so tests
    /// can call this with an in-memory context without going through SharedModelContainer.
    static func sortedEntities(from context: ModelContext) -> [CategoryEntity] {
        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        return all
            .sorted {
                if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
                return $0.order < $1.order
            }
            .map { CategoryEntity(from: $0) }
    }
}
