//
//  PurchaseEntitlementTests.swift
//  FinanceTrackerTests
//
//  Locks the premium-gating contract: premium == ANY active (non-revoked)
//  entitlement on one of our product IDs. Trial, paid renewal, and lifetime
//  non-consumable are ALL premium; revoked/refunded and foreign products are
//  not. This is the launch-blocker fix — a user on the active free trial MUST
//  be premium and MUST NOT see the Export/Import paywall.
//
//  These tests exercise the pure `PurchaseManager.evaluatePremium` mapping,
//  which `refreshPremiumStatus()` feeds live `currentEntitlements` into. A live
//  StoreKit `SKTestSession` assertion (trial flips isPremium without relaunch)
//  is NOT wired here — final trial/entitlement confirmation must be done in
//  Sandbox (real sandbox Apple ID, StoreKit config OFF), because the local
//  .storekit test env can misreport trial/entitlement state.
//

import Testing
@testable import FinanceTracker

@Suite("Premium entitlement mapping")
struct PurchaseEntitlementTests {

    typealias Snapshot = PurchaseManager.EntitlementSnapshot

    private let monthly  = "bc_premium_monthly"
    private let annual   = "bc_premium_annual"   // the one with the free trial
    private let lifetime = "bc_premium_lifetime"

    // MARK: - Entitled states

    @Test("Active trial (annual intro offer) → premium")
    func trialIsPremium() {
        // A trial is an active entitlement on the annual product; nothing about
        // being in the introductory-offer period should exclude it.
        let entitlements = [Snapshot(productID: annual, isRevoked: false)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == true)
    }

    @Test("Paid monthly renewal → premium")
    func paidMonthlyIsPremium() {
        let entitlements = [Snapshot(productID: monthly, isRevoked: false)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == true)
    }

    @Test("Paid annual (post-trial renewal) → premium")
    func paidAnnualIsPremium() {
        let entitlements = [Snapshot(productID: annual, isRevoked: false)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == true)
    }

    @Test("Lifetime non-consumable → premium")
    func lifetimeIsPremium() {
        let entitlements = [Snapshot(productID: lifetime, isRevoked: false)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == true)
    }

    @Test("Any one active entitlement among several → premium")
    func mixedWithOneActiveIsPremium() {
        let entitlements = [
            Snapshot(productID: monthly, isRevoked: true),   // refunded
            Snapshot(productID: annual, isRevoked: false)    // active trial
        ]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == true)
    }

    // MARK: - Non-entitled states (paywall must show)

    @Test("No entitlements → not premium")
    func emptyIsNotPremium() {
        #expect(PurchaseManager.evaluatePremium(entitlements: []) == false)
    }

    @Test("Revoked / refunded entitlement → not premium")
    func revokedIsNotPremium() {
        let entitlements = [Snapshot(productID: annual, isRevoked: true)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == false)
    }

    @Test("Entitlement on a foreign product ID → not premium")
    func foreignProductIsNotPremium() {
        let entitlements = [Snapshot(productID: "com.someoneelse.pro", isRevoked: false)]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == false)
    }

    @Test("All entitlements revoked → not premium")
    func allRevokedIsNotPremium() {
        let entitlements = [
            Snapshot(productID: monthly, isRevoked: true),
            Snapshot(productID: annual, isRevoked: true),
            Snapshot(productID: lifetime, isRevoked: true)
        ]
        #expect(PurchaseManager.evaluatePremium(entitlements: entitlements) == false)
    }
}
