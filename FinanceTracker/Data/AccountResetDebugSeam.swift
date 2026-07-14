//
//  AccountResetDebugSeam.swift
//  FinanceTracker
//
//  Gives the account-cap UI test a deterministic starting count.
//
//  The account cap is the only gate whose verdict depends on rows that OUTLIVE the
//  process: `XCUIApplication.launch()` reuses the existing app container, so a test
//  that counts accounts inherits whatever the last run left behind — its own two
//  accounts, or the three that a `--demo-mode` screenshot session seeds. Once the
//  container holds 2+ accounts, the free user is legitimately at the cap and the
//  FIRST add already raises the paywall, so the test fails looking for a field that
//  was never supposed to appear. It could therefore pass at most once per simulator.
//
//  This resets the REAL store and then lets the REAL gate decide. It never fakes,
//  relaxes or bypasses a cap — a test that mocked the thing it is verifying would be
//  worth nothing.
//

#if DEBUG
import Foundation
import SwiftData

enum AccountResetDebugSeam {

    static let argument = "--reset-accounts"

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// Deletes every `Source` so the free-tier account count starts at 0.
    ///
    /// The back-reference is cleared BY HAND first, and that is load-bearing.
    /// `Transaction.source` is declared `.nullify`, but the relationship has no
    /// inverse, so SwiftData has nothing to enforce the rule through: deleting a
    /// Source out from under a Transaction leaves the Transaction pointing at a
    /// tombstone, and the next view to read `tx.source?.name` dies on an
    /// EXC_BREAKPOINT inside SwiftData — a crash that PERSISTS, because the dangling
    /// reference is on disk. The app's own delete path sidesteps this by refusing to
    /// delete an account that still has transactions (`performDeleteSources`); a test
    /// seam cannot refuse, so it detaches first and deletes second.
    @MainActor
    static func resetIfRequested(modelContext: ModelContext) {
        guard isRequested else { return }

        do {
            for transaction in try modelContext.fetch(FetchDescriptor<Transaction>())
            where transaction.source != nil {
                transaction.source = nil
            }

            for source in try modelContext.fetch(FetchDescriptor<Source>()) {
                modelContext.delete(source)
            }

            try modelContext.save()
        } catch {
            print("AccountResetDebugSeam failed: \(error.localizedDescription)")
        }
    }
}
#endif
