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

/// Logs a SwiftData `save()` failure with the full NSError shape. `context`
/// names the call site (e.g. "AddTransactionView.add") so overlapping failures
/// can be told apart in the log.
func logSaveFailure(_ context: String, _ error: Error) {
    let ns = error as NSError
    persistenceLog.error(
        "save failed [\(context, privacy: .public)] domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) userInfo=\(String(describing: ns.userInfo), privacy: .public)"
    )
}
