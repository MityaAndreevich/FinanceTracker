import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

// MARK: - Bug 20: Reset shows error but actually wipes the data
//
// Device test #7: Settings → Reset transactions deleted everything (factually)
// yet the alert reported "несколько ошибок проверки". The handler treated a
// thrown save() as authoritative failure; SwiftData's non-fatal bulk-delete
// validation noise produced a false-negative error. The fix makes the
// post-delete COUNT authoritative.

@Suite("TransactionResetService (Bug 20)")
@MainActor
struct TransactionResetServiceTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self, MerchantCategoryLearning.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @discardableResult
    private func seedTransactions(_ n: Int, in ctx: ModelContext) -> FinanceTracker.Category {
        let cat = FinanceTracker.Category(name: "Other", kindRaw: "expense", order: 0)
        ctx.insert(cat)
        for i in 0..<n {
            ctx.insert(Transaction(
                typeRaw: "expense", amountCents: (i + 1) * 100, currency: "USD",
                date: Date(), category: cat
            ))
        }
        try? ctx.save()
        return cat
    }

    @Test func testResetTransactions_success_doesNotShowError() throws {
        let ctx = try makeContext()
        seedTransactions(5, in: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 5)

        let outcome = TransactionResetService.reset(in: ctx)

        #expect(outcome == .success, "a reset that empties the store must report success, not an error")
        #expect(try ctx.fetchCount(FetchDescriptor<Transaction>()) == 0, "every transaction must be gone")
    }

    @Test func testResetTransactions_emptyStore_success() throws {
        let ctx = try makeContext()
        // Nothing to delete — still a clean success, never an error alert.
        let outcome = TransactionResetService.reset(in: ctx)
        #expect(outcome == .success)
    }

    @Test func testResetTransactions_actualFailure_showsSpecificError() throws {
        // The crux of Bug 20: the outcome is decided by the remaining count, not by
        // whether save() threw. Zero remaining → success (no false error); any row
        // that genuinely survives the delete → failure with that count.
        #expect(TransactionResetService.outcome(remaining: 0) == .success)
        #expect(TransactionResetService.outcome(remaining: 3) == .failure(remaining: 3),
                "rows that actually survive a reset are the only thing that surfaces an error")
    }
}
