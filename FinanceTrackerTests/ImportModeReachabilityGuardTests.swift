//
//  ImportModeReachabilityGuardTests.swift
//  FinanceTrackerTests
//
//  Pins a CONDITION, not a behaviour: `.importAll` must not become reachable
//  from shipping code until partial-state disclosure is live.
//
//  WHY THE GUARD LIVES HERE AND NOT IN A DOCUMENT
//
//  The condition was first written into an audit. Nobody building a "keep both"
//  toggle reads an audit — they read the enum, the view, and the tests that fail.
//  A guard has to live where the change gets made. This month's whole theme is
//  that a documented hazard is a comment, and a comment guards nothing.
//
//  WHAT THE CONDITION IS
//
//  On the mapped (foreign-CSV) path a row is ALWAYS inserted: those rows carry no
//  UUID, so there is nothing to dedup against. `.skipDuplicates` does not decide
//  whether a row lands — only whether it is FLAGGED `isPossibleDuplicate`. That
//  flag is the entire reason a re-import after a partial failure is recoverable:
//  the repeats are badged and collected in the duplicate-review queue.
//
//  `.importAll` switches that flagging off (`processMappedRow`, the
//  `mode == .skipDuplicates &&` conjunction). Combined with an import that
//  half-succeeded, it would let a retry silently double thousands of rows with
//  nothing marking them.
//
//  WHY A SOURCE SCAN RATHER THAN A BEHAVIOURAL TEST
//
//  Same reasoning as `LocalizedCallSiteGuardTests`: the thing to prevent is a
//  future EDIT, not a current wrong answer. There is no runtime state to assert
//  on — the hazard does not exist until somebody wires a picker to this enum, and
//  at that moment the guard must fail loudly and explain itself. The rule is about
//  the source, so the source is what is tested.
//
//  A SCANNER THAT FINDS NO FILES MUST NEVER READ AS "NO VIOLATIONS"
//
//  Inherited verbatim from the localization guard, because it is the same class
//  as everything else caught this month: `#filePath` is baked in at compile time,
//  so the repo root is derived from it and asserted. If the tree moves, this fails
//  at the `#expect` on the roots rather than silently scanning nothing and
//  reporting success.
//

import Foundation
import Testing

@Suite("`.importAll` stays unreachable from shipping code")
struct ImportModeReachabilityGuardTests {

    /// Directories that ship in a product. Test targets are excluded: tests are
    /// SUPPOSED to exercise `.importAll` — three of them do, and that is correct.
    /// The rule is about what a user's build can reach.
    private static let scannedRoots = ["FinanceTracker", "BudgetCrabShared", "BudgetCrabWidget"]

    /// The declaration site and the branch that READS the case are legitimate.
    /// What is forbidden is production code that SETS it.
    private static let exemptSuffixes = ["Services/CSVImportService.swift"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)      // …/FinanceTrackerTests/<this file>
            .deletingLastPathComponent()      // …/FinanceTrackerTests
            .deletingLastPathComponent()      // …/<repo root>
    }

    private struct Violation: CustomStringConvertible {
        let path: String
        let line: Int
        let text: String
        var description: String { "\(path):\(line)  \(text.trimmingCharacters(in: .whitespaces))" }
    }

    @Test("No shipping file assigns CSVImportMode.importAll")
    func importAllIsNotWiredUp() throws {
        let fm = FileManager.default
        var scannedFiles = 0
        var violations: [Violation] = []

        for root in Self.scannedRoots {
            let dir = Self.repoRoot.appendingPathComponent(root)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            // NOTE: `enumerator(at:)` returns a NON-nil enumerator that yields zero
            // elements for a bad path — it cannot be used to detect a wrong root.
            // That is why `scannedFiles` is asserted separately below.
            guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }

            for case let url as URL in walker where url.pathExtension == "swift" {
                let rel = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
                if Self.exemptSuffixes.contains(where: { rel.hasSuffix($0) }) { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedFiles += 1

                for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    // Ignore comments — the enum's own doc comment names the case
                    // repeatedly, and so does this guard's rationale wherever it is
                    // quoted. Only real code counts.
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") || trimmed.hasPrefix("*") { continue }
                    if line.contains(".importAll") {
                        violations.append(Violation(path: rel, line: i + 1, text: String(line)))
                    }
                }
            }
        }

        // The scanner must have actually read something. A zero-file scan reporting
        // "no violations" is the exact defect class this project has already paid
        // for more than once.
        #expect(scannedFiles > 50, """
            Scanned only \(scannedFiles) shipping Swift files — the roots are wrong, \
            so this guard proved nothing. Roots: \(Self.scannedRoots) under \(Self.repoRoot.path)
            """)

        #expect(violations.isEmpty, """
            `.importAll` is now set by shipping code:

            \(violations.map(\.description).joined(separator: "\n"))

            READ THIS BEFORE DELETING THE GUARD.

            `.importAll` turns OFF duplicate flagging on the mapped (foreign-CSV) \
            import path. Those rows carry no UUID, so they are always inserted — \
            flagging is the only thing that makes a re-import recoverable, by \
            badging repeats into the duplicate-review queue.

            The condition for wiring this up is that partial-state disclosure is \
            live: an import that stops mid-way must TELL the user how many rows \
            landed (`PartialImportFailure` → `data.import.partial.format`). \
            Without it, a user is told "Import failed" after a partial commit, \
            re-imports the file, and with `.importAll` the duplicates arrive \
            silently and unmarked.

            If disclosure is live and this is deliberate, delete this guard in the \
            same commit that wires up the toggle — deliberately, not reflexively.
            """)
    }
}
