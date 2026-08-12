//
//  AccessManagerTests.swift
//  FinanceTrackerTests
//
//  Locks the v1.0.2 monetization contract. Three things must never regress:
//
//  1. isPremium == hasPaidEntitlement || isReverseTrialActive
//  2. Free-tier caps block ADDING only. Over-cap items created during the trial
//     survive the drop to free, untouched. User data is never hostage.
//  3. History, CSV export (any scope) and the widget are free in EVERY state.
//

import Combine
import Foundation
import Testing
@testable import FinanceTracker

// MARK: - Fakes

/// Stands in for StoreKit. Real entitlements can't be constructed in a test —
/// `PurchaseEntitlementTests` covers the entitlement→paid mapping separately, so
/// here we only need to say "they paid" or "they didn't".
@MainActor
private final class FakePurchases: PaidEntitlementProviding {
    private let subject: CurrentValueSubject<Bool, Never>

    init(paid: Bool) { subject = CurrentValueSubject(paid) }

    var hasPaidEntitlement: Bool { subject.value }
    var hasPaidEntitlementPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    func refreshStatus() async {}

    /// Simulates a purchase landing while the app is running.
    func purchase() { subject.send(true) }
}

private final class InMemoryTrialStore: ReverseTrialStore {
    var reverseTrialStartDate: Date?
    var hasShownTrialEndPaywall: Bool
    var observedTimeWatermark: Date?
    init(start: Date? = nil, shownTrialEndPaywall: Bool = false, watermark: Date? = nil) {
        reverseTrialStartDate = start
        hasShownTrialEndPaywall = shownTrialEndPaywall
        observedTimeWatermark = watermark
    }
}

private let day: TimeInterval = 24 * 60 * 60

/// Fixed reference instant so no test depends on the wall clock.
private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

// MARK: - Access state machine

@Suite("Access state machine: paid ∪ reverse trial")
struct AccessStateMachineTests {

    @Test("Active paid entitlement is premium, with no trial in play")
    func paidEntitlementIsPremium() {
        #expect(AccessLogic.isPremium(hasPaidEntitlement: true, trialStart: nil, now: t0))
    }

    @Test("An active reverse trial is premium, with no paid entitlement")
    func activeReverseTrialIsPremium() {
        let start = t0.addingTimeInterval(-3 * day)
        #expect(AccessLogic.isPremium(hasPaidEntitlement: false, trialStart: start, now: t0))
    }

    @Test("Expired reverse trial with no paid entitlement drops to free")
    func expiredTrialWithoutPaymentIsFree() {
        let start = t0.addingTimeInterval(-20 * day)
        #expect(AccessLogic.isPremium(hasPaidEntitlement: false, trialStart: start, now: t0) == false)
    }

    @Test("Subscribing mid-trial stays premium — the paid entitlement wins")
    func subscribingMidTrialIsPremium() {
        let start = t0.addingTimeInterval(-5 * day)
        #expect(AccessLogic.isPremium(hasPaidEntitlement: true, trialStart: start, now: t0))
    }

    @Test("A paid entitlement outlives the expired trial")
    func paidEntitlementAfterTrialExpiryIsPremium() {
        let start = t0.addingTimeInterval(-60 * day)
        #expect(AccessLogic.isPremium(hasPaidEntitlement: true, trialStart: start, now: t0))
    }

    @Test("No trial recorded and nothing paid is free, not a crash")
    func noTrialNoPaymentIsFree() {
        #expect(AccessLogic.isPremium(hasPaidEntitlement: false, trialStart: nil, now: t0) == false)
    }
}

// MARK: - Trial math

@Suite("Reverse trial expires at exactly 14 days")
struct ReverseTrialMathTests {

    @Test("Day 0 is active")
    func startIsActive() {
        #expect(ReverseTrial.isActive(start: t0, now: t0))
    }

    @Test("One second before the 14-day mark is still active")
    func justBeforeExpiryIsActive() {
        let now = t0.addingTimeInterval(14 * day - 1)
        #expect(ReverseTrial.isActive(start: t0, now: now))
    }

    @Test("Exactly 14 days in, the trial is over")
    func exactlyAtExpiryIsOver() {
        let now = t0.addingTimeInterval(14 * day)
        #expect(ReverseTrial.isActive(start: t0, now: now) == false)
    }

    @Test("No start date means no trial")
    func nilStartIsNotActive() {
        #expect(ReverseTrial.isActive(start: nil, now: t0) == false)
    }

    @Test("A backwards clock keeps the trial active instead of crashing")
    func clockMovedBackwardsStaysActive() {
        let start = t0
        let now = t0.addingTimeInterval(-30 * day) // user rewound the device clock
        #expect(ReverseTrial.isActive(start: start, now: now))
        #expect(ReverseTrial.daysRemaining(start: start, now: now) == ReverseTrial.durationDays)
    }

    /// GAP CLOSED, 2026-08-13. This replaces the KNOWN-GAP pin (F2, 2026-08-05),
    /// whose own instructions said: *"If the watermark is ever added, this test
    /// fails — which is the signal to delete it, not to weaken it."* It was deleted
    /// rather than weakened, and this is the test that took its place.
    ///
    /// The gap: the trial genuinely EXPIRED, and rewinding the device clock revived
    /// the ENTITLEMENT — unbounded, for as long as the clock stayed back — while
    /// `daysRemaining` reported a clamped, plausible-looking number. The two
    /// disagreed and the entitlement was the one that mattered.
    ///
    /// **The obvious repair was checked empirically and does not work**: adding
    /// `max(now, start)` to `isActive` left the old test passing, because it only
    /// forbids `now` PRECEDING the start — a clock rewound to a date inside the
    /// window is unaffected. What closes it is a persisted monotonic high-water mark
    /// of observed time, compared as `max(now, watermark)`.
    @Test("A rewound clock can no longer revive an expired trial")
    func rewoundClockCannotReviveAnExpiredEntitlement() {
        let start = t0
        let genuinelyExpired = t0.addingTimeInterval(100 * day)
        #expect(ReverseTrial.isActive(start: start, now: genuinelyExpired) == false)

        // The install has SEEN that date, so the watermark stands there.
        let watermark = genuinelyExpired
        // Same install, same start date, clock rolled back to inside the window.
        let rewound = t0.addingTimeInterval(1 * day)

        #expect(
            ReverseTrial.isActive(start: start, now: rewound, watermark: watermark) == false,
            "the watermark outranks the rewound clock"
        )
        #expect(
            AccessLogic.isPremium(
                hasPaidEntitlement: false, trialStart: start, now: rewound, watermark: watermark
            ) == false,
            "and the gate every paid capability consults follows it"
        )
        // The badge must agree with the gate — them disagreeing was half the defect.
        #expect(ReverseTrial.daysRemaining(start: start, now: rewound, watermark: watermark) == 0)
    }

    /// The rewind must not be recoverable by winding forward again to any point the
    /// install has already passed — otherwise the mark is decorative.
    @Test("The watermark holds across repeated rewinds")
    func watermarkHoldsAcrossRepeatedRewinds() {
        let start = t0
        let watermark = t0.addingTimeInterval(100 * day)
        for offset in [-500.0, -30.0, 0.0, 1.0, 13.0, 13.9] {
            #expect(
                ReverseTrial.isActive(
                    start: start, now: t0.addingTimeInterval(offset * day), watermark: watermark
                ) == false,
                "rewinding to \(offset)d must not revive the trial"
            )
        }
    }

    /// A STRICT max, with no tolerance window: a backward `now` simply does not
    /// advance the mark. A tolerance would be a second parameter to get wrong.
    @Test("effectiveNow is a strict max with no tolerance window")
    func effectiveNowIsStrictMax() {
        let mark = t0.addingTimeInterval(10 * day)
        // A few seconds backwards — an NTP correction or a time-zone move.
        #expect(ReverseTrial.effectiveNow(now: mark.addingTimeInterval(-5), watermark: mark) == mark)
        // Forward wins.
        let ahead = mark.addingTimeInterval(day)
        #expect(ReverseTrial.effectiveNow(now: ahead, watermark: mark) == ahead)
        // No mark yet: `now` is all we have.
        #expect(ReverseTrial.effectiveNow(now: t0, watermark: nil) == t0)
    }

    /// The mark advances forward only, and a fresh install seeds it from `now`.
    @MainActor
    @Test("advanceObservedTime moves forward only")
    func advanceObservedTimeMovesForwardOnly() {
        let store = InMemoryTrialStore(start: t0)
        let manager = AccessManager(purchases: nil, store: store)

        manager.advanceObservedTime(now: t0)
        #expect(store.observedTimeWatermark == t0, "first observation seeds the mark")

        manager.advanceObservedTime(now: t0.addingTimeInterval(5 * day))
        #expect(store.observedTimeWatermark == t0.addingTimeInterval(5 * day))

        manager.advanceObservedTime(now: t0)   // clock rewound
        #expect(store.observedTimeWatermark == t0.addingTimeInterval(5 * day),
                "a backward clock must never move the mark")
    }

    /// Reinstall semantics are UNCHANGED and accepted: clearing the store clears the
    /// mark along with the start date, so the abuse ceiling stays one extra
    /// fortnight — exactly what it already was for `reverseTrialStartDate`. Pinned
    /// so nobody "hardens" it into the Keychain, where a surviving mark plus a
    /// cleared start date would describe a trial that never began.
    @Test("A reinstall clears the watermark with the start date")
    func reinstallClearsBothTogether() {
        let store = InMemoryTrialStore(start: t0, watermark: t0.addingTimeInterval(100 * day))
        store.reverseTrialStartDate = nil
        store.observedTimeWatermark = nil
        #expect(ReverseTrial.isActive(start: store.reverseTrialStartDate, now: t0,
                                      watermark: store.observedTimeWatermark) == false)
    }

    @Test("Days remaining counts down and clamps to zero")
    func daysRemainingCountsDown() {
        #expect(ReverseTrial.daysRemaining(start: t0, now: t0) == 14)
        #expect(ReverseTrial.daysRemaining(start: t0, now: t0.addingTimeInterval(13.5 * day)) == 1)
        #expect(ReverseTrial.daysRemaining(start: t0, now: t0.addingTimeInterval(14 * day)) == 0)
        #expect(ReverseTrial.daysRemaining(start: t0, now: t0.addingTimeInterval(99 * day)) == 0)
        #expect(ReverseTrial.daysRemaining(start: nil, now: t0) == 0)
    }
}

// MARK: - Trial persistence

@MainActor
@Suite("Reverse trial start is recorded once and never re-granted")
struct ReverseTrialPersistenceTests {

    @Test("First launch records the start date")
    func firstLaunchRecordsStart() {
        let store = InMemoryTrialStore()
        let access = AccessManager(purchases: nil, store: store)

        access.startReverseTrialIfNeeded(now: t0)

        #expect(store.reverseTrialStartDate == t0)
    }

    @Test("A later launch does not re-grant a fresh 14 days")
    func secondLaunchDoesNotOverwriteStart() {
        let original = t0.addingTimeInterval(-10 * day)
        let store = InMemoryTrialStore(start: original)
        let access = AccessManager(purchases: nil, store: store)

        access.startReverseTrialIfNeeded(now: t0)

        #expect(store.reverseTrialStartDate == original)
    }

    @Test("Fresh install grants full premium without any entitlement")
    func freshInstallIsPremium() {
        let store = InMemoryTrialStore()
        let access = AccessManager(purchases: nil, store: store)

        access.startReverseTrialIfNeeded(now: t0)
        access.refresh(now: t0)

        #expect(access.isPremium)
        #expect(access.isReverseTrialActive)
        #expect(access.hasPaidEntitlement == false)
        #expect(access.trialDaysRemaining == 14)
    }

    @Test("Fifteen days later, with nothing purchased, access is free")
    func afterExpiryIsFree() {
        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: nil, store: store)

        access.refresh(now: t0.addingTimeInterval(15 * day))

        #expect(access.isPremium == false)
        #expect(access.isReverseTrialActive == false)
        #expect(access.trialDaysRemaining == 0)
    }

    @Test("Buying after the trial lapsed unlocks everything again")
    func purchaseAfterExpiryRestoresAccess() {
        let store = InMemoryTrialStore(start: t0)
        let purchases = FakePurchases(paid: false)
        let access = AccessManager(purchases: purchases, store: store)
        let now = t0.addingTimeInterval(30 * day)

        access.refresh(now: now)
        #expect(access.isPremium == false)
        #expect(access.isAllowed(.csvImport) == false)

        purchases.purchase()
        access.refresh(now: now)

        #expect(access.hasPaidEntitlement)
        #expect(access.isPremium)
        #expect(access.isAllowed(.csvImport))
        #expect(access.canAdd(.addAccountBeyondFreeCap, currentCount: 6))
    }
}

// MARK: - Free-tier caps

@MainActor
@Suite("Free-tier caps block adding, never destroy")
struct FreeTierCapTests {

    @Test("A free user may create accounts up to the cap")
    func freeUserMayAddUpToAccountCap() {
        #expect(AccessLogic.canAdd(.addAccountBeyondFreeCap, isPremium: false, currentCount: 0))
        #expect(AccessLogic.canAdd(.addAccountBeyondFreeCap, isPremium: false, currentCount: 1))
    }

    @Test("A free user at the account cap is blocked")
    func freeUserBlockedAtAccountCap() {
        #expect(AccessLogic.canAdd(.addAccountBeyondFreeCap,
                                   isPremium: false,
                                   currentCount: FreeTierLimits.maxAccounts) == false)
    }

    @Test("A free user may add custom categories up to the cap, then is blocked")
    func freeUserCustomCategoryCap() {
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap, isPremium: false, currentCount: 2))
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap,
                                   isPremium: false,
                                   currentCount: FreeTierLimits.maxCustomCategories) == false)
    }

    @Test("Premium lifts every cap")
    func premiumHasNoCaps() {
        #expect(AccessLogic.canAdd(.addAccountBeyondFreeCap, isPremium: true, currentCount: 99))
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap, isPremium: true, currentCount: 99))
    }

    @Test("A lapsed trial user sitting ABOVE the cap keeps every item — only the next add is blocked")
    func overCapItemsAreNeverDestroyed() {
        // The user built 6 accounts and 9 custom categories during the trial.
        let accountsCreatedDuringTrial = 6
        let categoriesCreatedDuringTrial = 9

        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: nil, store: store)
        access.refresh(now: t0.addingTimeInterval(30 * day)) // trial long gone, never paid

        #expect(access.isPremium == false)

        // The gate refuses only the NEXT one...
        #expect(access.canAdd(.addAccountBeyondFreeCap,
                              currentCount: accountsCreatedDuringTrial) == false)
        #expect(access.canAdd(.addCustomCategoryBeyondFreeCap,
                              currentCount: categoriesCreatedDuringTrial) == false)

        // ...and reports nothing that would justify deleting, hiding, or locking
        // what already exists. The counts the app holds are untouched.
        #expect(accountsCreatedDuringTrial == 6)
        #expect(categoriesCreatedDuringTrial == 9)
    }

    @Test("Subscribing un-blocks the add for an over-cap user, still without touching data")
    func subscribingRestoresAddForOverCapUser() {
        #expect(AccessLogic.canAdd(.addAccountBeyondFreeCap, isPremium: true, currentCount: 6))
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap, isPremium: true, currentCount: 9))
    }
}

// MARK: - Trial-end paywall trigger

@MainActor
@Suite("The trial-end paywall fires once, and only when the trial actually lapsed")
struct TrialEndPaywallTests {

    @Test("Nothing fires while the trial is still running")
    func silentDuringTrial() {
        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: nil, store: store)

        #expect(access.shouldShowTrialEndPaywall(now: t0.addingTimeInterval(5 * day)) == false)
        #expect(store.hasShownTrialEndPaywall == false)
    }

    @Test("It fires the first time we notice the trial lapsed unpaid")
    func firesOnceAfterExpiry() {
        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: nil, store: store)

        #expect(access.shouldShowTrialEndPaywall(now: t0.addingTimeInterval(15 * day)))
        #expect(store.hasShownTrialEndPaywall)
    }

    @Test("It never nags a second time")
    func doesNotFireTwice() {
        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: nil, store: store)
        let now = t0.addingTimeInterval(15 * day)

        #expect(access.shouldShowTrialEndPaywall(now: now))
        #expect(access.shouldShowTrialEndPaywall(now: now) == false)
        #expect(access.shouldShowTrialEndPaywall(now: now.addingTimeInterval(60 * day)) == false)
    }

    @Test("A user who already subscribed is never shown the trial-end paywall")
    func neverFiresForAPayingUser() {
        // Trial long lapsed, but they bought — nothing to sell, nothing to say.
        let store = InMemoryTrialStore(start: t0)
        let access = AccessManager(purchases: FakePurchases(paid: true), store: store)

        #expect(access.shouldShowTrialEndPaywall(now: t0.addingTimeInterval(30 * day)) == false)
        #expect(store.hasShownTrialEndPaywall == false)
    }

    @Test("A user with no trial recorded is never nagged")
    func neverFiresWithoutATrial() {
        let store = InMemoryTrialStore(start: nil)
        let access = AccessManager(purchases: nil, store: store)

        #expect(access.shouldShowTrialEndPaywall(now: t0) == false)
    }
}

// MARK: - What counts against the category cap

@Suite("Only user-created categories count against the cap")
struct CustomCategoryCountingTests {

    /// Mirrors SeedService: a default carries a nameKey and no custom text.
    private func seeded(_ key: String) -> FinanceTracker.Category {
        FinanceTracker.Category(name: key, kindRaw: "expense", nameKey: key, nameCustom: nil)
    }

    /// Mirrors NewCategoryViewModel.makeCategory: user text, no key.
    private func custom(_ text: String) -> FinanceTracker.Category {
        FinanceTracker.Category(name: text, kindRaw: "expense", nameKey: nil, nameCustom: text)
    }

    @Test("The 13 seeded defaults are free and never count")
    func seededDefaultsDoNotCount() {
        let seeds = ["category.food_drink", "category.transport", "category.housing"].map(seeded)
        #expect(seeds.customCategoryCount == 0)
    }

    @Test("User-created categories count")
    func userCreatedCategoriesCount() {
        let all = [seeded("category.food_drink"), custom("Cat food"), custom("Guitar strings")]
        #expect(all.customCategoryCount == 2)
    }

    @Test("A free user with defaults plus two customs may still add one more")
    func freeUserUnderCapMayAdd() {
        let all = [seeded("category.food_drink"), custom("Cat food"), custom("Guitar strings")]
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap,
                                   isPremium: false,
                                   currentCount: all.customCategoryCount))
    }

    @Test("A free user at three customs is blocked, no matter how many defaults exist")
    func freeUserAtCapIsBlocked() {
        let all = [seeded("category.food_drink"), seeded("category.transport"),
                   custom("Cat food"), custom("Guitar strings"), custom("Climbing gym")]
        #expect(all.customCategoryCount == 3)
        #expect(AccessLogic.canAdd(.addCustomCategoryBeyondFreeCap,
                                   isPremium: false,
                                   currentCount: all.customCategoryCount) == false)
    }
}

// MARK: - The free/paid line

@Suite("The free/paid line")
struct CapabilityMatrixTests {

    private static let alwaysFree: [AppCapability] = [
        .manualEntry, .quickAdd, .fullHistory, .basicAnalytics, .widget,
        .exportCSVMonth, .exportCSVAll,
        .exportPDFMonth, .exportExcelMonth
    ]

    private static let premiumOnly: [AppCapability] = [
        .csvImport,
        .exportPDFAll, .exportExcelAll,
        .addAccountBeyondFreeCap, .addCustomCategoryBeyondFreeCap,
        .iCloudSync, .proactiveAlerts
    ]

    @Test("History, CSV export and the widget are never premium", arguments: alwaysFree)
    func freeCapabilitiesAreNeverGated(_ capability: AppCapability) {
        #expect(capability.requiresPremium == false)
    }

    @Test("The high-WTP capabilities are premium", arguments: premiumOnly)
    func premiumCapabilitiesAreGated(_ capability: AppCapability) {
        #expect(capability.requiresPremium)
    }

    @Test("Every capability is classified — no silent third state")
    func matrixIsExhaustive() {
        let classified = Set(Self.alwaysFree.map(\.self) + Self.premiumOnly.map(\.self))
        #expect(classified.count == AppCapability.allCases.count)
    }
}

// MARK: - Gates against live access state

@MainActor
@Suite("Feature gates read the access state, not StoreKit")
struct FeatureGateTests {

    private func access(trialStart: Date?, now: Date) -> AccessManager {
        let a = AccessManager(purchases: nil, store: InMemoryTrialStore(start: trialStart))
        a.refresh(now: now)
        return a
    }

    @Test("Import is blocked on the free tier")
    func importBlockedWhenFree() {
        let a = access(trialStart: t0, now: t0.addingTimeInterval(30 * day))
        #expect(a.isAllowed(.csvImport) == false)
    }

    @Test("Import is allowed during the reverse trial")
    func importAllowedDuringTrial() {
        let a = access(trialStart: t0, now: t0.addingTimeInterval(2 * day))
        #expect(a.isAllowed(.csvImport))
    }

    @Test("History, CSV export and the widget survive the drop to free")
    func freeStateKeepsTheFreeCapabilities() {
        let a = access(trialStart: t0, now: t0.addingTimeInterval(30 * day))
        #expect(a.isPremium == false)

        #expect(a.isAllowed(.fullHistory))
        #expect(a.isAllowed(.exportCSVMonth))
        #expect(a.isAllowed(.exportCSVAll))
        #expect(a.isAllowed(.widget))
        #expect(a.isAllowed(.manualEntry))
        #expect(a.isAllowed(.quickAdd))
        #expect(a.isAllowed(.basicAnalytics))
    }

    @Test("All-time PDF and Excel are premium once the trial lapses")
    func allTimePdfAndExcelAreGatedWhenFree() {
        let a = access(trialStart: t0, now: t0.addingTimeInterval(30 * day))
        #expect(a.isAllowed(.exportPDFAll) == false)
        #expect(a.isAllowed(.exportExcelAll) == false)
        #expect(a.isAllowed(.exportPDFMonth))
        #expect(a.isAllowed(.exportExcelMonth))
    }
}
