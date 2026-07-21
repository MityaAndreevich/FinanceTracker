//
//  ProactiveAlertScheduler.swift
//  FinanceTracker
//
//  The only impure part of the alerts feature: it turns a `ProactiveAlertPolicy.Plan`
//  (or the absence of one) into a pending iOS notification (or the absence of one).
//
//  Follows the pattern already established in RecurrenceService rather than inventing a
//  second notification flow.
//

import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` this feature needs — behind a protocol so the
/// scheduling rules can be tested against a fake instead of the real system.
///
/// The method is `schedule`, not `add`: `UNUserNotificationCenter` already has its own
/// `add(_:)` overloads, and a protocol requirement of the same name would be ambiguous at
/// best and infinitely recursive at worst.
protocol NotificationScheduling {
    func removePending(identifiers: [String])
    func schedule(_ request: UNNotificationRequest)
}

extension UNUserNotificationCenter: NotificationScheduling {
    func removePending(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func schedule(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}

enum ProactiveAlertScheduler {

    /// One stable identifier, so a new request *replaces* the pending one rather than
    /// piling up beside it. There is never more than one weekly alert in flight.
    static let identifier = "budgetcrab.proactive.weekly"

    /// Cancel whatever is pending, then schedule the plan — or nothing, if there isn't
    /// one. Every guard in `ProactiveAlertPolicy` arrives here as `plan == nil`.
    static func apply(
        plan: ProactiveAlertPolicy.Plan?,
        currencyCode: String,
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        center.removePending(identifiers: [identifier])
        guard let plan else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "alerts.notif.title")
        content.body = body(for: plan.body, currencyCode: currencyCode)
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: plan.fireDate
        )
        // `repeats: false` is load-bearing. A repeating trigger would re-deliver a number
        // frozen at schedule time, week after week, long after it went stale.
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        center.schedule(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    static func cancel(center: NotificationScheduling = UNUserNotificationCenter.current()) {
        center.removePending(identifiers: [identifier])
    }

    /// Gain-framed, month-scoped. The amount is the whole month's remainder, so the copy
    /// says so — calling it a week figure would overstate what is safe to spend.
    private static func body(for body: ProactiveAlertPolicy.Body, currencyCode: String) -> String {
        switch body {
        case .safeToSpend(let cents):
            return String(
                format: String(localized: "alerts.notif.body.safe.format"),
                Money.format(cents: cents, currencyCode: currencyCode)
            )
        case .pace(let cents):
            return String(
                format: String(localized: "alerts.notif.body.pace.format"),
                Money.format(cents: cents, currencyCode: currencyCode)
            )
        case .categoryLimit(_, let name, let remainingCents):
            // Gain-framed by construction: the policy only emits this while
            // remaining > 0 ("X left in Dining"), never an exceeded message.
            return String(
                format: String(localized: "alerts.notif.body.limit.format"),
                Money.format(cents: remainingCents, currencyCode: currencyCode),
                name
            )
        }
    }

    // MARK: - Authorization

    /// Asked for **only** when the user turns alerts on — never at launch.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
