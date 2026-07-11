//
//  AccessManager.swift
//  FinanceTracker
//
//  THE single source of truth for "may this user do this?".
//
//      isPremium == hasPaidEntitlement || isReverseTrialActive
//
//  Views ask AccessManager. Views never ask StoreKit, never read
//  `currentEntitlements`, and never do trial date math themselves.
//

import Combine
import Foundation

/// Pure access rules. Everything here is a total function of explicit inputs so
/// the whole state machine is testable without StoreKit, a clock, or a UI.
enum AccessLogic {

    static func isPremium(hasPaidEntitlement: Bool, trialStart: Date?, now: Date) -> Bool {
        // A real entitlement always wins: subscribing mid-trial, or long after it
        // lapsed, is premium either way.
        hasPaidEntitlement || ReverseTrial.isActive(start: trialStart, now: now)
    }

    /// May the user create one more of a capped thing?
    ///
    /// Note what this does NOT do: it never says anything about the items that
    /// already exist. A free user holding 6 accounts is simply told "no" on the
    /// 7th. Nothing anywhere reads this to decide what to show, delete or lock.
    static func canAdd(_ capability: AppCapability, isPremium: Bool, currentCount: Int) -> Bool {
        if isPremium { return true }
        guard let limit = capability.freeLimit else { return !capability.requiresPremium }
        return currentCount < limit
    }
}

@MainActor
final class AccessManager: ObservableObject {

    static let shared = AccessManager(purchases: .shared)

    // MARK: - Published state

    /// The one flag the feature gates read.
    @Published private(set) var isPremium: Bool = false

    /// True only for a REAL StoreKit entitlement (paid, renewing, inside Apple's
    /// intro trial, or lifetime). The paywall dismisses on this — not on
    /// `isPremium` — so a reverse-trial user can still reach it and subscribe.
    @Published private(set) var hasPaidEntitlement: Bool = false

    @Published private(set) var isReverseTrialActive: Bool = false
    @Published private(set) var trialDaysRemaining: Int = 0

    // MARK: - Dependencies

    private let store: ReverseTrialStore
    private let purchases: PurchaseManager?
    private var cancellables = Set<AnyCancellable>()

    init(purchases: PurchaseManager?,
         store: ReverseTrialStore = AppGroupReverseTrialStore.shared) {
        self.purchases = purchases
        self.store = store
        refresh()
    }

    // MARK: - Lifecycle

    /// Call once, at app launch, after `PurchaseManager.start()`.
    func start(now: Date = .now) {
        startReverseTrialIfNeeded(now: now)

        purchases?.$hasPaidEntitlement
            .sink { [weak self] _ in
                // Re-read on the next tick so we observe the settled value, not
                // the one in flight.
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)

        refresh(now: now)
    }

    /// Records the trial start on first ever launch. Idempotent: an existing
    /// start date is NEVER overwritten, so relaunching cannot farm a fresh 14 days.
    func startReverseTrialIfNeeded(now: Date = .now) {
        guard store.reverseTrialStartDate == nil else { return }
        store.reverseTrialStartDate = now
    }

    func refresh(now: Date = .now) {
        let start = store.reverseTrialStartDate
        let paid = purchases?.hasPaidEntitlement ?? false

        hasPaidEntitlement = paid
        isReverseTrialActive = ReverseTrial.isActive(start: start, now: now)
        trialDaysRemaining = ReverseTrial.daysRemaining(start: start, now: now)
        isPremium = AccessLogic.isPremium(hasPaidEntitlement: paid, trialStart: start, now: now)
    }

    /// Re-reads StoreKit before answering. Use at tap time on a gate, so an
    /// already-entitled user never sees a paywall because of a stale cache.
    func refreshFromStoreKit() async {
        await purchases?.refreshStatus()
        refresh()
    }

    // MARK: - Gates

    func isAllowed(_ capability: AppCapability) -> Bool {
        !capability.requiresPremium || isPremium
    }

    func canAdd(_ capability: AppCapability, currentCount: Int) -> Bool {
        AccessLogic.canAdd(capability, isPremium: isPremium, currentCount: currentCount)
    }
}
