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

/// The slice of StoreKit that AccessManager needs. A protocol rather than a
/// concrete PurchaseManager so the access rules can be tested against a paid /
/// unpaid user without a live StoreKit session (real entitlements cannot be
/// constructed in a test).
@MainActor
protocol PaidEntitlementProviding: AnyObject {
    var hasPaidEntitlement: Bool { get }
    var hasPaidEntitlementPublisher: AnyPublisher<Bool, Never> { get }
    func refreshStatus() async
}

extension PurchaseManager: PaidEntitlementProviding {
    var hasPaidEntitlementPublisher: AnyPublisher<Bool, Never> {
        $hasPaidEntitlement.eraseToAnyPublisher()
    }
}

@MainActor
final class AccessManager: ObservableObject {

    static let shared = AccessManager(purchases: PurchaseManager.shared)

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
    private let purchases: PaidEntitlementProviding?
    private var cancellables = Set<AnyCancellable>()

    init(purchases: PaidEntitlementProviding?,
         store: ReverseTrialStore = AppGroupReverseTrialStore.shared) {
        self.purchases = purchases
        self.store = store
        refresh()
    }

    // MARK: - Lifecycle

    /// Call once, at app launch, after `PurchaseManager.start()`.
    func start(now: Date = .now) {
        #if DEBUG
        applyDebugTrialOverrides(now: now)
        #endif
        startReverseTrialIfNeeded(now: now)

        purchases?.hasPaidEntitlementPublisher
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

    // MARK: - Trial end

    /// Should the root view raise the paywall right now because the reverse trial
    /// has just lapsed unpaid? Consumes the trigger: true at most once, ever.
    ///
    /// Nothing is taken away when this fires. The user's records are all still
    /// there; what they lose is the ability to import and to add past the free
    /// caps. The paywall says exactly that — loss aversion works best when the
    /// loss is real and honestly named.
    func shouldShowTrialEndPaywall(now: Date = .now) -> Bool {
        guard let start = store.reverseTrialStartDate else { return false }
        guard !(purchases?.hasPaidEntitlement ?? false) else { return false }
        guard !ReverseTrial.isActive(start: start, now: now) else { return false }
        guard !store.hasShownTrialEndPaywall else { return false }

        store.hasShownTrialEndPaywall = true
        return true
    }

    /// True when the trial has run out and nothing was bought — drives the
    /// paywall's contextual "your trial ended" header.
    var didReverseTrialLapseUnpaid: Bool {
        store.reverseTrialStartDate != nil && !isReverseTrialActive && !hasPaidEntitlement
    }

    // MARK: - Gates

    func isAllowed(_ capability: AppCapability) -> Bool {
        !capability.requiresPremium || isPremium
    }

    func canAdd(_ capability: AppCapability, currentCount: Int) -> Bool {
        AccessLogic.canAdd(capability, isPremium: isPremium, currentCount: currentCount)
    }

    // MARK: - DEBUG seams

    #if DEBUG
    /// Drives the real state machine from a launch argument — the only honest way
    /// to verify the lapse without waiting 14 days or faking the gates.
    ///
    ///   --expire-reverse-trial   backdate the start so the trial is over
    ///   --reset-reverse-trial    forget the trial entirely (simulates a fresh install)
    private func applyDebugTrialOverrides(now: Date) {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("--reset-reverse-trial") {
            store.reverseTrialStartDate = nil
            store.hasShownTrialEndPaywall = false
        }

        if args.contains("--expire-reverse-trial") {
            store.reverseTrialStartDate = now.addingTimeInterval(-(ReverseTrial.duration + 24 * 60 * 60))
            store.hasShownTrialEndPaywall = false
        }
    }
    #endif
}
