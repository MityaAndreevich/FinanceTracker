//
//  PersistenceLog.swift
//  FinanceTracker
//
//  Always-compiled logging for SwiftData save failures.
//
//  The save catches carry a `#if DEBUG print(...)`, which is compiled OUT of
//  Release/TestFlight — so when a user hits "Couldn't save transaction" (B3) the
//  real NSError is invisible and the bug can't be root-caused off-device. This
//  logger survives into Release: the domain / code / userInfo land in the unified
//  log, capturable in Console.app (filter subsystem "com.dmitrylogachev.budgetcrab",
//  category "Persistence").
//
//  Privacy: SwiftData / CoreData errors describe schema, unique-constraint, and
//  store/file-protection state — not user content — so the fields are logged
//  `.public`. No merchant, amount, note, or category *values* are recorded.
//

import Foundation
import os

let persistenceLog = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "Persistence")

/// Purchase / entitlement failures, on the same always-compiled terms and for the
/// same reason: the environments where StoreKit actually works (TestFlight, App
/// Store) are exactly the ones a `#if DEBUG print` is compiled out of, so the
/// failures that reach real users were the only ones we could never see.
///
/// Privacy: StoreKit errors describe transaction and entitlement state, not the
/// user's payment details, so fields are logged `.public`. Never log a redemption
/// code — it is a bearer credential.
let storeKitLog = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "StoreKit")

/// Logs a SwiftData `save()` failure with the full NSError shape. `context`
/// names the call site (e.g. "AddTransactionView.add") so overlapping failures
/// can be told apart in the log.
func logSaveFailure(_ context: String, _ error: Error) {
    let ns = error as NSError
    persistenceLog.error(
        "save failed [\(context, privacy: .public)] domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) userInfo=\(String(describing: ns.userInfo), privacy: .public)"
    )
}
