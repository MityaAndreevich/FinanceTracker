//
//  LeakTeardownTests.swift
//  FinanceTrackerTests
//
//  Deallocation contracts for the reference types the app creates and destroys
//  at runtime (the singletons are excluded on purpose — they are *supposed* to
//  live for the process).
//
//  What these prove and what they do not:
//
//    They prove there is no retain cycle *rooted in the object itself* — no
//    stored closure, task, timer or observer that hands the object a strong
//    reference back to itself. That is the failure mode static reading is worst
//    at, because the cycle is spelled across three files.
//
//    They cannot prove the app leaks nothing. A cycle between two objects
//    neither of which is under test, or an ever-growing cache, is invisible
//    here. That is what the Instruments Leaks + Allocations pass on device is
//    for; these are the cheap regression net under it, so a future `[weak self]`
//    deleted in a refactor fails in CI instead of on a founder's device.
//
//  Method: hold a `weak` reference, drop the only strong one, assert the weak
//  reference zeroed. `autoreleasepool` bounds the strong reference's lifetime
//  explicitly rather than relying on where ARC decides the last use was.
//

import Foundation
import Testing
import SwiftData
import UserNotifications
@testable import FinanceTracker

@Suite("Leak teardown", .serialized)
@MainActor
struct LeakTeardownTests {

    // MARK: - VoiceInputService
    //
    // The highest-risk object in the app: per-view (`@StateObject` in
    // QuickEntryView), and it owns an audio engine, a speech recognition task, a
    // silence timer and a NotificationCenter observer. Every one of those is a
    // classic route to a self-retain.

    @Test func voiceInputServiceDeallocatesWhenReleased() {
        weak var weakService: VoiceInputService?

        autoreleasepool {
            // Injected locale: never depends on which dictation packs the
            // running device happens to have installed.
            let service = VoiceInputService(locale: Locale(identifier: "en_US"))
            weakService = service
            #expect(weakService != nil)
        }

        #expect(weakService == nil, """
            VoiceInputService survived its last strong reference — something it \
            owns (the recognition task callback, the silence timer, the \
            NotificationCenter observer, or the availability-change hop) is \
            holding `self` strongly.
            """)
    }

    /// Same contract after the object has been *used*, not merely constructed —
    /// `stop()` runs the whole `cleanup()` teardown path, which is where a
    /// dangling strong reference would be introduced if one were.
    @Test func voiceInputServiceDeallocatesAfterStop() {
        weak var weakService: VoiceInputService?

        autoreleasepool {
            let service = VoiceInputService(locale: Locale(identifier: "en_US"))
            weakService = service
            service.stop()   // safe when not listening; exercises cleanup()
        }

        #expect(weakService == nil,
                "VoiceInputService survived a stop()/cleanup() cycle")
    }

    // MARK: - OnboardingCoordinator
    //
    // Per-view too (`@StateObject` in ContentView), and it is handed to three
    // child views as an `@ObservedObject`. Cheap to pin.

    @Test func onboardingCoordinatorDeallocatesWhenReleased() {
        weak var weakCoordinator: OnboardingCoordinator?
        let suite = "leak-teardown-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        autoreleasepool {
            let coordinator = OnboardingCoordinator(defaults: defaults)
            coordinator.startIfNeeded()
            coordinator.advance()
            weakCoordinator = coordinator
        }

        #expect(weakCoordinator == nil,
                "OnboardingCoordinator survived its last strong reference")
    }

    // MARK: - ProactiveAlertRefreshScheduler
    //
    // This one is the actual regression test for the 2026-07-26 fix. The
    // scheduler stores the coalescing `Task` it creates, so a strong `self`
    // capture in that task closed a cycle for the whole coalescing window: the
    // task held the scheduler, the scheduler held the task.
    //
    // A 60-second window guarantees the pass is still in flight when the strong
    // reference is dropped, so the assertion is specifically about the pending
    // task's capture and not about a task that already finished.

    @Test func schedulerDeallocatesWhileACoalescedPassIsStillPending() throws {
        weak var weakScheduler: ProactiveAlertRefreshScheduler?

        let container = try ModelContainer(
            for: Transaction.self, FinanceTracker.Category.self, Source.self,
                MerchantCategoryLearning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let suite = "leak-teardown-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        autoreleasepool {
            let scheduler = ProactiveAlertRefreshScheduler()
            weakScheduler = scheduler
            scheduler.schedule(
                container: container,
                coalesceWindow: .seconds(60),
                defaults: defaults,
                center: NoopCenter(),
                isAllowed: { true }
            )
        }

        #expect(weakScheduler == nil, """
            ProactiveAlertRefreshScheduler survived its last strong reference \
            while a coalesced pass was pending — the stored Task is capturing \
            `self` strongly again.
            """)
    }

    /// A center that does nothing: the pass under test never reaches the
    /// scheduling step (60-second window), and no test should be able to touch
    /// the real notification centre by accident.
    private final class NoopCenter: NotificationScheduling, @unchecked Sendable {
        func removePending(identifiers: [String]) {}
        func schedule(_ request: UNNotificationRequest) {}
    }
}
