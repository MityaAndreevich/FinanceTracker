//
//  PlainTextEntryCoverageTests.swift
//  FinanceTrackerTests
//
//  The app has no login, so no field should offer Passwords or Contacts in the
//  QuickType bar. Every text-entry surface therefore declares `.plainTextEntry()`
//  (see Shared/PlainTextEntry.swift).
//
//  This is a SOURCE scan rather than a behavioural test, and that is deliberate:
//  whether the Passwords key is actually drawn is a keyboard behaviour we can
//  only confirm on a real device with AutoFill configured — a simulator has no
//  saved passwords, so it would show no key regardless and "pass" while proving
//  nothing. What IS mechanically checkable, and what actually regresses, is
//  someone adding a TextField and forgetting the modifier. That is what this
//  guards.
//

import XCTest

final class PlainTextEntryCoverageTests: XCTestCase {

    /// Repo root, derived from this file's own path (…/FinanceTrackerTests/x.swift).
    private var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FinanceTrackerTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("FinanceTracker")
    }

    private func swiftSources(file: StaticString = #filePath, line: UInt = #line) throws -> [URL] {
        let fm = FileManager.default

        // The `guard let` below was dead code, and it was the ONLY thing standing
        // between a moved source tree and three green tests that had read nothing.
        // `enumerator(at:)` returns a NON-nil enumerator for a directory that does
        // not exist; it just yields zero elements. So the skip was unreachable, the
        // scan came back empty, every `offenders` array stayed empty, and all three
        // tests passed by having examined no source at all.
        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            fm.fileExists(atPath: appSourceRoot.path, isDirectory: &isDirectory) && isDirectory.boolValue,
            "app source root \(appSourceRoot.path) is missing — the sources moved and this guard is scanning nothing",
            file: file, line: line
        )

        guard let walker = fm.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil) else {
            XCTFail("could not enumerate \(appSourceRoot.path)", file: file, line: line)
            return []
        }
        let sources = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }

        // 100 is far below the real count and far above anything a broken walk
        // would produce. In the helper, so no future scan can skip it.
        XCTAssertGreaterThan(
            sources.count, 100,
            "only \(sources.count) .swift files scanned — the walk is broken",
            file: file, line: line
        )
        return sources
    }

    /// Every `TextField(` declaration is followed by `.plainTextEntry()`.
    func test_everyTextField_declaresPlainTextEntry() throws {
        var offenders: [String] = []
        var examined = 0

        for file in try swiftSources() {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("TextField(") {
                examined += 1
                // The modifier is expected within the field's own chain — allow a
                // few lines of slack so an intervening `.keyboardType` or
                // `.focused` doesn't trip this.
                let window = lines[index..<min(index + 8, lines.count)]
                if !window.contains(where: { $0.contains(".plainTextEntry()") }) {
                    offenders.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }

        // Independent of the file count: the app HAS text fields, so zero matches
        // means the match string went stale, not that the surfaces disappeared.
        XCTAssertGreaterThan(examined, 0, "no TextField( found in any source — the match string is stale")

        XCTAssertTrue(offenders.isEmpty, """
            These TextFields do not declare .plainTextEntry(), so iOS will infer a \
            content type for them and may offer Passwords/Contacts: \
            \(offenders.joined(separator: ", "))
            """)
    }

    /// Same for `.searchable` — search was the surface the founder actually hit.
    func test_everySearchable_declaresPlainTextEntry() throws {
        var offenders: [String] = []
        var examined = 0

        for file in try swiftSources() {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains(".searchable(") {
                examined += 1
                // `.searchable` spans several lines when it carries a placement and
                // a prompt, so allow a wider window than the TextField scan.
                let window = lines[index..<min(index + 10, lines.count)]
                if !window.contains(where: { $0.contains(".plainTextEntry()") }) {
                    offenders.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertGreaterThan(examined, 0, "no .searchable( found in any source — the match string is stale")

        XCTAssertTrue(offenders.isEmpty, """
            These .searchable fields do not declare .plainTextEntry(): \
            \(offenders.joined(separator: ", "))
            """)
    }

    /// The modifier must never opt a field INTO a credential or code content
    /// type. `.oneTimeCode` is the popular "hide the Passwords key" answer online
    /// and it works, but it subscribes the field to SMS security-code suggestions
    /// — a worse outcome than the symptom, and easy for a future edit to reach for.
    func test_noCredentialContentTypeAnywhere() throws {
        let banned = [".oneTimeCode", ".newPassword", ".password", "UITextContentType(\"\")"]
        var offenders: [String] = []

        for file in try swiftSources() {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("textContentType") {
                for token in banned where line.contains(token) {
                    offenders.append("\(file.lastPathComponent):\(index + 1) uses \(token)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: ", "))
    }
}
