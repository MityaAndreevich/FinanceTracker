//
//  LocalizedCallSiteGuardTests.swift
//  FinanceTrackerTests
//
//  THE LOCK. `FrozenArtifactLanguageTests` proves the three highest-consequence
//  producers now resolve correctly; this proves nobody can quietly undo it, at
//  any of the 35 sites or at a site written next month.
//
//  WHY A SOURCE SCAN AND NOT A BEHAVIOURAL TEST. The defect is invisible by
//  construction: a bare `String(localized:)` compiles, runs, returns a perfectly
//  valid string, and is wrong only for a user who switched language mid-session.
//  There is no runtime signal to assert on for a `Text` inside a view body, and
//  writing 35 view-rendering tests to cover 35 one-line lookups is scaffolding
//  out of all proportion to the change. What actually prevents the regression is
//  a rule about the SOURCE — so that is what is tested, directly.
//
//  This test fails LOUDLY and names the file and line, because the failure mode
//  it guards against is a well-meaning refactor ("this `bundle:` looks
//  redundant") rather than a typo.
//
//  THE RULE
//
//      Every `String(localized:)` in shipping code passes an explicit `bundle:`.
//
//  `String(localized:)` takes its bundle from a `#bundle` default that does NOT
//  route through the `object_setClass(Bundle.main, LanguageBundle.self)` override
//  the in-app language picker relies on. Measured, not assumed — see
//  `LocalizedBundlePremiseTests`. `NSLocalizedString` DOES route through it and
//  is deliberately not covered by this rule.
//
//  ROOT DISCOVERY: `#filePath` is baked in at compile time and points at this
//  file in the working tree, so the repo root is two directories up. If the
//  sources ever move relative to the tests this test fails at the `#require`
//  rather than silently scanning nothing — a scanner that finds no files must
//  never read as "no violations".
//

import Foundation
import Testing

@Suite("Every String(localized:) passes an explicit bundle")
struct LocalizedCallSiteGuardTests {

    /// Directories that ship in a product. Test targets are excluded on purpose:
    /// a test that calls `String(localized:)` bare is measuring the harness, and
    /// `LocalizedBundlePremiseTests` documents why that matters.
    private static let scannedRoots = ["FinanceTracker", "BudgetCrabShared", "BudgetCrabWidget"]

    /// The ONLY exemption, and it is the probe that measures the defect itself.
    /// `LocalizationProbe.stringLocalized` must call the bare spelling — that is
    /// its entire job. Exempting the file rather than the line keeps the list
    /// short enough to stay honest; the file is 120 lines and is the one place a
    /// reviewer already knows to read carefully.
    private static let exemptSuffixes = ["Shared/LocalizedBundle.swift"]

    private struct Violation: CustomStringConvertible {
        let path: String
        let line: Int
        let text: String
        var description: String { "\(path):\(line)  \(text)" }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)      // …/FinanceTrackerTests/ThisFile.swift
            .deletingLastPathComponent()      // …/FinanceTrackerTests
            .deletingLastPathComponent()      // …/  repo root
    }

    /// Strips `//` line comments so a commented-out example or a doc comment
    /// mentioning the spelling is not reported. Block comments are not stripped;
    /// none of the scanned files put a call site inside one, and a naive block
    /// stripper would be more likely to hide a real violation than to prevent a
    /// false one.
    private func stripLineComment(_ line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[line.startIndex..<range.lowerBound])
    }

    /// True when the call opened at `start` carries a `bundle:` label before its
    /// matching close paren. A real paren scan, not a substring search: the
    /// argument is frequently a nested `String(format:)` and "does `bundle:`
    /// appear later on this line" would pass the wrong calls.
    private func callPassesBundle(_ source: String, from start: String.Index) -> Bool {
        var depth = 0
        var index = start
        var body = ""
        while index < source.endIndex {
            let character = source[index]
            if character == "(" { depth += 1 }
            if character == ")" {
                depth -= 1
                if depth == 0 { break }
            }
            body.append(character)
            index = source.index(after: index)
        }
        return body.contains("bundle:")
    }

    private func violations(in file: URL, relativeTo root: URL) throws -> [Violation] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
        guard !Self.exemptSuffixes.contains(where: { relative.hasSuffix($0) }) else { return [] }

        var found: [Violation] = []
        for (offset, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let line = stripLineComment(rawLine)
            guard let hit = line.range(of: "String(localized:") else { continue }
            // Scan from the "(" of `String(` so the paren depth starts correctly.
            let open = line.index(hit.lowerBound, offsetBy: "String".count)
            guard !callPassesBundle(line, from: open) else { continue }
            found.append(
                Violation(
                    path: relative,
                    line: offset + 1,
                    text: rawLine.trimmingCharacters(in: .whitespaces)
                )
            )
        }
        return found
    }

    @Test("no shipping call site relies on the #bundle default")
    func everyCallSitePassesAnExplicitBundle() throws {
        let root = repoRoot()
        var scannedFiles = 0
        var found: [Violation] = []

        for directory in Self.scannedRoots {
            let url = root.appendingPathComponent(directory)
            var isDirectory: ObjCBool = false
            #expect(
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue,
                "scan root \(directory) is missing — the sources moved and this guard is scanning nothing"
            )
            let enumerator = try #require(FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: nil
            ))
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                scannedFiles += 1
                found.append(contentsOf: try violations(in: file, relativeTo: root))
            }
        }

        // A scanner that found no files would report "no violations" — the exact
        // false green this whole audit exists to stop. 100 is far below the real
        // count and far above anything a broken walk would produce.
        #expect(scannedFiles > 100, "only \(scannedFiles) .swift files scanned — the walk is broken")

        #expect(
            found.isEmpty,
            """
            \(found.count) call site(s) use String(localized:) without an explicit bundle.

            `String(localized:)`'s #bundle default IGNORES the in-app language override
            (measured in LocalizedBundlePremiseTests), so these return the LAUNCH language
            for the rest of the process after a user switches.

            Fix: pass `bundle: LocalizedBundle.shared.bundle` (or `localizedBundle.bundle`
            in a view that already observes it).

            \(found.map(\.description).joined(separator: "\n"))
            """
        )
    }
}
