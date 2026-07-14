//
//  ProactiveAlertSchedulerTests.swift
//  FinanceTrackerTests
//
//  The scheduler is the only impure part of the feature, so UNUserNotificationCenter sits
//  behind a protocol and these tests drive a fake. What matters is that there is never
//  more than one pending alert, that it never repeats (a repeating trigger would replay a
//  frozen number forever), and that turning alerts off actually cancels.
//

import Testing
import Foundation
import UserNotifications
@testable import FinanceTracker

/// Records what the scheduler asked the system to do.
final class FakeNotificationCenter: NotificationScheduling, @unchecked Sendable {
    var added: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func removePending(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func schedule(_ request: UNNotificationRequest) {
        added.append(request)
    }
}

struct ProactiveAlertSchedulerTests {

    private func plan(amount: Int = 60_000, pace: Bool = false) -> ProactiveAlertPolicy.Plan {
        ProactiveAlertPolicy.Plan(
            fireDate: Date().addingTimeInterval(3 * 24 * 3600),
            body: pace ? .pace(amountCents: amount) : .safeToSpend(amountCents: amount)
        )
    }

    @Test func applyingAPlanAlwaysClearsThePreviousOneFirst() {
        // Otherwise a stale request with an out-of-date number could survive alongside the
        // fresh one, and iOS would deliver both.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(), currencyCode: "USD", center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.count == 1)
    }

    @Test func aNilPlanCancelsAndSchedulesNothing() {
        // This is how every one of the policy's guards reaches the system: no plan, no
        // notification — and any previously-scheduled one is withdrawn.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: nil, currencyCode: "USD", center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.isEmpty)
    }

    @Test func cancellingRemovesThePendingRequest() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.cancel(center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.isEmpty)
    }

    @Test func theTriggerNeverRepeats() {
        // A repeating trigger would re-deliver a number frozen at schedule time, week
        // after week, long after it stopped being true.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(), currencyCode: "USD", center: center)

        let trigger = center.added.first?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger != nil)
        #expect(trigger?.repeats == false)
    }

    @Test func onlyEverOnePendingAlert() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(amount: 10_000), currencyCode: "USD", center: center)
        ProactiveAlertScheduler.apply(plan: plan(amount: 20_000), currencyCode: "USD", center: center)

        // Both used the same identifier, so iOS replaces rather than accumulates.
        #expect(Set(center.added.map(\.identifier)) == [ProactiveAlertScheduler.identifier])
    }

    @Test func theBodyCarriesTheFormattedAmount() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(amount: 60_000), currencyCode: "USD", center: center)

        let body = center.added.first?.content.body ?? ""
        let expected = Money.format(cents: 60_000, currencyCode: "USD")
        #expect(body.contains(expected), "body should contain \(expected), got: \(body)")
    }

    @Test func thePaceBodyDiffersFromTheSafeToSpendBody() {
        let safeCenter = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(pace: false), currencyCode: "USD", center: safeCenter)

        let paceCenter = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(pace: true), currencyCode: "USD", center: paceCenter)

        #expect(safeCenter.added.first?.content.body != paceCenter.added.first?.content.body)
    }

    @Test func noBodyIsEverLossFramed() {
        // Cheap guard against a future edit reintroducing loss-framing. Both bodies must
        // talk about what the user HAS, never what they have lost or gone over.
        for pace in [false, true] {
            let center = FakeNotificationCenter()
            ProactiveAlertScheduler.apply(plan: plan(pace: pace), currencyCode: "USD", center: center)
            let body = (center.added.first?.content.body ?? "").lowercased()
            #expect(!body.contains("over budget"))
            #expect(!body.contains("only"))
        }
    }
}
