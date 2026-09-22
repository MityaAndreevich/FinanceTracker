//
//  ReceiptSeamRecognitionTests.swift
//  FinanceTrackerTests
//
//  The UI journey's fixture, recognised by the REAL Vision path five times in
//  a row. If this is not deterministic, the journey cannot be either — and the
//  fault is upstream of the UI.
//

import UIKit
import XCTest
@testable import FinanceTracker

final class ReceiptSeamRecognitionTests: XCTestCase {

    func testSeamFixtureIsRecognisedDeterministically() async throws {
        #if DEBUG
        let lines = "Corner Shop|Milk 2.49|Bread 3.10|Subtotal 5.59|Tax 0.45|Total 6.04".components(separatedBy: "|")
        let image = try XCTUnwrap(ReceiptScanDebugSeam.render(lines: lines))
        var results: [String] = []
        for _ in 0..<5 {
            let r = try await ReceiptRecognizer.recognize(try XCTUnwrap(image.cgImage), appLanguageCode: "en")
            let p = ReceiptParser.parse(lines: r.lines, decimalSeparator: ".", calendar: .current, now: Date())
            results.append("\(p.total?.cents.description ?? "nil")/\(p.confidence)/\(p.merchant ?? "nil")")
            print("SEAM OCR lines: \(r.lines.map { "\($0.text)@\(String(format: "%.2f", $0.confidence))" })")
        }
        print("SEAM results: \(results)")
        XCTAssertEqual(Set(results).count, 1, "recognition of the same pixels varied: \(results)")
        XCTAssertEqual(results.first, "604/high/Corner Shop")
        #else
        throw XCTSkip("DEBUG-only seam")
        #endif
    }
}
