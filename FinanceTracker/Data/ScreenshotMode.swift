//
//  ScreenshotMode.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 27.06.2026.
//
//  Reads the screenshot-automation launch arguments used by
//  `AppStore/capture-screenshots.sh`. Every accessor is hard-gated behind
//  `#if DEBUG` so a production Release build can never alter navigation, seed
//  demo data, or wipe the user's store from a stray launch argument.
//
//  Launch arguments (all DEBUG-only):
//    --demo-mode-debug-only      wipe + seed the deterministic demo dataset
//    --demo-locale <code>        which DemoSeed_<code>.json to load (en|ru|es|pt-BR)
//    --screenshot-screen <id>    route straight to one storyboard screen on launch
//

import Foundation

enum ScreenshotMode {

    /// The eight App Store storyboard screens, in shelf order. Raw values are the
    /// `--screenshot-screen` argument values used by the capture script.
    enum Screen: String, Identifiable {
        var id: String { rawValue }

        case dashboard      // 01 — hero (daily allowance / pace)
        case privacy        // 02 — on-device differentiator
        case quickentry     // 03 — fast capture
        case analytics      // 04 — breakdown chart (split contributes)
        case split          // 05 — one purchase across categories (1.0.3)
        case categorylimit  // 06 — gentle monthly category limit (1.0.3), list only
        case export         // 07 — data ownership / export
        case lifetime       // 08 — ownership close
        // Retired from the shelf at 1.0.3 (05_categories / 06_faceid) but kept
        // routable: AuthGateView still reads `.lock`, and both remain useful for
        // ad-hoc captures. `categorylimitsheet` is the limit EDITOR — off the shelf
        // because its destructive "Remove limit" button reads as a warning, and its
        // .medium detent leaves a third of the frame empty.
        case categories
        case categorylimitsheet
        case lock
    }

    /// The screen to route to on launch, or `nil` for a normal launch.
    static var requestedScreen: Screen? {
        value(for: "--screenshot-screen").flatMap(Screen.init(rawValue:))
    }

    /// Locale code for demo seeding (e.g. "en", "ru", "es", "pt-BR").
    /// Falls back to "en" when demo mode is on but no locale was specified.
    static var demoLocaleCode: String {
        value(for: "--demo-locale") ?? "en"
    }

    /// DEBUG-only: a locale-appropriate one-line NL phrase preloaded into Quick
    /// Entry so the App Store capture (frame 03) shows the populated *parsed*
    /// preview (amount + merchant + colored category tile) instead of the bare
    /// idle. The merchants match the seeded demo merchants, so the pre-taught
    /// merchant→category learning resolves a real category. Currency comes from
    /// `defaultCurrencyCode` (set by the seeder), so the phrase is amount + name
    /// only. Nil unless `--screenshot-quickentry-parsed` is passed; always nil in
    /// Release.
    static var quickEntryParsedInput: String? {
        #if DEBUG
        guard CommandLine.arguments.contains("--screenshot-quickentry-parsed") else { return nil }
        switch demoLocaleCode {
        case "ru":    return "3500 Пятёрочка"
        case "es":    return "180 Soriana"
        case "pt-BR": return "180 Pão de Açúcar"
        default:      return "42 Whole Foods"
        }
        #else
        return nil
        #endif
    }

    /// DEBUG-only: forces the first-run onboarding coordinator to a specific phase on
    /// launch so each coach-mark step can be screenshotted deterministically under
    /// `simctl` (which can't tap "Next"). Values: greeting | quickAdd | budget |
    /// analytics | firstwin. Always nil in Release.
    static var onboardingStep: String? {
        #if DEBUG
        return value(for: "--onboarding-step")
        #else
        return nil
        #endif
    }

    /// True only while capturing the paywall storyboard screen (08). StoreKit
    /// products can't load under `simctl launch`, so the paywall substitutes a
    /// deterministic mock of the plan cards for that capture. DEBUG-gated via
    /// `requestedScreen`, so a Release build always returns `false`.
    static var usesMockPaywall: Bool {
        requestedScreen == .lifetime
    }

    // MARK: - Argument parsing

    /// Returns the value following `flag` in the launch arguments, e.g. for
    /// `--demo-locale ru` returns "ru". DEBUG-only — always nil in Release.
    private static func value(for flag: String) -> String? {
        #if DEBUG
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        let next = args[i + 1]
        // Guard against a flag being followed by another flag (missing value).
        return next.hasPrefix("--") ? nil : next
        #else
        return nil
        #endif
    }
}
