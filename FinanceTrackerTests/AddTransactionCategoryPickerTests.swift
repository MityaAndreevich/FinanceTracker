//
//  AddTransactionCategoryPickerTests.swift
//  FinanceTrackerTests
//
//  Item 2 (Quick Entry UX polish): the detailed form's category control now opens the
//  shared full-list bottom sheet (CategoryPickerSheet) instead of a primary-only Picker
//  with a separate "Show all" step. These pin the two guarantees that survive the UI
//  swap: the picker surfaces the COMPLETE kind-set (including user-created categories) in
//  one step, and the form still auto-defaults an empty selection to "Other".
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
        configurations: config
    )
    return ModelContext(container)
}

@discardableResult
private func makeCategory(
    name: String, kindRaw: String, order: Int, isPrimary: Bool = true,
    nameKey: String? = nil, in ctx: ModelContext
) -> FinanceTracker.Category {
    let cat = FinanceTracker.Category(name: name, kindRaw: kindRaw, order: order)
    cat.isPrimary = isPrimary
    cat.nameKey = nameKey
    ctx.insert(cat)
    return cat
}

@Suite("AddTransaction category picker")
@MainActor
struct AddTransactionCategoryPickerTests {

    // MARK: - CategoryPickerSheet surfaces the full kind-set in one step

    @Test func test_visibleCategories_returnsCompleteKindSet_includingSecondaryAndUserCreated() throws {
        let ctx = try makeContext()
        makeCategory(name: "Food & Drink", kindRaw: "expense", order: 0, isPrimary: true, in: ctx)
        makeCategory(name: "Transport", kindRaw: "expense", order: 1, isPrimary: true, in: ctx)
        // Secondary (previously hidden behind "Show all")
        makeCategory(name: "Pets", kindRaw: "expense", order: 2, isPrimary: false, in: ctx)
        // A user-created category
        makeCategory(name: "Miniatures Hobby", kindRaw: "expense", order: 3, isPrimary: false, in: ctx)
        // A different-kind category that must NOT leak in
        makeCategory(name: "Salary", kindRaw: "income", order: 0, isPrimary: true, in: ctx)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        let visible = CategoryPickerSheet.visibleCategories(all, kind: "expense", search: "")
        let names = Set(visible.map { $0.name })

        // Complete expense set — primary AND secondary AND user-created — in one step.
        #expect(names == ["Food & Drink", "Transport", "Pets", "Miniatures Hobby"])
        // No cross-direction leakage.
        #expect(!names.contains("Salary"))
    }

    @Test func test_visibleCategories_searchNarrowsButStillWithinKind() throws {
        let ctx = try makeContext()
        makeCategory(name: "Food & Drink", kindRaw: "expense", order: 0, in: ctx)
        makeCategory(name: "Transport", kindRaw: "expense", order: 1, in: ctx)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        let hits = CategoryPickerSheet.visibleCategories(all, kind: "expense", search: "trans")
        #expect(hits.map { $0.name } == ["Transport"])
    }

    // MARK: - Empty selection auto-defaults to "Other"

    @Test func test_defaultCategory_prefersOther_overFirstOrdered() throws {
        let ctx = try makeContext()
        // "Alpha" is ordered first, but "Other" (nameKey) must win as the safe default.
        makeCategory(name: "Alpha", kindRaw: "expense", order: 0, in: ctx)
        makeCategory(name: "Other", kindRaw: "expense", order: 5, nameKey: "category.other", in: ctx)
        try ctx.save()

        let subset = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
            .filter { $0.kindRaw == "expense" }
        let result = AddTransactionView.defaultCategory(from: subset)
        #expect(result.category?.nameKey == "category.other")
        #expect(result.isOther == true)
    }

    @Test func test_defaultCategory_fallsBackToFirst_whenNoOther() throws {
        let ctx = try makeContext()
        makeCategory(name: "Alpha", kindRaw: "expense", order: 0, in: ctx)
        makeCategory(name: "Beta", kindRaw: "expense", order: 1, in: ctx)
        try ctx.save()

        let subset = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
            .filter { $0.kindRaw == "expense" }
            .sorted { $0.order < $1.order }
        let result = AddTransactionView.defaultCategory(from: subset)
        #expect(result.category?.name == "Alpha")
        #expect(result.isOther == false)
    }
}
