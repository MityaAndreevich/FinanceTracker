//
//  ReportNotificationScheduler.swift
//  FinanceTracker
//
//  Turns `ReportNotificationPolicy.Plan`s into pending local notifications —
//  the second instance of the ProactiveAlertScheduler shape, not a new
//  mechanism. One stable identifier per cadence, `repeats: false`, rescheduled
//  on every refresh pass, entitlement re-checked every pass.
//

import Foundation
import UserNotifications

enum ReportNotificationScheduler {

    static let weeklyIdentifier = "budgetcrab.report.weekly"
    static let monthlyIdentifier = "budgetcrab.report.monthly"
    static let identifiers = [weeklyIdentifier, monthlyIdentifier]

    /// `userInfo` key carrying the period's ASCII identity; read back by
    /// `AppDelegate` on tap. Not dotted: the localization-key scanner in
    /// `LocaleCompletenessTests` treats any dotted string literal as a key.
    static let periodUserInfoKey = "reportPeriodIdentity"

    static func identifier(for cadence: ReportCadence) -> String {
        switch cadence {
        case .weekly: return weeklyIdentifier
        case .monthly: return monthlyIdentifier
        }
    }

    /// Replace both pending requests with the plans given (none = cancel).
    static func apply(
        plans: [ReportNotificationPolicy.Plan],
        calendar: Calendar = .current,
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        center.removePending(identifiers: identifiers)
        for plan in plans {
            center.schedule(request(for: plan, calendar: calendar))
        }
    }

    static func cancel(center: NotificationScheduling = UNUserNotificationCenter.current()) {
        center.removePending(identifiers: identifiers)
    }

    /// Internal so `FrozenArtifactLanguageTests` and the policy tests can read
    /// the body without a notification center.
    static func request(for plan: ReportNotificationPolicy.Plan, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title(for: plan.cadence)
        content.body = body(for: plan, calendar: calendar)
        content.sound = .default
        content.userInfo = [periodUserInfoKey: plan.period.identity(calendar: calendar)]
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
        // `repeats: false` — the period label in the body is specific to ONE
        // fire date; the next one is scheduled by the next refresh pass.
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: identifier(for: plan.cadence), content: content, trigger: trigger)
    }

    /// Explicit bundle: a notification's text is frozen at schedule time, and
    /// `String(localized:)`'s default bundle ignores the in-app language.
    static func title(for cadence: ReportCadence) -> String {
        let bundle = LocalizedBundle.shared.bundle
        switch cadence {
        case .weekly: return String(localized: "reports.notif.title.weekly", bundle: bundle)
        case .monthly: return String(localized: "reports.notif.title.monthly", bundle: bundle)
        }
    }

    /// The period label and an invitation. No amount, no count — see the policy header.
    static func body(for plan: ReportNotificationPolicy.Plan, calendar: Calendar) -> String {
        let bundle = LocalizedBundle.shared.bundle
        // The label's language must match the body's: the in-app override
        // when set (lproj name, so "pt" → pt-BR), the device otherwise.
        let locale = LocalizedBundle.lprojName(for: LocalizedBundle.shared.languageCode)
            .map { Locale(identifier: $0) } ?? Locale.current
        return String(
            format: String(localized: "reports.notif.body.format", bundle: bundle),
            plan.period.label(locale: locale, calendar: calendar)
        )
    }

    // MARK: - Authorization (asked only when a toggle is turned on)

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            let ns = error as NSError
            persistenceLog.error("report notification authorization failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
            return false
        }
    }
}

// MARK: - Refresh glue

enum ReportNotificationRefresher {

    /// Called from the same coalesced refresh pass as the safe-to-spend alert
    /// (foreground + didSave). Needs no ledger data — it runs BEFORE the
    /// aggregate guard there, so an unsummable ledger still gets its report
    /// notification (the report itself will show the unavailable state).
    static func apply(
        isAllowed: Bool,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        calendar: Calendar = .current,
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        guard isAllowed else {
            ReportNotificationScheduler.cancel(center: center)
            return
        }
        let settings = ReportNotificationPolicy.Settings.read(defaults)
        let plans = ReportNotificationPolicy.plan(now: now, settings: settings, calendar: calendar)
        ReportNotificationScheduler.apply(plans: plans, calendar: calendar, center: center)
    }
}
