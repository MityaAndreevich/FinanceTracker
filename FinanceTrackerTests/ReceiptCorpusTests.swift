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
//    3. Each RECEIPT is assigned to DEV or SEALED by the first byte of the
//       SHA-256 of its receipt_id (even → DEV, odd → SEALED). All shots of one
//       physical receipt share a receipt_id, so they land in the same half —
//       a per-FILE split put near-duplicate shots in both halves and leaked
//       sealed content into tuning (amendment 2026-10-25, STATE §13.13).
//    4. The DEV half runs freely (`testDevHalfReport`). The SEALED half runs
//       ONLY with RECEIPT_SEALED_RUN=1 in the environment, ONCE, after the
//       parser is frozen; the run prints the parser commit it ran against.
//    5. Results are reported per RECEIPT (shot `_a`, the one taken by the
//       photographing rules — §7.3 is judged on this table) and per IMAGE
//       (variant shots: a robustness sub-table, not extra samples).
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
        let receiptId: String     // shared by every shot of one physical receipt
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
        let lines = text.components(separatedBy: .newlines)
        // A pre-amendment manifest has no receipt_id; read positionally it would
        // shift every column by one, so it is refused rather than misread.
        guard lines.first?.hasPrefix(Self.manifestHeader) == true else {
            XCTFail("manifest header must start with `\(Self.manifestHeader)` (RECEIPT_CORPUS_COLLECTION_GUIDE.md)")
            return []
        }
        var rows: [Row] = []
        for (i, line) in lines.enumerated() where i > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let c = line.components(separatedBy: ",")
            guard c.count >= 9 else { XCTFail("manifest line \(i + 1) has \(c.count) columns"); continue }
            rows.append(Row(file: c[0], receiptId: c[1], locale: c[2], type: c[3], totalCents: Int(c[4]), merchant: c[5], date: c[6],
                            currency: c[7], notes: c[8...].joined(separator: ",")))
        }
        XCTAssertGreaterThanOrEqual(rows.count, 1, "an empty manifest measures nothing")
        for problem in Self.receiptProblems(rows) { XCTFail(problem) }
        return rows
    }

    static let manifestHeader = "file,receipt_id,locale,type,total_cents,merchant,date,currency,notes"

    /// Shot `_a` of a receipt is its sample for the bar; every other shot is a variant.
    static func isPrimary(_ row: Row) -> Bool {
        (row.file as NSString).deletingPathExtension == row.receiptId + "_a"
    }

    /// Every shot of one receipt is the same receipt: same truth, and exactly one
    /// primary shot. A manifest that breaks this would make the per-receipt
    /// table depend on which shot happened to be read.
    static func receiptProblems(_ rows: [Row]) -> [String] {
        var problems: [String] = []
        for (id, shots) in Dictionary(grouping: rows, by: \.receiptId).sorted(by: { $0.key < $1.key }) {
            if id.isEmpty { problems.append("rows with an empty receipt_id: \(shots.map(\.file))"); continue }
            let primaries = shots.filter(isPrimary).count
            if primaries != 1 { problems.append("\(id): \(primaries) primary shots (need exactly one `\(id)_a.*`)") }
            let truths = Set(shots.map { "\($0.locale)|\($0.type)|\($0.totalCents.map(String.init) ?? "")|\($0.merchant)|\($0.date)|\($0.currency)" })
            if truths.count > 1 { problems.append("\(id): shots of one receipt disagree on its truth: \(truths.sorted())") }
        }
        return problems
    }

    private func sha256(_ url: URL) throws -> String {
        Self.sha256Hex(try Data(contentsOf: url))
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Refuses a corpus that changed since it was frozen. Absent FROZEN.sha256 =
    /// the corpus is not frozen = nothing may be measured on it yet.
    @discardableResult
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

    /// The half is decided by the receipt, never by the file: hashing a file
    /// sends near-duplicate shots of one receipt to both halves.
    static func half(forReceiptID id: String) -> Half {
        half(forSHA: sha256Hex(Data(id.utf8)))
    }

    static func split(_ rows: [Row]) -> (dev: [Row], sealed: [Row]) {
        (rows.filter { half(forReceiptID: $0.receiptId) == .dev }, rows.filter { half(forReceiptID: $0.receiptId) == .sealed })
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

    /// Per receipt (gated) first, then the robustness sub-table of variant shots.
    private func report(_ outcomes: [Outcome], title: String) -> [String: Cell] {
        let receipts = table(outcomes.filter { Self.isPrimary($0.row) })
        let variants = outcomes.filter { !Self.isPrimary($0.row) }
        print(render(receipts, title: "\(title) — PER RECEIPT (shot _a; §7.3 is judged here)"))
        print(render(table(variants), title: "\(title) — VARIANT SHOTS, \(variants.count) images (robustness only, NOT samples, NOT the bar)"))
        print(render(table(outcomes), title: "\(title) — PER IMAGE, all \(outcomes.count) shots (robustness only)"))
        return receipts
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
        try verifyFrozen(rows)
        let dev = Self.split(rows).dev
        let outcomes = try await run(dev)
        let cells = report(outcomes, title: "DEV half — \(Set(dev.map(\.receiptId)).count) receipts, \(dev.count) images")
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
        try verifyFrozen(rows)
        let sealed = Self.split(rows).sealed
        let outcomes = try await run(sealed)
        let commit = ProcessInfo.processInfo.environment["RECEIPT_PARSER_COMMIT"] ?? "UNRECORDED — pass RECEIPT_PARSER_COMMIT"
        let cells = report(outcomes, title: "SEALED half — \(Set(sealed.map(\.receiptId)).count) receipts, \(sealed.count) images — parser commit \(commit)")
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

    /// The commissioning fixture: 2 receipts × 3 shots. The file names and bytes
    /// were chosen so the OLD per-file rule splits BOTH receipts across the
    /// halves — asserted below, so the fixture cannot quietly stop discriminating.
    static let splitFixture: [(row: Row, bytes: Data)] = ["en_paper_01", "ru_paper_02"].flatMap { id in
        ["a", "b", "c"].map { shot in
            let file = "\(id)_\(shot).jpg"
            let row = Row(file: file, receiptId: id, locale: String(id.prefix(2)), type: "paper", totalCents: 1234,
                          merchant: "Fixture", date: "2026-10-25", currency: "USD", notes: "")
            return (row, Data("shot \(file)".utf8))
        }
    }

    func testSplitKeepsEveryShotOfAReceiptInOneHalf() {
        let rows = Self.splitFixture.map(\.row)
        XCTAssertEqual(Self.receiptProblems(rows), [])

        // Precondition: the pre-amendment rule (first byte of each FILE's SHA-256) leaks.
        let perFile = Self.splitFixture.filter { Self.half(forSHA: Self.sha256Hex($0.bytes)) == .dev }.map(\.row)
        let perFileLeaks = Set(perFile.map(\.receiptId)).intersection(rows.filter { r in !perFile.contains { $0.file == r.file } }.map(\.receiptId))
        XCTAssertEqual(perFileLeaks, ["en_paper_01", "ru_paper_02"], "fixture no longer discriminates: the per-file rule must split both receipts")

        let (dev, sealed) = Self.split(rows)
        XCTAssertEqual(Set(dev.map(\.receiptId)).intersection(sealed.map(\.receiptId)), [], "a receipt_id appears in both halves")
        XCTAssertEqual(dev.count + sealed.count, rows.count)
        // And the fixture exercises both halves, so "everything in one half" cannot pass it.
        XCTAssertEqual(Set(dev.map(\.receiptId)), ["ru_paper_02"])
        XCTAssertEqual(Set(sealed.map(\.receiptId)), ["en_paper_01"])
    }

    func testManifestRejectsAReceiptWhoseShotsDisagree() {
        var rows = Self.splitFixture.map(\.row)
        let b = rows[1]
        rows[1] = Row(file: b.file, receiptId: b.receiptId, locale: b.locale, type: b.type, totalCents: 9999,
                      merchant: b.merchant, date: b.date, currency: b.currency, notes: "")
        rows.removeAll { $0.file == "ru_paper_02_a.jpg" }
        let problems = Self.receiptProblems(rows)
        XCTAssertTrue(problems.contains { $0.hasPrefix("en_paper_01: shots of one receipt disagree") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.hasPrefix("ru_paper_02: 0 primary shots") }, "\(problems)")
    }
}
