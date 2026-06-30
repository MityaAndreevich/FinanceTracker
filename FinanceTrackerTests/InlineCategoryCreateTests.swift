import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Bug 34.5: inline category create in the Add Transaction flow
//
// + screen → amount → "New category: Test" → Save must persist BOTH the new
// category and the transaction, with the transaction filed against that exact
// category. The view-level defect was that the inline-create callback set the
// selection UUID but not `categoryManuallyChosen`, so a debounced merchant
// suggestion could overwrite the freshly created category before the user hit
// Add — saving the transaction under the wrong category. Fixed in
// AddTransactionView (mark it a manual pick + cancel the pending suggestion).
//
// This test pins the model-layer contract the flow relies on: the same
// create-then-resolve-then-save path the views drive yields one category and one
// transaction, correctly linked.

@Suite("Inline category create (Bug 34.5)")
@MainActor
struct InlineCategoryCreateTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func testInlineCategoryCreate_validName_savesBothCategoryAndTransaction() throws {
        let ctx = try makeContext()

        // A pre-existing seed so we can prove the NEW category is distinct and that
        // the transaction does not accidentally fall back to "Other".
        let other = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(other)
        try ctx.save()

        // 1) Inline create: same validated build path AddCategorySheet uses.
        let result = NewCategoryViewModel.makeCategory(
            name: "Test", kindRaw: "expense", icon: nil, order: 1,
            existing: try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        )
        guard case .success(let newCat) = result else {
            Issue.record("inline category create should succeed for a valid, unique name")
            return
        }
        ctx.insert(newCat)
        try ctx.save()

        // 2) Resolve the selection by uuid (as AddTransactionView.selectedCategory does)
        //    from a fresh fetch — the freshly created category must be findable.
        let targetUUID = newCat.uuid
        let resolved = try ctx.fetch(
            FetchDescriptor<FinanceTracker.Category>(predicate: #Predicate { $0.uuid == targetUUID })
        ).first
        #expect(resolved != nil, "the just-created category must be resolvable by uuid for selection")

        // 3) Save a transaction against that resolved category (AddTransactionView.add()).
        let tx = Transaction(
            typeRaw: "expense", amountCents: 1_299, currency: "USD",
            date: Date(), category: try #require(resolved), merchant: "Acme"
        )
        ctx.insert(tx)
        try ctx.save()

        // Both persisted…
        let categories = try ctx.fetch(FetchDescriptor<FinanceTracker.Category>())
        let transactions = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(categories.count == 2, "the new category is saved alongside the existing seed")
        #expect(transactions.count == 1, "exactly one transaction is saved")

        // …and correctly LINKED — filed against the created category, not "Other".
        #expect(transactions.first?.category.uuid == newCat.uuid,
                "the transaction must be filed against the inline-created category")
        #expect(transactions.first?.category.name == "Test")
    }
}
