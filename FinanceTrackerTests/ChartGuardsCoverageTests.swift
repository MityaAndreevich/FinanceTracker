//
//  ChartGuardsCoverageTests.swift
//  FinanceTrackerTests
//
//  A guard with no caller is not a guard (v1.0.2 review, item 8).
//
//  This has now happened twice: `dimension(_:)` was written for the degenerate-
//  frame crash and shipped UNWIRED — the exact bug it was built against cost
//  ~ten rounds of on-device debugging while the fix sat as dead code — and then
//  `finite(_:)` shipped with only test callers. The pattern is always the same:
//  the choke-point file grows a correct function, and the wiring commit never
//  lands. So this test scans the app target's source: every member declared in
//  ChartGuards.swift must either have a production call site or sit on the
//  exemption list below with a written reason. Exemptions EXPIRE: the moment an
//  exempt member gains a real caller, the test demands its removal, so the list
//  can only shrink toward zero.
//
//  Members are discovered by parsing the declarations, not hand-listed — a new
//  guard added to ChartGuards.swift is covered by this test automatically.
//

import Foundation
import Testing

@Suite("Every ChartGuards member is wired or explicitly excused")
struct ChartGuardsCoverageTests {

    /// Members allowed to have no production caller, each with the reason on
    /// record. Keyed by the qualified call pattern the scan searches for.
    private static let exemptions: [String: String] = [
        // Future-proofing, per the file's own NOTE: money is Int cents (always
        // finite), so no Double-valued mark/scale bound exists to coerce today.
        // The day one does, wire it and delete this entry.
        "ChartGuards.finite(": "guards a future Double-valued mark; no Double mark exists yet",

        // Internal plumbing: its only caller is the `cents:` overload in
        // ChartGuards.swift itself, which the scan excludes as the defining file.
        "ChartGuards.canRenderContinuous(values:": "wrapped by the cents: overload every real caller uses",

        // Internal plumbing: the geometry half's only caller is ChartFrameGuard,
        // in the defining file — every view reaches it through .guardedChartFrame(),
        // which the scan verifies separately.
        "ChartGuards.canRenderInBox(": "wrapped by ChartFrameGuard behind .guardedChartFrame()",
    ]

    // MARK: - The scan

    /// Repo-relative source of truth, located from this file's compile-time path.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)            // …/FinanceTrackerTests/ChartGuardsCoverageTests.swift
            .deletingLastPathComponent()           // …/FinanceTrackerTests
            .deletingLastPathComponent()           // repo root
    }

    private static var guardsFile: URL {
        repoRoot.appendingPathComponent("FinanceTracker/Shared/ChartGuards.swift")
    }

    /// Every .swift file in the app target except ChartGuards.swift itself.
    private static func productionSources() throws -> [(path: String, contents: String)] {
        let appDir = repoRoot.appendingPathComponent("FinanceTracker")
        let enumerator = FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)
        var results: [(String, String)] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  url.lastPathComponent != "ChartGuards.swift" else { continue }
            results.append((url.path, try String(contentsOf: url, encoding: .utf8)))
        }
        return results
    }

    /// The call patterns declared in ChartGuards.swift. Static members are
    /// called qualified (`ChartGuards.name(label:`) because ChartGuards is an
    /// enum; the View-extension modifier is called as `.guardedChartFrame(`.
    private static func declaredPatterns() throws -> [String] {
        let source = try String(contentsOf: guardsFile, encoding: .utf8)

        // `static func name(label:` or `static func name(_ …` → drop the label.
        // The optional `<…>` keeps generic members (renderableSlices<T>) covered.
        let regex = try NSRegularExpression(pattern: #"static func (\w+)(?:<[^>]*>)?\(\s*(_|\w+)"#)
        let range = NSRange(source.startIndex..., in: source)
        var patterns: [String] = regex.matches(in: source, range: range).map { match in
            let name = String(source[Range(match.range(at: 1), in: source)!])
            let label = String(source[Range(match.range(at: 2), in: source)!])
            return label == "_"
                ? "ChartGuards.\(name)("
                : "ChartGuards.\(name)(\(label):"
        }

        if source.contains("func guardedChartFrame") {
            patterns.append(".guardedChartFrame(")
        }
        return patterns
    }

    // MARK: - The contract

    @Test("Every declared guard has a production caller, unless excused in writing")
    func everyGuardIsWiredOrExcused() throws {
        let patterns = try Self.declaredPatterns()
        try #require(!patterns.isEmpty, "parsed no members out of ChartGuards.swift — the scan itself broke")

        let sources = try Self.productionSources()
        try #require(!sources.isEmpty, "found no app sources — the scan itself broke")

        for pattern in patterns {
            let callers = sources.filter { $0.contents.contains(pattern) }
            let isExempt = Self.exemptions.keys.contains { pattern.hasPrefix($0) || $0.hasPrefix(pattern) }

            if isExempt {
                #expect(callers.isEmpty,
                        "\(pattern) is on the exemption list but now HAS a caller — remove its exemption")
            } else {
                #expect(!callers.isEmpty,
                        "\(pattern) has NO production caller. A guard with no caller is not a guard — wire it, or add it to the exemption list with the reason in writing")
            }
        }
    }

    @Test("No stale exemptions: every entry excuses a member that still exists")
    func exemptionsMatchDeclaredMembers() throws {
        let patterns = try Self.declaredPatterns()
        for key in Self.exemptions.keys {
            let stillDeclared = patterns.contains { $0.hasPrefix(key) || key.hasPrefix($0) }
            #expect(stillDeclared,
                    "exemption '\(key)' excuses a member ChartGuards no longer declares — delete it")
        }
    }
}
