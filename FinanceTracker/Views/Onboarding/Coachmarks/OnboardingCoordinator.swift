//
//  OnboardingCoordinator.swift
//  FinanceTracker
//
//  Drives the first-run experience as a small phase state machine (Brief 28 Part B):
//  greeting → in-place Dashboard coach-marks → guided first win → done. Uses
//  ObservableObject to match the codebase's existing observation idiom
//  (VoiceInputService, LocalizedBundle). Completion is persisted to the same
//  UserDefaults key RootView reads, so a finished/skipped flow never re-triggers.
//

import SwiftUI
import Combine

@MainActor
final class OnboardingCoordinator: ObservableObject {

    enum Phase: Equatable {
        case inactive
        case greeting
        case coachmark(Int)   // index into `steps`
        case firstWin
        case done
    }

    /// AppStorage-compatible keys (plain UserDefaults, same standard suite).
    static let completedKey = "hasCompletedOnboarding"
    static let replayKey = "onboardingReplayRequested"

    /// Dashboard/tab-bar targets, in tour order.
    let steps: [CoachmarkID] = [.quickAdd, .budget, .analyticsTab]

    @Published private(set) var phase: Phase = .inactive

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// True while the running flow was started by Settings → Replay tutorial.
    /// A replay never writes the first-run outcome (`GuideUsageSignals`).
    private var isReplay = false

    /// The coach-mark target for the current phase, or nil outside `.coachmark`.
    var currentStep: CoachmarkID? {
        if case let .coachmark(i) = phase, steps.indices.contains(i) { return steps[i] }
        return nil
    }

    /// Starts the flow on a genuine first run, or when a replay was requested from
    /// Settings. A completed run stays `.inactive` (the app shows normally).
    func startIfNeeded() {
        let completed = defaults.bool(forKey: Self.completedKey)
        let replay = defaults.bool(forKey: Self.replayKey)
        guard !completed || replay else { phase = .inactive; return }
        defaults.set(false, forKey: Self.replayKey)
        isReplay = completed && replay
        if isReplay { GuideUsageSignals.markReplayed(defaults: defaults) }
        phase = .greeting
    }

    /// Greeting "Show me" → first coach-mark.
    func beginCoachmarks() { phase = .coachmark(0) }

    /// DEBUG/screenshot seam: jump straight to a named phase (see
    /// ScreenshotMode.onboardingStep) so each step can be captured under simctl.
    func startAtDebugPhase(_ raw: String) {
        switch raw {
        case "greeting": phase = .greeting
        case "quickAdd": phase = .coachmark(0)
        case "budget":   phase = .coachmark(1)
        case "analytics":phase = .coachmark(2)
        case "firstwin": phase = .firstWin
        default:         phase = .greeting
        }
    }

    /// Advance the current phase. Walks the coach-marks, then the first-win, then done.
    func advance() {
        switch phase {
        case .greeting:
            phase = .coachmark(0)
        case .coachmark(let i):
            let next = i + 1
            phase = steps.indices.contains(next) ? .coachmark(next) : .firstWin
        case .firstWin:
            complete()
        case .inactive, .done:
            break
        }
    }

    /// Skip from anywhere ends the flow (and marks it complete so it won't re-run).
    func skip() {
        record(skippedAt: phase)
        complete()
    }

    /// The guided first win: the user landed their first real save or opted into the
    /// demo sandbox. Ends the flow.
    func finishFirstWin() { complete() }

    // REMOVED 2026-08: `requestReplay()`. Settings → "Replay tutorial" arms the flag
    // by writing `replayKey` directly, so this method had no production caller — and
    // its only test exercised a path the app never took. Two ways to arm one flag is
    // how a dead path gets "fixed" instead of the live one. `replayKey` above stays
    // the single named home for the key.

    /// Skip on the first-win card still counts as completed: every mark of the
    /// tour was seen, and declining the first entry is not leaving the tour.
    private func record(skippedAt phase: Phase) {
        guard !isReplay else { return }
        let outcome: GuideUsageSignals.WalkthroughOutcome
        switch phase {
        case .greeting: outcome = .skipped(at: "greeting")
        case .coachmark(let i): outcome = .skipped(at: steps.indices.contains(i) ? steps[i].rawValue : "coachmark")
        case .firstWin, .inactive, .done: outcome = .completed
        }
        GuideUsageSignals.recordFirstOutcome(outcome, defaults: defaults)
    }

    private func complete() {
        if !isReplay, phase == .firstWin {
            GuideUsageSignals.recordFirstOutcome(.completed, defaults: defaults)
        }
        defaults.set(true, forKey: Self.completedKey)
        // The new coach-mark flow replaces the retired feature-tour carousel, but
        // RatingPromptCoordinator still gates the (post-onboarding) rating prompt on
        // "hasSeenFeatureTour". Set it here so completing onboarding — by any path —
        // keeps that gate satisfied without touching the rating logic.
        defaults.set(true, forKey: "hasSeenFeatureTour")
        phase = .done
    }
}
