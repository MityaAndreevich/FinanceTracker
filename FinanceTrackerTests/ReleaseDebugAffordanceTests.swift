//
//  ReleaseDebugAffordanceTests.swift
//  FinanceTrackerTests
//
//  Nothing debug-only may be reachable in a Release build (v1.0.2 device QA,
//  item 1). The app's debug machinery — the chart-bisection panel in Settings,
//  the data-wiping QA seams (--reset-accounts, --reset-tip-collection,
//  --seed-possible-duplicates, demo/screenshot modes, trial overrides) — is
//  kept out of Release by `#if DEBUG` at every declaration and call site, which
//  makes the Release build itself the enforcing check: an unwrapped reference
//  to a wrapped type cannot compile.
//
//  That discipline only holds while every reference stays wrapped, so this test
//  scans the app target's source and fails on:
//
//    1. any launch-argument read (`CommandLine.arguments` /
//       `processInfo.arguments`) outside an `#if DEBUG` region — Release must
//       ignore ALL launch arguments, because several of them wipe data;
//    2. any reference to a debug-only symbol outside an `#if DEBUG` region —
//       which would either break the Release build (good, but noisy late) or,
//       worse, mean someone unwrapped the symbol's declaration too.
//
//  `ChartBisection` and the `ScreenshotMode`/`DemoSeeder` accessors are the
//  sanctioned pattern for production call sites: unwrapped shims whose Release
//  branches are compile-time constants (`true` / `false` / `nil`). Their
//  internals satisfy rule 1 because the actual argument reads sit inside DEBUG.
//

import Foundation
import Testing

@Suite("No debug affordance is reachable in a Release build")
struct ReleaseDebugAffordanceTests {

    /// Symbols that exist only for debugging. Every reference to any of these,
    /// anywhere in the app target, must sit inside an `#if DEBUG` region.
    private static let debugOnlySymbols = [
        "ChartDebug",                 // the bisection instrument + Settings panel state
        "chartBisectionSection",      // the Settings panel itself
        "AccountResetDebugSeam",      // --reset-accounts (wipes every Source)
        "DuplicateReviewDebugSeed",   // --seed-possible-duplicates
        "resetForDebugIfRequested",   // --reset-tip-collection (wipes the collection)
        "applyDebugTrialOverrides",   // --expire/--reset-reverse-trial
    ]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// (path, lines annotated with whether each is inside an `#if DEBUG` region).
    private static func annotatedSources() throws -> [(path: String, lines: [(text: String, inDebug: Bool)])] {
        let appDir = repoRoot.appendingPathComponent("FinanceTracker")
        let enumerator = FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)
        var results: [(String, [(String, Bool)])] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            results.append((url.path, annotate(source)))
        }
        return results
    }

    /// Walks compiler-conditional blocks, tracking whether each line is inside a
    /// region that only compiles in DEBUG. Handles nesting (`#if os(iOS)` inside
    /// `#if DEBUG` and vice versa) and `#else` (the else-branch of `#if DEBUG`
    /// is the RELEASE branch, and vice versa is conservatively not-debug).
    private static func annotate(_ source: String) -> [(String, Bool)] {
        var stack: [Bool] = []
        var annotated: [(String, Bool)] = []
        for rawLine in source.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                stack.append(line.contains("DEBUG"))
            } else if line.hasPrefix("#elseif") {
                if !stack.isEmpty { stack[stack.count - 1] = line.contains("DEBUG") }
            } else if line.hasPrefix("#else") {
                if !stack.isEmpty { stack[stack.count - 1].toggle() }
            } else if line.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
            }
            annotated.append((rawLine, stack.contains(true)))
        }
        return annotated
    }

    /// Comment lines can name a debug symbol legitimately ("see ChartDebug.swift").
    private static func isComment(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
    }

    @Test("Release ignores every launch argument — several of them wipe data")
    func launchArgumentReadsAreDebugOnly() throws {
        for (path, lines) in try Self.annotatedSources() {
            for (line, inDebug) in lines
            where (line.contains("CommandLine.arguments") || line.contains("processInfo.arguments"))
                && !Self.isComment(line) {
                #expect(inDebug,
                        "\(path): launch-argument read outside #if DEBUG — a Release build must not process launch arguments: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    @Test("Every reference to a debug-only symbol is wrapped in #if DEBUG")
    func debugSymbolReferencesAreWrapped() throws {
        var found = Set<String>()
        for (path, lines) in try Self.annotatedSources() {
            for (line, inDebug) in lines where !Self.isComment(line) {
                for symbol in Self.debugOnlySymbols where line.contains(symbol) {
                    found.insert(symbol)
                    #expect(inDebug,
                            "\(path): '\(symbol)' referenced outside #if DEBUG: \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        // The scan proves nothing if a rename quietly empties it.
        for symbol in Self.debugOnlySymbols {
            #expect(found.contains(symbol),
                    "'\(symbol)' no longer appears anywhere — renamed? Update debugOnlySymbols so the guard keeps guarding")
        }
    }
}
