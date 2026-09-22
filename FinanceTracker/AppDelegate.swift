//
//  AppDelegate.swift
//  FinanceTracker
//
//  Exists for ONE reason: notification-tap routing. Until 1.0.6 the app had no
//  `UNUserNotificationCenterDelegate`, so tapping any Budget Crab notification
//  merely foregrounded the app. The report notifications carry a period in
//  `userInfo`; a tap must open THAT report.
//
//  The hand-off is the App-Group-flag + `.budgetCrabPendingIntent` route the
//  AppIntents already use (`ShowSpendingIntent.swift`), consumed by
//  `ContentView.handlePendingIntentNavigation` — one routing mechanism, not two.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// App-Group key: the ASCII identity of the report period to open.
    static let pendingOpenReportKey = "pendingOpenReport"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground delivery: show the banner; never auto-open a report over
    /// whatever the user is doing.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let userInfo = response.notification.request.content.userInfo
        guard let identity = userInfo[ReportNotificationScheduler.periodUserInfoKey] as? String else {
            // The safe-to-spend alert and recurrence reminders carry no period;
            // their tap stays a plain foreground (filed, out of 1.0.6 scope).
            return
        }
        Self.requestOpenReport(identity: identity)
    }

    /// Internal so a test can drive the same hand-off without a notification.
    static func requestOpenReport(identity: String) {
        let defaults = UserDefaults.appGroup
        defaults.set(identity, forKey: pendingOpenReportKey)
        // A tap while already in the foreground fires no scenePhase transition;
        // the post is what wakes ContentView in that case.
        NotificationCenter.default.post(name: .budgetCrabPendingIntent, object: nil)
    }
}
