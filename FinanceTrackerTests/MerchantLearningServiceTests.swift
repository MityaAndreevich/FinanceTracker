import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - In-memory container helper

private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: MerchantCategoryLearning.self,
        configurations: config
    )
    return ModelContext(container)
}

// MARK: - MerchantLearningService tests

@Suite("MerchantLearningService")
struct MerchantLearningServiceTests {

    // MARK: - record: new merchant

    @Test func test_record_newMerchant_createsEntry() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Food & Drink", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "Starbucks", in: ctx)
        #expect(result == "Food & Drink")
    }

    // MARK: - record: existing merchant — upsert

    @Test func test_record_existingMerchant_incrementsCount() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Food & Drink", in: ctx)
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Food & Drink", in: ctx)
        let descriptor = FetchDescriptor<MerchantCategoryLearning>(
            predicate: #Predicate { $0.merchantNormalized == "starbucks" }
        )
        let entry = try ctx.fetch(descriptor).first
        #expect(entry?.useCount == 2)
    }

    @Test func test_record_existingMerchant_overwritesCategory() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Food & Drink", in: ctx)
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "Other", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "Starbucks", in: ctx)
        #expect(result == "Other", "latest pick wins — user correction is highest-signal")
    }

    // MARK: - Normalization

    @Test func test_normalize_caseInsensitive() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "STARBUCKS", categoryName: "Food & Drink", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "starbucks", in: ctx)
        #expect(result == "Food & Drink")
    }

    @Test func test_normalize_diacritics() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "Café", categoryName: "Food & Drink", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "cafe", in: ctx)
        #expect(result == "Food & Drink")
    }

    @Test func test_normalize_whitespace() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "  Starbucks  ", categoryName: "Food & Drink", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "Starbucks", in: ctx)
        #expect(result == "Food & Drink")
    }

    @Test func test_normalize_russian_yo() throws {
        let ctx = try makeContext()
        // "ё" → "е" via diacritic folding
        MerchantLearningService.record(merchant: "Пятёрочка", categoryName: "Food & Drink", in: ctx)
        let result = MerchantLearningService.suggestedCategoryName(for: "пятерочка", in: ctx)
        #expect(result == "Food & Drink")
    }

    // MARK: - Guard conditions

    @Test func test_record_nilMerchant_doesNothing() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: nil, categoryName: "Food & Drink", in: ctx)
        let descriptor = FetchDescriptor<MerchantCategoryLearning>()
        let all = try ctx.fetch(descriptor)
        #expect(all.isEmpty)
    }

    @Test func test_record_blankCategory_doesNothing() throws {
        let ctx = try makeContext()
        MerchantLearningService.record(merchant: "Starbucks", categoryName: "   ", in: ctx)
        let descriptor = FetchDescriptor<MerchantCategoryLearning>()
        let all = try ctx.fetch(descriptor)
        #expect(all.isEmpty)
    }

    @Test func test_suggest_unknownMerchant_returnsNil() throws {
        let ctx = try makeContext()
        let result = MerchantLearningService.suggestedCategoryName(for: "NeverSeenBefore", in: ctx)
        #expect(result == nil)
    }
}
