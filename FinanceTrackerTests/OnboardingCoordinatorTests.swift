//
//  OnboardingCoordinatorTests.swift
//  FinanceTrackerTests
//
//  Phase state-machine behavior for the first-run coordinator (Brief 28 Part B).
//

import Testing
import Foundation
@testable import FinanceTracker

@MainActor
@Suite("OnboardingCoordinator")
struct OnboardingCoordinatorTests {

    /// An isolated defaults suite so tests never touch the real onboarding flag.
    private func makeDefaults() -> UserDefaults {
        let suite = "onboarding-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func startIfNeeded_freshInstall_entersGreeting() {
        let c = OnboardingCoordinator(defaults: makeDefaults())
        c.startIfNeeded()
        #expect(c.phase == .greeting)
    }

    @Test func startIfNeeded_completed_staysInactive() {
        let d = makeDefaults()
        d.set(true, forKey: OnboardingCoordinator.completedKey)
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        #expect(c.phase == .inactive)
    }

    @Test func advance_walksAllCoachmarksThenFirstWinThenDone() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()                 // .greeting
        c.advance()                       // .coachmark(0)
        #expect(c.phase == .coachmark(0))
        #expect(c.currentStep == .quickAdd)
        c.advance()                       // .coachmark(1)
        #expect(c.currentStep == .budget)
        c.advance()                       // .coachmark(2)
        #expect(c.currentStep == .analyticsTab)
        c.advance()                       // .firstWin
        #expect(c.phase == .firstWin)
        c.advance()                       // .done + persists
        #expect(c.phase == .done)
        #expect(d.bool(forKey: OnboardingCoordinator.completedKey))
    }

    @Test func skip_fromGreeting_completesImmediately() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.skip()
        #expect(c.phase == .done)
        #expect(d.bool(forKey: OnboardingCoordinator.completedKey))
    }

    @Test func finishFirstWin_completes() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.finishFirstWin()
        #expect(c.phase == .done)
        #expect(d.bool(forKey: OnboardingCoordinator.completedKey))
    }

    /// Arms the flag EXACTLY as Settings → "Replay tutorial" does — a direct write to
    /// `replayKey` (`GeneralSettingView`). This used to call `requestReplay()`, an API
    /// with no production caller, so the test passed while covering a path the app
    /// never took. Now it covers the real one.
    @Test func replay_restartsEvenWhenCompleted() {
        let d = makeDefaults()
        d.set(true, forKey: OnboardingCoordinator.completedKey)
        let c = OnboardingCoordinator(defaults: d)
        d.set(true, forKey: OnboardingCoordinator.replayKey)
        c.startIfNeeded()
        #expect(c.phase == .greeting)
        // The one-shot replay flag is consumed so a later start won't re-trigger.
        #expect(d.bool(forKey: OnboardingCoordinator.replayKey) == false)
    }

    // MARK: - Walkthrough instrumentation (1.0.7, DESIGN_USER_GUIDE.md §6)

    @Test func skipOnGreeting_recordsSkippedAtGreeting() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.skip()
        #expect(GuideUsageSignals.firstOutcome(defaults: d) == .skipped(at: "greeting"))
    }

    @Test func skipOnSecondMark_recordsThatMarksId() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.advance()          // → coachmark(0)
        c.advance()          // → coachmark(1)
        c.skip()
        #expect(GuideUsageSignals.firstOutcome(defaults: d) == .skipped(at: c.steps[1].rawValue))
    }

    @Test func walkingToTheEnd_recordsCompleted() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.advance()
        while c.phase != .firstWin { c.advance() }
        c.finishFirstWin()
        #expect(GuideUsageSignals.firstOutcome(defaults: d) == .completed)
    }

    /// Declining the first-win card is not leaving the tour: every mark was seen.
    @Test func skipOnFirstWin_recordsCompleted() {
        let d = makeDefaults()
        let c = OnboardingCoordinator(defaults: d)
        c.startIfNeeded()
        c.advance()
        while c.phase != .firstWin { c.advance() }
        c.skip()
        #expect(GuideUsageSignals.firstOutcome(defaults: d) == .completed)
    }

    /// The first run's answer survives a replay that ends differently.
    @Test func replay_marksReplayed_andNeverOverwritesTheFirstOutcome() {
        let d = makeDefaults()
        let first = OnboardingCoordinator(defaults: d)
        first.startIfNeeded()
        first.skip()
        #expect(GuideUsageSignals.wasReplayed(defaults: d) == false)

        d.set(true, forKey: OnboardingCoordinator.replayKey)
        let replay = OnboardingCoordinator(defaults: d)
        replay.startIfNeeded()
        replay.advance()
        while replay.phase != .firstWin { replay.advance() }
        replay.finishFirstWin()

        #expect(GuideUsageSignals.wasReplayed(defaults: d))
        #expect(GuideUsageSignals.firstOutcome(defaults: d) == .skipped(at: "greeting"))
    }

    /// Before 1.0.7 nothing was recorded; that must read as "not recorded", never "skipped".
    @Test func noRun_readsAsNotRecorded() {
        #expect(GuideUsageSignals.firstOutcome(defaults: makeDefaults()) == nil)
    }
}
