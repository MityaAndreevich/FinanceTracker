//
//  RatingPromptCoordinatorTests.swift
//  FinanceTrackerTests
//
//  Tests the business-logic gates on the rating prompt coordinator.
//  SKStoreReviewController cannot be invoked in unit tests (requires a real
//  scene), so tests verify that eligibility logic correctly blocks/allows
//  the prompt by asserting side-effects on UserDefaults.
//

import XCTest
@testable import FinanceTracker

@MainActor
final class RatingPromptCoordinatorTests: XCTestCase {

    private let savedTxCountKey     = "ratingPrompt.savedTxCount"
    private let distinctDaysKey     = "ratingPrompt.distinctDaysSeen"
    private let lastDayKey          = "ratingPrompt.lastDaySeen"
    private let lastPromptKey       = "ratingPrompt.lastDate"
    private let tourKey             = "hasSeenFeatureTour"
    private let demoKey             = "hasDemoDataActive"

    override func setUp() {
        super.setUp()
        // Clean slate before each test
        [savedTxCountKey, distinctDaysKey, lastDayKey, lastPromptKey, tourKey, demoKey]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        [savedTxCountKey, distinctDaysKey, lastDayKey, lastPromptKey, tourKey, demoKey]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - recordTransactionSaved

    func test_recordTransactionSaved_incrementsCount() {
        RatingPromptCoordinator.recordTransactionSaved()
        let count = UserDefaults.standard.integer(forKey: savedTxCountKey)
        XCTAssertEqual(count, 1)

        RatingPromptCoordinator.recordTransactionSaved()
        let count2 = UserDefaults.standard.integer(forKey: savedTxCountKey)
        XCTAssertEqual(count2, 2)
    }

    func test_tutorialNotComplete_blocksPrompt() {
        // Mark tour NOT seen (default), set count to 5 so trigger would fire
        UserDefaults.standard.set(false, forKey: tourKey)
        UserDefaults.standard.set(4, forKey: savedTxCountKey)

        RatingPromptCoordinator.recordTransactionSaved()  // count becomes 5

        // No lastPromptDate should be set (prompt was blocked)
        let prompted = UserDefaults.standard.object(forKey: lastPromptKey)
        XCTAssertNil(prompted, "Prompt should be blocked before tutorial is complete")
    }

    func test_demoDataActive_blocksPrompt() {
        UserDefaults.standard.set(true, forKey: tourKey)     // tour done
        UserDefaults.standard.set(true, forKey: demoKey)     // demo data active
        UserDefaults.standard.set(4, forKey: savedTxCountKey)

        RatingPromptCoordinator.recordTransactionSaved()  // count becomes 5

        let prompted = UserDefaults.standard.object(forKey: lastPromptKey)
        XCTAssertNil(prompted, "Prompt should be blocked during demo data mode")
    }

    func test_quarterlyCooldown_blocksSecondPromptWithin90Days() {
        UserDefaults.standard.set(true, forKey: tourKey)
        // Set last prompt to 30 days ago (within 90-day cooldown)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        UserDefaults.standard.set(thirtyDaysAgo, forKey: lastPromptKey)
        UserDefaults.standard.set(4, forKey: savedTxCountKey)

        let beforeDate = UserDefaults.standard.object(forKey: lastPromptKey) as? Date

        RatingPromptCoordinator.recordTransactionSaved()

        let afterDate = UserDefaults.standard.object(forKey: lastPromptKey) as? Date
        // Date should not have been updated (prompt blocked by cooldown)
        let beforeInterval = beforeDate?.timeIntervalSinceReferenceDate ?? 0
        let afterInterval  = afterDate?.timeIntervalSinceReferenceDate ?? 0
        XCTAssertEqual(beforeInterval, afterInterval, accuracy: 1.0,
                       "Cooldown should prevent new prompt within 90 days")
    }

    // MARK: - recordSessionOpen

    func test_recordSessionOpen_sameDay_doesNotIncrement() {
        let today = Calendar.current.startOfDay(for: .now)
        UserDefaults.standard.set(today, forKey: lastDayKey)
        UserDefaults.standard.set(2, forKey: distinctDaysKey)

        RatingPromptCoordinator.recordSessionOpen()

        let days = UserDefaults.standard.integer(forKey: distinctDaysKey)
        XCTAssertEqual(days, 2, "Same-day call must not increment distinct-day counter")
    }

    func test_recordSessionOpen_differentDay_increments() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        UserDefaults.standard.set(yesterday, forKey: lastDayKey)
        UserDefaults.standard.set(1, forKey: distinctDaysKey)

        RatingPromptCoordinator.recordSessionOpen()

        let days = UserDefaults.standard.integer(forKey: distinctDaysKey)
        XCTAssertEqual(days, 2, "Different day call should increment counter")
    }

    // MARK: - resetForTutorialReplay

    func test_resetForTutorialReplay_clearsCountersButNotCooldown() {
        let ninetyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        UserDefaults.standard.set(5, forKey: savedTxCountKey)
        UserDefaults.standard.set(3, forKey: distinctDaysKey)
        UserDefaults.standard.set(Date(), forKey: lastDayKey)
        UserDefaults.standard.set(ninetyOneDaysAgo, forKey: lastPromptKey)

        RatingPromptCoordinator.resetForTutorialReplay()

        XCTAssertEqual(UserDefaults.standard.integer(forKey: savedTxCountKey), 0,
                       "savedTxCount should be cleared")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: distinctDaysKey), 0,
                       "distinctDays should be cleared")
        XCTAssertNil(UserDefaults.standard.object(forKey: lastDayKey),
                     "lastDaySeen should be cleared")

        // Cooldown date must survive reset
        let cooldownDate = UserDefaults.standard.object(forKey: lastPromptKey)
        XCTAssertNotNil(cooldownDate, "Quarterly cooldown date must NOT be cleared by replay reset")
    }
}
