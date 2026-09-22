//
//  ReceiptScanGuardTests.swift
//  FinanceTrackerTests
//
//  Three guards for DESIGN_RECEIPT_SCAN.md: nothing in the scan module can
//  reach the network; Vision's language support is asked, not assumed; and the
//  five-free-scans-per-month cap counts what it says it counts.
//

import Foundation
import Testing
import Vision
@testable import FinanceTracker

// MARK: - No network, as a test rather than a sentence

@Suite("The scan module cannot reach the network")
struct NoNetworkInScanModuleTests {

    private static let scannedDirectories = ["FinanceTracker/Services/ReceiptScan", "FinanceTracker/Views/ReceiptScan"]
    private static let forbidden = ["URLSession", "URLRequest", "import Network", "NWConnection", "CloudKit", "CKContainer",
                                    "MLModel", "CoreML", "NSURLConnection", "WebKit", "http://", "https://"]

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test("no networking, cloud or model-download symbol appears in the scan module")
    func scanModuleIsOffline() throws {
        let root = repoRoot()
        var scanned = 0
        var hits: [String] = []
        for dir in Self.scannedDirectories {
            let url = root.appendingPathComponent(dir)
            var isDir: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue,
                    "scan directory \(dir) is missing — this guard is scanning nothing")
            let e = try #require(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
            for case let file as URL in e where file.pathExtension == "swift" {
                scanned += 1
                let source = try String(contentsOf: file, encoding: .utf8)
                for (n, raw) in source.components(separatedBy: .newlines).enumerated() {
                    let line = raw.range(of: "//").map { String(raw[..<$0.lowerBound]) } ?? raw
                    for word in Self.forbidden where line.contains(word) {
                        hits.append("\(dir)/\(file.lastPathComponent):\(n + 1) \(word)")
                    }
                }
            }
        }
        #expect(scanned >= 4, "scanned only \(scanned) files — the module moved")
        #expect(hits.isEmpty, Comment(rawValue: "the scan module reaches out:\n" + hits.joined(separator: "\n")))
    }
}

// MARK: - Vision language support: asked in code, recorded, never assumed

@Suite("Vision recognition languages, on this OS")
struct VisionLanguageSupportTests {

    @Test("the four Latin/Cyrillic locales we ship are usable; Ukrainian's status is REPORTED, not assumed")
    func languages() throws {
        let supported = Set(try ReceiptRecognizer.supportedLanguages())
        #expect(!supported.isEmpty)
        func has(_ code: String) -> Bool { supported.contains(code) || supported.contains(String(code.prefix(2))) }
        #expect(has("en-US")); #expect(has("ru-RU")); #expect(has("es-ES")); #expect(has("pt-BR"))
        #expect(!supported.contains("es-MX"), "Vision grew an es-MX model — revisit preferredLanguages")
        // Ukrainian: the founder's decision 4 — if absent, recognise with ru + en and
        // MEASURE. The fallback chain must then still be non-empty and contain both.
        let uk = try ReceiptRecognizer.usableLanguages(appLanguageCode: "uk")
        #expect(uk.contains("ru-RU") && uk.contains("en-US"))
        // Recorded on every run so the fact is in the log, not in anyone's memory.
        // (An `Issue.record` would fail the test; a passing expectation with the
        // value in its message is invisible. So the fact is asserted as a fact:)
        let ukSupported = has("uk-UA")
        #expect(ukSupported == ukSupported, Comment(rawValue: "uk-UA supported by Vision here: \(ukSupported); usable for uk app: \(uk)"))
        #expect(uk.first == (ukSupported ? "uk-UA" : "ru-RU"))
    }

    @Test("the app language goes first, the other four follow")
    func ordering() {
        #expect(ReceiptRecognizer.preferredLanguages(appLanguageCode: "ru").first == "ru-RU")
        #expect(ReceiptRecognizer.preferredLanguages(appLanguageCode: "pt").first == "pt-BR")
        #expect(ReceiptRecognizer.preferredLanguages(appLanguageCode: nil).first == "en-US")
        #expect(ReceiptRecognizer.preferredLanguages(appLanguageCode: "es").count == 5)
    }
}

// MARK: - The counted cap

@Suite("Five free scans per month (S1)")
struct ReceiptScanQuotaTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    @Test("scans are counted per calendar month and the cap is FreeTierLimits.freeScansPerMonth")
    func countsPerMonth() {
        let suite = "ReceiptScanQuotaTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        let sep = date(2026, 9, 21), oct = date(2026, 10, 1)
        #expect(ReceiptScanQuota.count(defaults: d, now: sep, calendar: cal) == 0)
        for i in 1...5 { #expect(ReceiptScanQuota.recordScan(defaults: d, now: sep, calendar: cal) == i) }
        #expect(ReceiptScanQuota.count(defaults: d, now: sep, calendar: cal) == 5)
        #expect(ReceiptScanQuota.count(defaults: d, now: oct, calendar: cal) == 0, "a new month starts at zero")
        #expect(ReceiptScanQuota.monthKey(now: sep, calendar: cal) == "receiptScan.count.2026-09")
    }

    @Test("free: the sixth scan is refused; premium: never refused")
    func gate() {
        #expect(AppCapability.receiptScan.requiresPremium)
        #expect(AppCapability.receiptScan.freeLimit == FreeTierLimits.freeScansPerMonth)
        #expect(FreeTierLimits.freeScansPerMonth == 5)
        #expect(AccessLogic.canAdd(.receiptScan, isPremium: false, currentCount: 4))
        #expect(!AccessLogic.canAdd(.receiptScan, isPremium: false, currentCount: 5))
        #expect(AccessLogic.canAdd(.receiptScan, isPremium: true, currentCount: 500))
    }

    @Test("the scanner is not on the paywall until it ships")
    func unshipped() {
        #expect(PaywallComparison.unshippedCapabilities.contains(.receiptScan))
        #expect(!PaywallComparison.rows.contains { $0.capability == .receiptScan })
    }
}

// MARK: - The form's date window is one definition

@Suite("Scanned dates respect the form's window")
struct AddTransactionPrefillDateTests {
    @Test("the window is 1990-01-01 … now + 1 year, in one place")
    func window() {
        let now = Date()
        #expect(Calendar.current.component(.year, from: AddTransactionView.minDate) == 1990)
        #expect(abs(AddTransactionView.maxDate(now: now).timeIntervalSince(Calendar.current.date(byAdding: .year, value: 1, to: now)!)) < 1)
        let p = AddTransactionPrefill(typeRaw: "expense", amountText: "12.34", merchant: "Cafe",
                                      categoryUUID: nil, sourceUUID: nil, recurrence: nil,
                                      date: now, note: nil, origin: .receiptScan)
        #expect(p.origin == .receiptScan && p.date == now)
        let legacy = AddTransactionPrefill(typeRaw: "expense", amountText: "1", merchant: "", categoryUUID: nil, sourceUUID: nil, recurrence: nil)
        #expect(legacy.date == nil && legacy.origin == .edit, "existing call sites are unchanged")
    }
}
