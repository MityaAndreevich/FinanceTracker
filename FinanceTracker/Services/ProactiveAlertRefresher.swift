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
import UserNotifications

/// Coalesces a burst of refresh triggers into one off-main aggregation pass.
///
/// An INSTANCE type, not statics, deliberately: the unit-test host is the real
/// app, whose live didSave observer drives the app's own scheduler — statics
/// would let the host's refreshes clobber a test's pending pass (and did,
/// before this shape). The app uses `.shared`; tests create their own.
///
/// MEASURED (MainThreadHotPathMeasurementTests): the synchronous form of this
/// work costs ~1.0-1.2s PER CALL on the main actor at 12k rows — which, wired
/// to every didSave (twice per QuickAdd: transaction save + merchant-learning
/// save), was the founder's multi-second freeze ("Edit opens nothing, then
/// recovers"). Here a burst coalesces to ONE pass, the full-table read runs on
/// the ModelActor's executor, and only three Ints come back to the main actor
/// for the plan/schedule step.
@MainActor
final class ProactiveAlertRefreshScheduler {

    static let shared = ProactiveAlertRefreshScheduler()

    /// How long a burst is allowed to coalesce. The scheduled alert genuinely
    /// does not care about sub-second freshness; short enough that the pending
    /// notification is re-planned long before any alert could plausibly fire.
    ///
    /// `nonisolated` because it is read as a default-argument expression (on
    /// `schedule(coalesceWindow:)`), which is evaluated in a nonisolated context.
    /// Safe: an immutable `let` of a `Sendable` value type has no shared mutable
    /// state to race on — hence plain `nonisolated`, never `nonisolated(unsafe)`.
    nonisolated static let defaultCoalesceWindow: Duration = .seconds(2)

    private var aggregator: LedgerAggregator?
    private var pending: Task<Void, Never>?

    /// What the app calls on every `ModelContext.didSave` and on foreground.
    func schedule(
        container: ModelContainer = SharedModelContainer.shared,
        coalesceWindow: Duration = defaultCoalesceWindow,
        defaults: UserDefaults = .standard,
        center: NotificationScheduling = UNUserNotificationCenter.current(),
        isAllowed: (@MainActor () -> Bool)? = nil
    ) {
        pending?.cancel()
        // `[weak self]`: `pending` holds this task and the task would otherwise
        // hold `self`, so an instance dropped mid-window (tests create their own;
        // the app's is the singleton) would outlive its owner for the whole
        // coalescing window plus a full-table aggregation. Weak keeps the
        // instance's lifetime the caller's business, not the timer's.
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(for: coalesceWindow)
            guard !Task.isCancelled, let self else { return }

            if self.aggregator == nil {
                self.aggregator = LedgerAggregator(modelContainer: container)
            }
            guard let aggregator = self.aggregator else { return }

            let now = Date()
            // nil = the ledger cannot be summed. Schedule nothing; see
            // SafeToSpend.aggregate. This is the path that runs on every .active
            // transition, so before the guard existed it crashed the app at launch.
            guard let aggregate = await aggregator.safeToSpendAggregate(now: now) else { return }
            guard !Task.isCancelled else { return }

            ProactiveAlertRefresher.apply(
                aggregate: aggregate,
                isAllowed: isAllowed?() ?? AccessManager.shared.isAllowed(.proactiveAlerts),
                defaults: defaults,
                now: now,
                center: center
            )
        }
    }

    /// Await the in-flight coalesced pass, if any (tests).
    func drain() async {
        await pending?.value
    }

    deinit {
        // The weak capture above already lets this object die mid-window; this
        // stops the orphaned task from sleeping out the rest of its window for
        // an owner that no longer exists.
        pending?.cancel()
    }
}

@MainActor
enum ProactiveAlertRefresher {

    // MARK: - Synchronous form (tests, and the guts of the async path)

    /// Reads the live entitlement, then hands off to the testable form below.
    ///
    /// (The entitlement cannot be a *default argument* on that function: default-argument
    /// expressions are evaluated in a nonisolated context, and `AccessManager` is
    /// main-actor isolated.)
    static func refresh(modelContext: ModelContext) {
        refresh(
            modelContext: modelContext,
            isAllowed: AccessManager.shared.isAllowed(.proactiveAlerts)
        )
    }

    /// The dependencies are injectable because this function is the *join* — the one place
    /// where a wiring slip (feeding the policy the wrong field) would produce a
    /// confidently-wrong number in a notification. The pure pieces either side of it are
    /// already well covered; this is what makes the seam between them testable too.
    static func refresh(
        modelContext: ModelContext,
        isAllowed: Bool,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        // Synchronous full-table fetch — this form exists for TESTS (a
        // deterministic, awaitable-free join) and must never be wired to a hot
        // path again: at 12k rows it costs ~1s on whatever thread runs it. The
        // app goes through `scheduleRefresh`, which does this read on the
        // LedgerAggregator's executor. Shares SafeToSpend.makeAggregate with
        // the actor so the two paths cannot drift.
        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let limited = ((try? modelContext.fetch(FetchDescriptor<Category>())) ?? [])
            .compactMap { category -> (uuid: UUID, displayName: String, limitCents: Int)? in
                guard let limit = category.limitCents, limit > 0 else { return nil }
                return (category.uuid, category.displayName(), limit)
            }
        // Overflowing ledger → schedule NOTHING. An alert derived from a total we
        // could not compute would be worse than silence, and there is no screen or
        // string to add here: the correct behaviour is absence.
        guard let aggregate = SafeToSpend.makeAggregate(
            transactions: transactions, limitedCategories: limited, now: now
        ) else { return }
        apply(
            aggregate: aggregate,
            isAllowed: isAllowed,
            defaults: defaults,
            now: now,
            center: center
        )
    }

    /// The join between the (already computed) aggregate and the notification
    /// plan. Pure main-actor glue: no I/O beyond UserDefaults, no fetch.
    static func apply(
        aggregate: SafeToSpend.Aggregate,
        isAllowed: Bool,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        // Re-checked on every pass rather than trusting the toggle, so an expired trial
        // cannot leave a premium notification in flight.
        guard isAllowed else {
            ProactiveAlertScheduler.cancel(center: center)
            return
        }

        let settings = AlertSettings(
            isEnabled: defaults.bool(forKey: "alertsEnabled"),
            weekday: defaults.object(forKey: "alertWeekday") as? Int ?? 6,
            hour: defaults.object(forKey: "alertHour") as? Int ?? 18,
            minute: defaults.object(forKey: "alertMinute") as? Int ?? 0
        )

        let budget = defaults.integer(forKey: "monthlyBudgetCents")
        let currency = defaults.string(forKey: "defaultCurrencyCode") ?? "USD"

        let snapshot = SafeToSpend.snapshot(
            monthlyBudgetCents: budget,
            spentThisMonthCents: aggregate.spentThisMonthCents,
            priorExpenseCents: aggregate.priorExpenseCents,
            priorSpanDays: aggregate.priorSpanDays,
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

        // Category-limit latch maintenance (design §6.4): a previously PLANNED
        // limit warning whose fire date has passed has been delivered — latch
        // that category for the fire date's month so it warns once per month.
        // Latching at plan time would burn the latch on every re-plan; this is
        // the same frozen-body re-plan machinery, one extra comparison.
        if let plannedUUIDString = defaults.string(forKey: plannedLimitCategoryKey),
           let plannedFireDate = defaults.object(forKey: plannedLimitFireDateKey) as? Date,
           let plannedUUID = UUID(uuidString: plannedUUIDString),
           now >= plannedFireDate {
            defaults.set(true, forKey: CategoryLimitPolicy.latchKey(
                categoryUUID: plannedUUID, month: plannedFireDate))
            defaults.removeObject(forKey: plannedLimitCategoryKey)
            defaults.removeObject(forKey: plannedLimitFireDateKey)
        }

        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot,
            pace: pace,
            limitStatuses: aggregate.limitStatuses,
            isLatched: { uuid in
                defaults.bool(forKey: CategoryLimitPolicy.latchKey(categoryUUID: uuid, month: now))
            },
            settings: settings,
            now: now
        )

        // Record (or clear) the planned limit warning for the latch above.
        if case .categoryLimit(let uuid, _, _)? = plan?.body {
            defaults.set(uuid.uuidString, forKey: plannedLimitCategoryKey)
            defaults.set(plan?.fireDate, forKey: plannedLimitFireDateKey)
        } else {
            defaults.removeObject(forKey: plannedLimitCategoryKey)
            defaults.removeObject(forKey: plannedLimitFireDateKey)
        }

        ProactiveAlertScheduler.apply(plan: plan, currencyCode: currency, center: center)
    }

    /// Defaults keys for the pending category-limit warning (latch mechanics).
    static let plannedLimitCategoryKey = "limitWarnPlannedCategory"
    static let plannedLimitFireDateKey = "limitWarnPlannedFireDate"
}
