//
//  RecurrenceNotificationIdentityTests.swift
//  FinanceTrackerTests
//
//  Replaces a comment with a test.
//
//  `RecurrenceService.notificationID(for:)` carried a long doc comment asserting
//  that twins sharing one identifier is "load-bearing, not an oversight" and
//  telling the next reader DO NOT "fix" this to be per-row. Nothing enforced it:
//  the identifier survived being replaced with a random `UUID()` while 88 tests
//  still passed (AUDIT_TEST_DISCRIMINATION_2026-08-08, finding I2).
//
//  A comment guards nothing. This project has now been burned by that three
//  times — a stale `.deny` comment sent a severity read the wrong way, an
//  `@Attribute(.unique)` comment was outright false, and the privacy policy
//  described a product name that had changed. The comment stays, because the
//  *reasoning* is worth reading; these tests are what make it true.
//
//  THE PROPERTY, stated so a future reader knows what breaking it costs:
//  one series raises one notification. After a first-sync union a series can
//  exist as two rows (see `RecurrenceTwinFixture`). `dueRecurring` already
//  collapses those to one prompt. If the notification identifier were per-row,
//  the collapse would still be correct and the user would still be reminded
//  twice — one series, two pending notifications, two reminders for one charge.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("One series raises one notification")
struct RecurrenceNotificationIdentityTests {

    private static let anchor = Date(timeIntervalSince1970: 1_770_000_000)

    /// THE pin. Two divergent rows of one series must map to one identifier, so
    /// that `removePendingNotificationRequests` genuinely REPLACES the series'
    /// pending notification rather than leaving a second one behind.
    ///
    /// The twins are made to diverge on amount and merchant on purpose: an
    /// implementation that hashed content instead of identity would pass a
    /// twins-are-identical test and fail here, which is the realistic wrong fix.
    @Test("Twins of one series share one notification identifier")
    func twinsShareOneIdentifier() throws {
        let (container, ctx) = try RecurrenceTwinFixture.makeStore()
        _ = container

        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx,
            anchor: Self.anchor,
            olderAmountCents: 5200,
            newerAmountCents: 6300,          // diverged: edited on one device only
            olderMerchant: "Netflix",
            newerMerchant: "Netflix Premium" // diverged
        )

        #expect(
            RecurrenceService.notificationID(for: twins.older)
                == RecurrenceService.notificationID(for: twins.newer),
            """
            Twins of one series produced two notification identifiers. \
            The user will be reminded twice for one charge. If this was a \
            deliberate move to per-row keying, dueRecurring's twin collapse \
            must move with it — see RecurrenceTwinCollapseTests.
            """
        )
    }

    /// Row order is not a promise and two devices have no reason to agree on it.
    /// Insertion order must not reach the identifier.
    @Test("Insertion order does not reach the identifier")
    func identifierIsOrderIndependent() throws {
        let (container, ctx) = try RecurrenceTwinFixture.makeStore()
        _ = container

        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: Self.anchor, insertNewerFirst: true
        )

        #expect(
            RecurrenceService.notificationID(for: twins.older)
                == RecurrenceService.notificationID(for: twins.newer)
        )
    }

    /// Discrimination guard. Without this, `return "recurring"` — a constant —
    /// would satisfy every assertion above. Two DIFFERENT series must not
    /// collide, or scheduling one reminder would silently cancel another's.
    @Test("Different series do not collide")
    func distinctSeriesGetDistinctIdentifiers() throws {
        let (container, ctx) = try RecurrenceTwinFixture.makeStore()
        _ = container

        let netflix = RecurrenceTwinFixture.insertTemplate(
            in: ctx, anchor: Self.anchor, merchant: "Netflix"
        )
        let rent = RecurrenceTwinFixture.insertTemplate(
            in: ctx, anchor: Self.anchor, merchant: "Rent"
        )

        #expect(
            RecurrenceService.notificationID(for: netflix)
                != RecurrenceService.notificationID(for: rent),
            "Two series collapsed onto one identifier — scheduling one reminder cancels the other."
        )
    }

    /// `scheduleNotification` composes the identifier from the ROW;
    /// `cancelNotification` composes it from the UUID. Nothing but this test
    /// stops those two from drifting apart — and if they drift, cancel silently
    /// stops cancelling: the reminder for a series the user just deleted still
    /// fires, and no code path reports it.
    @Test("The schedule path and the cancel path compose the same identifier")
    func schedulePathAgreesWithCancelPath() throws {
        let (container, ctx) = try RecurrenceTwinFixture.makeStore()
        _ = container

        let tx = RecurrenceTwinFixture.insertTemplate(in: ctx, anchor: Self.anchor)

        #expect(
            RecurrenceService.notificationID(for: tx)
                == RecurrenceService.notificationID(for: tx.uuid),
            "cancelNotification(for:) would no longer cancel what scheduleNotification scheduled."
        )
    }
}
