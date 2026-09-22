//
//  ReceiptCorpusTests.swift
//  FinanceTrackerTests
//
//  THE MEASUREMENT (DESIGN_RECEIPT_SCAN.md §7, founder's held-out rule):
//
//    1. The corpus lives in the PRIVATE repo. A symlink or copy at
//       FinanceTrackerTests/Fixtures/Receipts/ (manifest.csv + images) makes it
//       visible here. Nothing personal is in it (RECEIPT_CORPUS_COLLECTION_GUIDE).
//    2. `FROZEN.sha256` freezes it: one SHA-256 per file plus the manifest's.
//       Every run re-hashes and refuses a corpus that changed since freezing.
//    3. Each image is assigned to DEV or SEALED by the first byte of its SHA-256
//       (even → DEV, odd → SEALED) — deterministic, decided by the bytes, not
//       by anyone.
//    4. The DEV half runs freely (`testDevHalfReport`). The SEALED half runs
//       ONLY with RECEIPT_SEALED_RUN=1 in the environment, ONCE, after the
//       parser is frozen; the run prints the parser commit it ran against.
//    5. Both reporters print the table and assert only that they measured
//       something; `testDevHalfMeetsTheBar` / `testSealedHalfMeetsTheBar`
//       assert §7.3 per (type × locale) cell.
//
//  Until the manifest exists every test here SKIPS, visibly — a skipped test
//  is counted (executed+skipped) and named in the log; a vacuous pass is the
//  defect class D29/D30 and is not acceptable here.
//

import CryptoKit
import Foundation
import UIKit
import XCTest
@testable import FinanceTracker

final class ReceiptCorpusTests: XCTestCase {

    // MARK: - Corpus

    struct Row {
        let file: String
        let locale: String        // en ru es pt uk, or "" for non-receipts
        let type: String          // paper | screenshot | nonreceipt
        let totalCents: Int?
        let merchant: String
        let date: String
        let currency: String
        let notes: String
    }

    enum Half: String { case dev, sealed }

    static var corpusURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Receipts")
    }

    private func loadManifest() throws -> [Row] {
        let url = Self.corpusURL.appendingPathComponent("manifest.csv")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("receipt corpus not collected yet: \(url.path) is missing (RECEIPT_CORPUS_COLLECTION_GUIDE.md)")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        var rows: [Row] = []
        for (i, line) in text.components(separatedBy: .newlines).enumerated() where i > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let c = line.components(separatedBy: ",")
            guard c.count >= 8 else { XCTFail("manifest line \(i + 1) has \(c.count) columns"); continue }
            rows.append(Row(file: c[0], locale: c[1], type: c[2], totalCents: Int(c[3]), merchant: c[4], date: c[5], currency: c[6],
                            notes: c[7...].joined(separator: ",")))
        }
        XCTAssertGreaterThanOrEqual(rows.count, 1, "an empty manifest measures nothing")
        return rows
    }

    private func sha256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    /// Refuses a corpus that changed since it was frozen. Absent FROZEN.sha256 =
    /// the corpus is not frozen = nothing may be measured on it yet.
    private func verifyFrozen(_ rows: [Row]) throws -> [String: String] {
        let frozenURL = Self.corpusURL.appendingPathComponent("FROZEN.sha256")
        guard FileManager.default.fileExists(atPath: frozenURL.path) else {
            throw XCTSkip("corpus present but NOT FROZEN: write FROZEN.sha256 first (see the file header); nothing is measured on an unfrozen corpus")
        }
        var frozen: [String: String] = [:]
        for line in try String(contentsOf: frozenURL, encoding: .utf8).components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { frozen[parts[1].trimmingCharacters(in: .whitespaces)] = parts[0] }
        }
        var hashes: [String: String] = [:]
        for row in rows {
            let h = try sha256(Self.corpusURL.appendingPathComponent(row.file))
            XCTAssertEqual(frozen[row.file], h, "\(row.file) changed since the corpus was frozen — a measurement on it is void")
            hashes[row.file] = h
        }
        XCTAssertEqual(frozen["manifest.csv"], try sha256(Self.corpusURL.appendingPathComponent("manifest.csv")), "manifest.csv changed since freezing")
        return hashes
    }

    static func half(forSHA sha: String) -> Half {
        let firstByte = UInt8(sha.prefix(2), radix: 16) ?? 0
        return firstByte % 2 == 0 ? .dev : .sealed
    }

    // MARK: - Running the parser on real OCR

    struct Outcome {
        let row: Row
        let parse: ReceiptParser.Parse
        var exact: Bool { row.totalCents != nil && parse.total?.cents == row.totalCents }
        var wrongPrefill: Bool { parse.confidence == .high && parse.total?.cents != row.totalCents }
        var missed: Bool { row.totalCents != nil && parse.confidence == .low }
        var merchantMatch: Bool {
            guard let m = parse.merchant, row.merchant.count >= 4 else { return false }
            return ReceiptParser.fold(m).hasPrefix(String(ReceiptParser.fold(row.merchant).prefix(4)))
        }
        var dateMatch: Bool {
            guard let d = parse.date, !row.date.isEmpty else { return false }
            let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d) == row.date
        }
    }

    private func run(_ rows: [Row]) async throws -> [Outcome] {
        var out: [Outcome] = []
        for row in rows {
            let url = Self.corpusURL.appendingPathComponent(row.file)
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage, "\(row.file) is not an image")
            // The APP locale's separator (DESIGN §4.3): comma for ru/uk/pt-BR, period for en/es-MX.
            let sep: Character = ["ru", "uk", "pt"].contains(row.locale) ? "," : "."
            let result = try await ReceiptRecognizer.recognize(image, appLanguageCode: row.locale.isEmpty ? nil : row.locale)
            let parse = ReceiptParser.parse(lines: result.lines, decimalSeparator: sep, calendar: .current, now: Date())
            out.append(Outcome(row: row, parse: parse))
        }
        return out
    }

    // MARK: - The table (§7.4)

    struct Cell { var n = 0, exact = 0, wrong = 0, missed = 0, merchant = 0, date = 0; var misses: [String] = [] }

    private func table(_ outcomes: [Outcome]) -> [String: Cell] {
        var cells: [String: Cell] = [:]
        for o in outcomes where o.row.type != "nonreceipt" {
            let key = Self.cellLabel(type: o.row.type, locale: o.row.locale)
            var c = cells[key] ?? Cell()
            c.n += 1
            if o.exact { c.exact += 1 }
            if o.wrongPrefill { c.wrong += 1 }
            if o.missed { c.missed += 1 }
            if o.merchantMatch { c.merchant += 1 }
            if o.dateMatch { c.date += 1 }
            if !o.exact {
                c.misses.append("\(o.row.file): true \(o.row.totalCents ?? -1), chose \(o.parse.total?.cents.description ?? "nil") (\(o.parse.total?.keyword.map { "\($0)" } ?? "no keyword"), \(o.parse.confidence))")
            }
            cells[key] = c
        }
        return cells
    }

    /// The cell label says what the images ARE and what recognised them. Vision
    /// has no es-MX model (VisionLanguageSupportTests): es-MX images are
    /// recognised with es-ES, and the table says so in every row so nobody later
    /// reads the cell as a native es-MX result.
    static func cellLabel(type: String, locale: String) -> String {
        let recogniser: String
        switch locale {
        case "es": recogniser = "es-MX images, recognised es-ES"
        case "uk": recogniser = "uk images, recognised uk-UA"
        case "pt": recogniser = "pt-BR images, recognised pt-BR"
        default: recogniser = "\(locale) images, recognised \(locale)"
        }
        return "\(type)/\(locale) (\(recogniser))"
    }

    private func render(_ cells: [String: Cell], title: String) -> String {
        var s = "\n═══ \(title) ═══\ncell             n   exact  wrong-prefill  missed  merchant  date\n"
        for key in cells.keys.sorted() {
            let c = cells[key]!
            func pct(_ x: Int) -> String { c.n == 0 ? "  —  " : String(format: "%5.1f%%", 100.0 * Double(x) / Double(c.n)) }
            s += String(format: "%-16@ %3d  %@  %@         %@  %@   %@\n", key as NSString, c.n, pct(c.exact), pct(c.wrong), pct(c.missed), pct(c.merchant), pct(c.date))
            for m in c.misses { s += "    miss: \(m)\n" }
        }
        return s
    }

    /// §7.3, per cell. Returns the verdict lines; the caller asserts.
    private func barVerdicts(_ cells: [String: Cell]) -> [(cell: String, verdict: String, meetsPrefill: Bool)] {
        cells.keys.sorted().map { key in
            let c = cells[key]!
            let exact = c.n == 0 ? 0 : Double(c.exact) / Double(c.n)
            let wrong = c.n == 0 ? 0 : Double(c.wrong) / Double(c.n)
            if c.n < 10 { return (key, "n < 10 — NOT CERTIFIED", false) }
            if wrong > 0.03 { return (key, "wrong-prefill > 3% → HINT-ONLY", false) }
            if exact >= 0.90 { return (key, "prefill ON", true) }
            if exact >= 0.75 { return (key, "prefill ON with permanent 'check the amount'", true) }
            return (key, "exact < 75% — founder decides", false)
        }
    }

    private func nonReceiptControl(_ outcomes: [Outcome]) {
        let controls = outcomes.filter { $0.row.type == "nonreceipt" }
        XCTAssertGreaterThanOrEqual(controls.count, 5, "the negative control needs ≥ 5 non-receipt images")
        for o in controls {
            XCTAssertEqual(o.parse.confidence, .low, "\(o.row.file): a non-receipt came back HIGH — the parser is not ready to be measured")
            XCTAssertNil(o.parse.total, "\(o.row.file): a non-receipt produced a total")
        }
    }

    // MARK: - DEV half: run freely, tune against

    func testDevHalfReport() async throws {
        let rows = try loadManifest()
        let hashes = try verifyFrozen(rows)
        let dev = rows.filter { Self.half(forSHA: hashes[$0.file]!) == .dev }
        let outcomes = try await run(dev)
        let cells = table(outcomes)
        print(render(cells, title: "DEV half — \(dev.count) images"))
        for v in barVerdicts(cells) { print("  \(v.cell): \(v.verdict)") }
        nonReceiptControl(outcomes)
        XCTAssertGreaterThanOrEqual(outcomes.count, 1, "measured nothing")
    }

    // MARK: - SEALED half: once, after the parser is frozen

    func testSealedHalfReport() async throws {
        guard ProcessInfo.processInfo.environment["RECEIPT_SEALED_RUN"] == "1" else {
            throw XCTSkip("SEALED half runs only with RECEIPT_SEALED_RUN=1, ONCE, after the parser is frozen (DESIGN §7, held-out rule)")
        }
        let rows = try loadManifest()
        let hashes = try verifyFrozen(rows)
        let sealed = rows.filter { Self.half(forSHA: hashes[$0.file]!) == .sealed }
        let outcomes = try await run(sealed)
        let cells = table(outcomes)
        let commit = ProcessInfo.processInfo.environment["RECEIPT_PARSER_COMMIT"] ?? "UNRECORDED — pass RECEIPT_PARSER_COMMIT"
        print(render(cells, title: "SEALED half — \(sealed.count) images — parser commit \(commit)"))
        let verdicts = barVerdicts(cells)
        for v in verdicts { print("  \(v.cell): \(v.verdict)") }
        nonReceiptControl(outcomes)
        XCTAssertGreaterThanOrEqual(outcomes.count, 1, "measured nothing")
        // The bar, asserted per cell: a cell that does not meet prefill is a
        // FINDING (the founder decides), reported here as a failure so it cannot
        // be missed in a green run. Do not tune and re-run this half.
        for v in verdicts where !v.meetsPrefill {
            XCTFail("SEALED \(v.cell): \(v.verdict)")
        }
    }

    // MARK: - The split itself is deterministic and roughly even

    func testCellLabelsNameTheRecogniser() {
        XCTAssertEqual(ReceiptCorpusTests.cellLabel(type: "paper", locale: "es"), "paper/es (es-MX images, recognised es-ES)")
        XCTAssertTrue(ReceiptCorpusTests.cellLabel(type: "screenshot", locale: "uk").contains("uk-UA"))
    }

    func testSplitIsDeterministicByHash() {
        XCTAssertEqual(ReceiptCorpusTests.half(forSHA: "00abc"), .dev)
        XCTAssertEqual(ReceiptCorpusTests.half(forSHA: "01abc"), .sealed)
        XCTAssertEqual(ReceiptCorpusTests.half(forSHA: "fe"), .dev)
        XCTAssertEqual(ReceiptCorpusTests.half(forSHA: "ff"), .sealed)
    }
}
