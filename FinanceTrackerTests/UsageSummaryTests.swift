//
//  UsageSummaryTests.swift
//  FinanceTrackerTests
//
//  The feedback usage summary is a privacy surface, so the tests here are
//  mostly boundary tests on the buckets (an off-by-one turns "51–200" into a
//  claim about the wrong person) plus one structural test that no ledger
//  content can reach the rendered string.
//
//  Note the deliberate absence of a test asserting the ENGLISH text of any
//  label: per the project rule, unit tests never assert process-locale strings.
//  The tests below render through an explicit bundle and assert structure.
//

import XCTest
@testable import FinanceTracker

final class UsageSummaryTests: XCTestCase {

    // MARK: - Transaction buckets

    func test_transactionBucket_boundaries() {
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 0), .none)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 10), .none)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 11), .small)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 50), .small)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 51), .medium)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 200), .medium)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 201), .large)
        XCTAssertEqual(UsageSummary.TransactionBucket(count: 99_999), .large)
    }

    // MARK: - Split buckets

    func test_splitBucket_boundaries() {
        XCTAssertEqual(UsageSummary.SplitBucket(count: 0), .zero)
        XCTAssertEqual(UsageSummary.SplitBucket(count: 1), .few)
        XCTAssertEqual(UsageSummary.SplitBucket(count: 5), .few)
        XCTAssertEqual(UsageSummary.SplitBucket(count: 6), .many)
        XCTAssertEqual(UsageSummary.SplitBucket(count: 4_000), .many)
    }

    /// The pre-test's whole verdict turns on the 6+ bucket (see
    /// DECISION_RECEIPT_INPUT_PRETEST.md §4.2 clause 3), so pin it explicitly.
    func test_splitBucket_sixIsTheHabitualThreshold() {
        XCTAssertEqual(UsageSummary.SplitBucket(count: 5).rawValue, "1–5")
        XCTAssertEqual(UsageSummary.SplitBucket(count: 6).rawValue, "6+")
    }

    // MARK: - Tenure

    func test_tenureBucket_boundaries() {
        XCTAssertEqual(UsageSummary.TenureBucket(months: 0), .underOne)
        XCTAssertEqual(UsageSummary.TenureBucket(months: 1), .oneToThree)
        XCTAssertEqual(UsageSummary.TenureBucket(months: 2), .oneToThree)
        XCTAssertEqual(UsageSummary.TenureBucket(months: 3), .threeToSix)
        XCTAssertEqual(UsageSummary.TenureBucket(months: 6), .sixToTwelve)
        XCTAssertEqual(UsageSummary.TenureBucket(months: 12), .overTwelve)
    }

    /// A never-written `firstLaunchDate` must NOT report "12+" — that would be
    /// a lie in the loud direction, and it is the state every pre-1.0.4
    /// install with a wiped defaults domain is in.
    func test_monthsSinceFirstLaunch_missingKeyReportsNewest() {
        let months = UsageSummaryBuilder.monthsSinceFirstLaunch(
            firstLaunchInterval: 0,
            now: Date(),
            calendar: .current
        )
        XCTAssertEqual(months, 0)
        XCTAssertEqual(UsageSummary.TenureBucket(months: months), .underOne)
    }

    /// Clock skew (user moved the device date backwards) must not produce a
    /// negative month count.
    func test_monthsSinceFirstLaunch_futureFirstLaunchClampsToZero() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let future = now.addingTimeInterval(60 * 60 * 24 * 90)
        let months = UsageSummaryBuilder.monthsSinceFirstLaunch(
            firstLaunchInterval: future.timeIntervalSinceReferenceDate,
            now: now,
            calendar: .current
        )
        XCTAssertEqual(months, 0)
    }

    func test_monthsSinceFirstLaunch_countsWholeMonths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = DateComponents(calendar: calendar, year: 2026, month: 1, day: 15).date!
        let now = DateComponents(calendar: calendar, year: 2026, month: 8, day: 2).date!
        let months = UsageSummaryBuilder.monthsSinceFirstLaunch(
            firstLaunchInterval: first.timeIntervalSinceReferenceDate,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(months, 6)
        XCTAssertEqual(UsageSummary.TenureBucket(months: months), .sixToTwelve)
    }

    // MARK: - Rendering

    private func sampleSummary() -> UsageSummary {
        UsageSummary(
            transactions: .medium,
            splitTransactions: .few,
            splitsEverUsed: true,
            tenure: .threeToSix,
            usedRecurring: true,
            usedCategoryLimits: false,
            usedVoiceEntry: true,
            usedCSVImport: false,
            usedExport: true
        )
    }

    /// Line ORDER is contractual — the decision file tells whoever reads a
    /// Ukrainian reply that line 3 is the transaction bucket. Reordering the
    /// render without updating that file silently corrupts the dataset.
    func test_render_lineOrderAndCountAreStable() {
        let text = sampleSummary().render(bundle: .main)
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasPrefix("—") }

        // heading + 8 fields
        XCTAssertEqual(lines.count, 9, "Summary shape changed:\n\(text)")

        // Values are locale-neutral, so they can be asserted regardless of the
        // bundle's language.
        XCTAssertTrue(lines[1].hasSuffix("3–6"), "line 1 must be tenure: \(lines[1])")
        XCTAssertTrue(lines[2].hasSuffix("51–200"), "line 2 must be transactions: \(lines[2])")
        XCTAssertTrue(lines[3].hasSuffix("1–5"), "line 3 must be splits: \(lines[3])")
    }

    /// The load-bearing privacy invariant: the rendered block must be
    /// constructible ONLY from buckets and booleans. If someone adds a field
    /// carrying a merchant, a category name, an amount or a date, this fails.
    func test_render_containsNoDigitsBeyondBucketBoundaries() {
        let text = sampleSummary().render(bundle: .main)
        let numbers = text
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
        // Every number in the output must be a bucket boundary literal.
        let allowed: Set<String> = ["3", "6", "51", "200", "1", "5", "0", "11", "50", "10", "12"]
        for number in numbers {
            XCTAssertTrue(
                allowed.contains(number),
                "Unexpected number '\(number)' in the usage summary — that is how a count or an amount leaks:\n\(text)"
            )
        }
    }

    /// An exact count is a fingerprint. Assert we never emit one.
    func test_render_neverContainsAnExactCount() {
        let summary = UsageSummary(
            transactions: .init(count: 137),
            splitTransactions: .init(count: 43),
            splitsEverUsed: true,
            tenure: .init(months: 7),
            usedRecurring: false,
            usedCategoryLimits: false,
            usedVoiceEntry: false,
            usedCSVImport: false,
            usedExport: false
        )
        let text = summary.render(bundle: .main)
        XCTAssertFalse(text.contains("137"))
        XCTAssertFalse(text.contains("43"))
        XCTAssertTrue(text.contains("51–200"))
        XCTAssertTrue(text.contains("6+"))
        XCTAssertTrue(text.contains("6–12"))
    }

    // MARK: - Flags

    func test_featureUsageSignals_defaultFalseAndStick() {
        FeatureUsageSignals.resetAll()
        for feature in FeatureUsageSignals.Feature.allCases {
            XCTAssertFalse(FeatureUsageSignals.wasUsed(feature), "\(feature) should default to false")
        }

        FeatureUsageSignals.markUsed(.voiceEntry)
        XCTAssertTrue(FeatureUsageSignals.wasUsed(.voiceEntry))
        XCTAssertFalse(FeatureUsageSignals.wasUsed(.export))

        // Idempotent.
        FeatureUsageSignals.markUsed(.voiceEntry)
        XCTAssertTrue(FeatureUsageSignals.wasUsed(.voiceEntry))

        FeatureUsageSignals.resetAll()
    }

    /// Renaming a case silently resets every install to "never used", which
    /// would look like a real drop in the pre-test data.
    func test_featureUsageSignals_rawValuesAreFrozen() {
        XCTAssertEqual(FeatureUsageSignals.Feature.splits.rawValue, "splits")
        XCTAssertEqual(FeatureUsageSignals.Feature.recurring.rawValue, "recurring")
        XCTAssertEqual(FeatureUsageSignals.Feature.categoryLimits.rawValue, "category_limits")
        XCTAssertEqual(FeatureUsageSignals.Feature.voiceEntry.rawValue, "voice_entry")
        XCTAssertEqual(FeatureUsageSignals.Feature.csvImport.rawValue, "csv_import")
        XCTAssertEqual(FeatureUsageSignals.Feature.export.rawValue, "export")
        XCTAssertEqual(FeatureUsageSignals.Feature.allCases.count, 6)
    }
}
