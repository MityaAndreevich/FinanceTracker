//
//  RecurrenceService.swift
//  FinanceTracker
//
//  Drives recurring transactions. A recurring transaction is a normal saved
//  Transaction whose `recurrenceRaw` is set — it counts as the FIRST occurrence.
//  Each subsequent period we surface a prompt offering to log that period's
//  charge; confirming creates a concrete (non-recurring) instance.
//
//  Period bookkeeping lives in UserDefaults (one key per template uuid) so the
//  only schema change is the single optional `recurrenceRaw` attribute.
//

import Foundation
import SwiftData
import UserNotifications

/// A due recurring charge awaiting the user's decision.
struct RecurrencePrompt: Identifiable {
    /// The series identity. Still the template's `uuid` because that is what
    /// keys the period watermark and the notification id — NOT because it
    /// resolves a row. It no longer does: `uuid` lost `@Attribute(.unique)` in
    /// V2 (CloudKit forbids it), so a first-sync union can give one series two
    /// rows carrying this same value.
    let id: UUID

    /// Which row this prompt was built from. Resolution goes through this, so
    /// that the row the user approves is the row that gets posted even if the
    /// store changes underneath between the prompt and the tap.
    let templateID: PersistentIdentifier

    let merchant: String
    let amountCents: Int
    let currency: String
    let recurrence: RecurrenceType
    let dueDate: Date
}

enum RecurrenceService {

    private static let handledPrefix = "recurring.handled."      // + uuid → Double (epoch seconds)
    private static let lastPromptDayKey = "recurring.lastPromptDay"
    static let notifAuthRequestedKey = "recurring.notifAuthRequested"   // one-shot

    // MARK: - Launch entry point

    /// Called quietly on app launch (Dashboard `.task`). Respects a once-per-day
    /// throttle so the user isn't re-prompted repeatedly the same day.
    static func checkAndPromptDueRecurring(modelContext: ModelContext) -> [RecurrencePrompt] {
        guard shouldPromptToday() else { return [] }
        return dueRecurring(modelContext: modelContext)
    }

    /// All recurring templates whose next occurrence is now due (ignores the daily throttle).
    ///
    /// Collapsed by `uuid` first. A series is one thing to the user but can be
    /// two ROWS after a first-sync union (uuid lost `@Attribute(.unique)` in V2 —
    /// CloudKit forbids it), and prompting per row asks for the same charge
    /// twice in one sitting. This is the row-count half of the double charge;
    /// the per-device watermark is the other half.
    static func dueRecurring(modelContext: ModelContext, now: Date = Date()) -> [RecurrencePrompt] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.recurrenceRaw != nil }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        let templates = Dictionary(grouping: rows, by: \.uuid)
            .values
            .compactMap(canonicalTemplate(among:))

        return templates.compactMap { tx -> RecurrencePrompt? in
            guard let rec = tx.recurrence else { return nil }
            let due = nextDueDate(for: tx, recurrence: rec)
            guard now >= due else { return nil }
            return RecurrencePrompt(
                id: tx.uuid,
                templateID: tx.persistentModelID,
                merchant: tx.merchant ?? "",
                amountCents: tx.amountCents,
                currency: tx.currency,
                recurrence: rec,
                dueDate: due
            )
        }
        // Total order, not just by dueDate: two series falling due the same day
        // must be walked in the same order on both devices, or the user answers
        // the same two questions in a different sequence per device.
        .sorted {
            $0.dueDate != $1.dueDate
                ? $0.dueDate < $1.dueDate
                : $0.id.uuidString < $1.id.uuidString
        }
    }

    // MARK: - Choosing between twins

    /// Picks the one row of a duplicated series whose values every device will
    /// agree on, from SYNCED fields only.
    ///
    /// The order:
    ///   1. later `updatedAt` — an edit is newer than a non-edit, and
    ///      last-writer-wins is already how everything else converges
    ///   2. then earlier `createdAt` — the original row of the series
    ///   3. then content — amount, type, currency, date, merchant, note
    ///
    /// `persistentModelID` is deliberately NOT in that list. It is assigned per
    /// device, so ordering on it is the one choice guaranteed to make two
    /// devices disagree — which is also why `.first` of a fetch cannot be the
    /// rule: fetch order tracks insertion order, and two devices have no reason
    /// to have inserted the twins in the same order.
    ///
    /// Rows that tie on all of (3) are identical in every synced field, so
    /// either one yields the same VALUES. The guarantee this needs is that the
    /// OUTCOME is deterministic, not that the winning object is.
    static func canonicalTemplate(among twins: [Transaction]) -> Transaction? {
        twins.min(by: precedes)
    }

    /// True when `a` should win over `b`.
    private static func precedes(_ a: Transaction, _ b: Transaction) -> Bool {
        if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        if a.amountCents != b.amountCents { return a.amountCents < b.amountCents }
        if a.typeRaw != b.typeRaw { return a.typeRaw < b.typeRaw }
        if a.currency != b.currency { return a.currency < b.currency }
        if a.date != b.date { return a.date < b.date }
        if (a.merchant ?? "") != (b.merchant ?? "") { return (a.merchant ?? "") < (b.merchant ?? "") }
        return (a.note ?? "") < (b.note ?? "")
    }

    /// The next occurrence date that has not yet been handled. The saved
    /// transaction's own date is the first occurrence, so the first *prompt*
    /// lands one full period after it (or after the last handled period).
    static func nextDueDate(for tx: Transaction, recurrence: RecurrenceType) -> Date {
        let lastBoundary = handledDate(for: tx.uuid) ?? tx.date
        return recurrence.nextDate(after: lastBoundary)
    }

    // MARK: - User actions on a prompt

    /// The single way a prompt gets back to its row. Every action surface uses
    /// it, so the Add button, the Skip button and the Edit prefill cannot end up
    /// on three different twins of the same series.
    ///
    /// Resolution is a FETCH on `persistentModelID`, and the alternatives were
    /// measured rather than reasoned about (`DeletedModelIdentifierTests`):
    ///
    /// - `model(for:)` returns a NON-optional and vends a live-looking object
    ///   over a row that no longer exists; the first stored-property read traps
    ///   (`EXC_BREAKPOINT` in `Transaction.amountCents.getter`). A template
    ///   deleted on another device between the prompt and the tap would be a
    ///   crash, not a no-op.
    /// - `registeredModel(for:)` answers on this context's registry, so it
    ///   returns nil for a perfectly live row a fresh context has not
    ///   materialized yet — the normal state on a cold launch, which is exactly
    ///   when prompts are built.
    ///
    /// A fetch is the only one of the three that means "does this row exist".
    /// Returns nil if it does not; every caller treats that as "series gone".
    static func template(for prompt: RecurrencePrompt, modelContext: ModelContext) -> Transaction? {
        let id = prompt.templateID
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Create this period's concrete transaction (non-recurring) and advance the
    /// template's handled boundary so it won't re-prompt until next period.
    ///
    /// ORDER IS LOAD-BEARING: the boundary is written only after the save
    /// succeeded. It used to be written first, and that made a failed save into
    /// a silently MISSING charge — the period was marked handled, no transaction
    /// existed, and the user was never re-prompted. `rollback()` cannot repair
    /// that, because the watermark lives in UserDefaults, outside the store.
    ///
    /// A missing charge is worse than the double charge the rest of this file
    /// exists to prevent: a double charge is visible in the ledger and the user
    /// can delete it; a missing one never appears at all.
    ///
    /// - Returns: whether the charge was actually persisted. On false nothing
    ///   changed — not the ledger, not the boundary, not the notification — and
    ///   the prompt will legitimately come back next launch.
    @discardableResult
    static func confirm(_ prompt: RecurrencePrompt, modelContext: ModelContext) -> Bool {
        guard let template = template(for: prompt, modelContext: modelContext) else { return false }

        let instance = Transaction(
            typeRaw: template.typeRaw,
            amountCents: template.amountCents,
            currency: template.currency,
            date: prompt.dueDate,
            category: template.category,
            source: template.source,
            taxCents: template.taxCents,
            note: template.note,
            merchant: template.merchant,
            recurrenceRaw: nil               // concrete occurrence, not a new template
        )
        modelContext.insert(instance)
        // Deep-copy the template's splits (A10): a split recurring purchase
        // that materialized without them would mis-categorize silently every
        // period. Fresh uuids — these are new child rows of a new purchase.
        for templateSplit in CategoryAttribution.orderedSplits(of: template) {
            let copy = TransactionSplit(
                amountCents: templateSplit.amountCents,
                category: templateSplit.category,
                note: templateSplit.note,
                order: templateSplit.order
            )
            modelContext.insert(copy)
            copy.parent = instance
        }
        do {
            try modelContext.save()
        } catch {
            // Same discipline as DuplicateReviewService: rollback() is what makes
            // a failed operation stay failed. Without it the insert stays pending
            // in the long-lived mainContext and the user's next ordinary save
            // commits this period's charge at a moment they never asked for.
            modelContext.rollback()
            logSaveFailure("RecurrenceService.confirm", error)
            return false
        }

        // Only now is the period genuinely handled.
        setHandledDate(prompt.dueDate, for: prompt.id)
        scheduleNotification(for: template)
        return true
    }

    /// Dismiss this period without logging a charge; still advances the boundary.
    static func skip(_ prompt: RecurrencePrompt, modelContext: ModelContext) {
        // The boundary advances first and unconditionally: a series whose
        // template vanished mid-prompt must still not re-ask this period.
        setHandledDate(prompt.dueDate, for: prompt.id)
        if let template = template(for: prompt, modelContext: modelContext) {
            scheduleNotification(for: template)
        }
    }

    /// Stop a series entirely (Settings → Recurring → delete). Keeps the historical
    /// transaction but clears its recurrence flag and cancels its notification.
    ///
    /// Same ordering rule as `confirm`, mirrored. The watermark used to be cleared
    /// before the save, so a failed save left a series that is still recurring on
    /// disk but has lost its period boundary — and `nextDueDate` then falls back
    /// to `tx.date`, which re-prompts for a period the user already handled. That
    /// is the double charge, arrived at from the stop path.
    ///
    /// The field restore is not redundant with `rollback()`: rollback does NOT
    /// reliably revert a mutated attribute on a live object (verified in
    /// TransactionEditServiceTests), so a bare rollback would leave
    /// `recurrenceRaw == nil` in memory to be flushed by the next save — the
    /// series would stop anyway, minutes later, silently.
    ///
    /// - Returns: whether the series was actually stopped. On false nothing
    ///   changed and the row stays in the list, which is the user's cue.
    @discardableResult
    static func stopRecurrence(for tx: Transaction, modelContext: ModelContext) -> Bool {
        let previous = tx.recurrenceRaw
        tx.recurrence = nil

        do {
            try modelContext.save()
        } catch {
            tx.recurrenceRaw = previous
            modelContext.rollback()
            logSaveFailure("RecurrenceService.stopRecurrence", error)
            return false
        }

        clearHandled(for: tx.uuid)
        cancelNotification(for: tx.uuid)
        return true
    }

    // MARK: - Editing an existing transaction's recurrence (1.0.3)

    /// What an edit did to the series — returned so the caller (and its tests)
    /// can see the decision without reaching into UNUserNotificationCenter.
    enum EditOutcome: Equatable {
        case unchanged
        case scheduled(RecurrenceType)
        case cleared
    }

    /// Toggle + picker state for an edit surface opened on `tx`. The picker
    /// always needs a selection, so a one-time transaction shows the default
    /// cadence behind an off toggle.
    static func editState(for tx: Transaction) -> (isRecurring: Bool, type: RecurrenceType) {
        let rec = tx.recurrence
        return (rec != nil, rec ?? .monthly)
    }

    /// Reconcile the notification + period bookkeeping after a recurrence edit
    /// has been PERSISTED. Deliberately does not write to the store: the
    /// transaction's `recurrenceRaw` travels through `TransactionEditService`
    /// with every other field, in one guarded save, so a failed save reverts it
    /// like anything else. Call this only once that save succeeded.
    ///
    /// - Parameter previous: the recurrence the transaction had *before* the edit.
    @discardableResult
    static func applyRecurrenceSideEffects(for tx: Transaction, previous: RecurrenceType?) -> EditOutcome {
        let current = tx.recurrence

        switch (previous, current) {
        case (nil, nil):
            return .unchanged

        case let (old?, new?) where old == new:
            // The user never touched the toggle. Re-scheduling here would
            // rewrite a pending notification for no reason on every save.
            return .unchanged

        case let (_, new?):
            // Set or re-cadenced. scheduleNotification removes the old pending
            // id first, so this reschedules off the new period. The handled
            // boundary is deliberately KEPT — changing the cadence continues
            // the series, it doesn't restart it. (When there is no boundary,
            // `nextDueDate` keys off `tx.date`: the edited transaction becomes
            // the first occurrence.)
            scheduleNotification(for: tx)
            return .scheduled(new)

        case (_?, nil):
            // Series ended. The boundary has to go with it, or re-enabling
            // later would resume mid-period against a cadence the user
            // no longer chose.
            clearHandled(for: tx.uuid)
            cancelNotification(for: tx.uuid)
            return .cleared
        }
    }

    // MARK: - Notifications

    /// One-shot authorization request, fired the first time the user enables Recurring.
    static func requestAuthorizationIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: notifAuthRequestedKey) else { return }
        defaults.set(true, forKey: notifAuthRequestedKey)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    /// Schedule a local notification 1 day before the next occurrence. Local
    /// notifications need no special entitlement; silently no-ops if not authorized.
    static func scheduleNotification(for tx: Transaction) {
        guard let rec = tx.recurrence else { return }
        let center = UNUserNotificationCenter.current()
        // Keyed by `uuid`, which means TWINS SHARE ONE IDENTIFIER — and that is
        // load-bearing, not an oversight. See `notificationID(for:)`.
        let identifier = notificationID(for: tx.uuid)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let due = nextDueDate(for: tx, recurrence: rec)
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: due),
              fireDate > Date() else { return }

        let content = notificationContent(
            merchant: tx.merchant,
            amountCents: tx.amountCents,
            currencyCode: tx.currency
        )

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Composes the reminder copy. Split out of `scheduleNotification` so the
    /// **language** of a body that is frozen at schedule time can be tested
    /// without a notification centre or a `Transaction` — the rest of that
    /// function is `UNUserNotificationCenter.current()`, which a unit test
    /// cannot drive.
    static func notificationContent(
        merchant: String?,
        amountCents: Int,
        currencyCode: String
    ) -> UNMutableNotificationContent {
        // Explicit bundle, not the `#bundle` default: `String(localized:)` does NOT
        // honor the in-app language override (LocalizedBundlePremiseTests), and this
        // body is frozen at schedule time — it would arrive in the launch language
        // days after the user switched. See FrozenArtifactLanguageTests.
        let bundle = LocalizedBundle.shared.bundle
        let content = UNMutableNotificationContent()
        content.title = String(localized: "recurring.notif.title", bundle: bundle)
        let name = (merchant?.isEmpty == false)
            ? merchant!
            : String(localized: "recurring.notif.fallback_merchant", bundle: bundle)
        let amount = Money.format(cents: amountCents, currencyCode: currencyCode)
        content.body = String(
            format: String(localized: "recurring.notif.body", bundle: bundle),
            name,
            amount
        )
        content.sound = .default
        return content
    }

    static func cancelNotification(for uuid: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID(for: uuid)])
    }

    // MARK: - Throttle

    static func shouldPromptToday() -> Bool {
        UserDefaults.standard.string(forKey: lastPromptDayKey) != todayKey()
    }

    static func markPromptedToday() {
        UserDefaults.standard.set(todayKey(), forKey: lastPromptDayKey)
    }

    // MARK: - Internals

    // (`fetchTemplate(_ uuid:)` was deleted here. Resolving a series by `uuid`
    // is no longer a valid operation — see `template(for:modelContext:)`.)

    // The period boundary is the one piece of series state that lives outside
    // SwiftData, so an edit that changes or ends a series can only be verified
    // by reading it back. Internal (not private) for exactly that.
    static func handledDate(for uuid: UUID) -> Date? {
        let t = UserDefaults.standard.double(forKey: handledPrefix + uuid.uuidString)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func setHandledDate(_ date: Date, for uuid: UUID) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: handledPrefix + uuid.uuidString)
    }

    static func clearHandled(for uuid: UUID) {
        UserDefaults.standard.removeObject(forKey: handledPrefix + uuid.uuidString)
    }

    /// The pending-notification identifier for a series.
    ///
    /// **Keyed by `uuid`, deliberately, and DO NOT "fix" this to be per-row.**
    ///
    /// This is a uuid-keyed site that the `uuid ==` audit
    /// (AUDIT_UUID_UNIQUENESS_SYNC_1_0_4) structurally could not find, because
    /// it is string interpolation rather than a comparison. Everywhere else,
    /// uuid losing `@Attribute(.unique)` in V2 made uuid-keying a bug: a
    /// first-sync union gives one series two rows carrying this same value.
    ///
    /// Here it is accidentally CORRECT, and it is what keeps the fix in
    /// `dueRecurring` whole. One series shows one prompt (the twin collapse), so
    /// it must also raise one notification. Because both twins map to this one
    /// identifier, `removePendingNotificationRequests` above genuinely replaces
    /// the series' pending notification instead of leaving a second one behind.
    ///
    /// Making this per-row — keying on `persistentModelID`, say, to match how
    /// prompts now resolve — would reintroduce the double prompt through the
    /// notification path: two pending notifications, two reminders, one series.
    /// The collapse would still be correct and the user would still be asked
    /// twice.
    ///
    /// When step 3 moves the period watermark onto the model, this stays keyed
    /// on the series, not on the row.
    private static func notificationID(for uuid: UUID) -> String {
        "recurring-\(uuid.uuidString)"
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
