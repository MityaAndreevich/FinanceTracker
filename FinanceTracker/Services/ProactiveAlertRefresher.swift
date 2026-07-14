//
//  ProactiveAlertRefresher.swift
//  FinanceTracker
//
//  Recomputes the single pending alert. This is the join between the pure policy and the
//  live ledger, and it is the answer to the staleness problem: a local notification's
//  body is frozen when scheduled, so an amount in it can be wrong by the time it fires.
//
//  Safe-to-spend is `budget − spend(this month)`. It changes ONLY when a transaction is
//  written, when the budget changes, or when the month rolls over — the passage of time
//  alone never changes it. So if we recompute after every write, a number computed on
//  Monday is still literally true on Friday: had it stopped being true, a write would
//  have happened and we would have rescheduled.
//

import Foundation
import SwiftData

@MainActor
enum ProactiveAlertRefresher {

    static func refresh(modelContext: ModelContext) {
        let defaults = UserDefaults.standard

        // Re-checked on every pass rather than trusting the toggle, so an expired trial
        // cannot leave a premium notification in flight.
        guard AccessManager.shared.isAllowed(.proactiveAlerts) else {
            ProactiveAlertScheduler.cancel()
            return
        }

        let settings = AlertSettings(
            isEnabled: defaults.bool(forKey: "alertsEnabled"),
            weekday: defaults.object(forKey: "alertWeekday") as? Int ?? 6,
            hour: defaults.object(forKey: "alertHour") as? Int ?? 18,
            minute: defaults.object(forKey: "alertMinute") as? Int ?? 0
        )

        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let budget = defaults.integer(forKey: "monthlyBudgetCents")
        let currency = defaults.string(forKey: "defaultCurrencyCode") ?? "USD"
        let now = Date()

        let agg = SafeToSpend.aggregate(
            entries: SafeToSpend.entries(from: transactions),
            now: now
        )
        let snapshot = SafeToSpend.snapshot(
            monthlyBudgetCents: budget,
            spentThisMonthCents: agg.spentThisMonthCents,
            priorExpenseCents: agg.priorExpenseCents,
            priorSpanDays: agg.priorSpanDays,
            now: now
        )

        let baseline = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: snapshot.monthlyBudgetCents,
            daysInMonth: snapshot.daysInMonth,
            priorExpenseCents: snapshot.priorExpenseCents,
            priorSpanDays: snapshot.priorSpanDays
        )
        let pace = PaceMetric.evaluate(
            spentThisPeriodCents: snapshot.spentCents,
            elapsedDays: snapshot.elapsedDays,
            baselineDailyCents: baseline
        )

        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot,
            pace: pace,
            settings: settings,
            now: now
        )

        ProactiveAlertScheduler.apply(plan: plan, currencyCode: currency)
    }
}
