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
    func skip() { complete() }

    /// The guided first win: the user landed their first real save or opted into the
    /// demo sandbox. Ends the flow.
    func finishFirstWin() { complete() }

    /// Queue a re-run of the tutorial (Settings → Replay). Takes effect on the next
    /// `startIfNeeded()` even though onboarding is already complete.
    func requestReplay() { defaults.set(true, forKey: Self.replayKey) }

    private func complete() {
        defaults.set(true, forKey: Self.completedKey)
        // The new coach-mark flow replaces the retired feature-tour carousel, but
        // RatingPromptCoordinator still gates the (post-onboarding) rating prompt on
        // "hasSeenFeatureTour". Set it here so completing onboarding — by any path —
        // keeps that gate satisfied without touching the rating logic.
        defaults.set(true, forKey: "hasSeenFeatureTour")
        phase = .done
    }
}
