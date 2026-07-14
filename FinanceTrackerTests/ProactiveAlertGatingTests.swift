//
//  ProactiveAlertGatingTests.swift
//  FinanceTrackerTests
//
//  Alerts are a premium hook. The capability already existed in FreeTierLimits —
//  declared under "Premium hooks — NOT built yet" so the gate would be there the day the
//  feature landed. These are characterization tests: they pin the behaviour the settings
//  screen now depends on, and would catch someone later flipping proactiveAlerts to free
//  by accident. There is no red phase here, and that is correct.
//
//  The rules live on `AccessLogic` (a pure enum), not on `AccessManager` (the
//  @MainActor ObservableObject whose `isPremium` is a published property) — which is
//  exactly why they can be tested with no StoreKit, no clock, and no UI.
//

import Testing
import Foundation
@testable import FinanceTracker

struct ProactiveAlertGatingTests {

    @Test func alertsRequirePremium() {
        #expect(AppCapability.proactiveAlerts.requiresPremium == true)
    }

    @Test func aFreeUserIsBlocked() {
        let isPremium = AccessLogic.isPremium(
            hasPaidEntitlement: false,
            trialStart: nil,
            now: .now
        )
        #expect(isPremium == false)
    }

    @Test func anActiveReverseTrialGetsAlerts() {
        // The reverse trial resolves through the same isPremium call, so trial users get
        // alerts with no extra code path to forget.
        let isPremium = AccessLogic.isPremium(
            hasPaidEntitlement: false,
            trialStart: .now,
            now: .now
        )
        #expect(isPremium == true)
    }

    @Test func aPaidUserGetsAlerts() {
        let isPremium = AccessLogic.isPremium(
            hasPaidEntitlement: true,
            trialStart: nil,
            now: .now
        )
        #expect(isPremium == true)
    }

    @Test func aLapsedTrialWithoutPurchaseIsBlocked() {
        // The refresher re-checks this on every pass, so an expired trial cannot leave a
        // premium notification pending.
        let longAgo = Calendar.current.date(byAdding: .day, value: -60, to: .now)!
        let isPremium = AccessLogic.isPremium(
            hasPaidEntitlement: false,
            trialStart: longAgo,
            now: .now
        )
        #expect(isPremium == false)
    }
}
