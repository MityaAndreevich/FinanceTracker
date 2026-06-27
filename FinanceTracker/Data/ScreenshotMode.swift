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

        case dashboard      // 01 — hero
        case privacy        // 02 — on-device differentiator
        case quickentry     // 03 — fast capture
        case analytics      // 04 — breakdown chart
        case categories     // 05 — categories & accounts
        case lock           // 06 — Face ID gate
        case export         // 07 — data ownership / export
        case lifetime       // 08 — paywall / ownership close
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
