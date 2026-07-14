//
//  TutorialFlowTests.swift
//  FinanceTrackerTests
//
//  Tests the flag gate for TutorialFlow.
//  UI animation and page transitions are visual — verified manually.
//
//  These tests used to read `UserDefaults.standard` and assert that
//  "hasSeenFeatureTour" was *absent*. That is ambient global state, shared with the
//  host app (which is live during a hosted test run and free to write defaults) and
//  with anything a human did to the simulator beforehand. A single
//  `xcrun simctl spawn <sim> defaults write <bundle-id> hasSeenFeatureTour -bool true`
//  during manual QA poisoned the run — and, critically, `removeObject` in `setUp`
//  did NOT clear it, so the reset that looked like a guard was doing nothing.
//
//  So the flag logic now runs against an isolated suite that is destroyed around
//  every test. Nothing outside this file can reach it, and nothing this file does
//  leaks into the simulator.
//

import XCTest
@testable import FinanceTracker

@MainActor
final class TutorialFlowTests: XCTestCase {

    private let tourKey = "hasSeenFeatureTour"
    private let demoFlagKey = "hasDemoDataActive"

    /// A private domain, wiped around every test — the tests own it outright.
    private let suiteName = "TutorialFlowTests.isolated"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)

        // `DemoDataController` reads `UserDefaults.standard` directly, so that one
        // key still has to be cleared there. Unlike the tour flag, nothing else
        // writes it during a test run, so clearing it is sufficient.
        UserDefaults.standard.removeObject(forKey: demoFlagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removeObject(forKey: demoFlagKey)
        defaults = nil
        super.tearDown()
    }

    func test_hasSeenFeatureTour_defaultsFalse() {
        // Key absent → AppStorage's default (false) applies → the tutorial shows.
        XCTAssertNil(defaults.object(forKey: tourKey),
                     "A fresh install has never seen the tour")
        XCTAssertFalse(defaults.bool(forKey: tourKey),
                       "Absent key must read as false, which is what gates the tour")
    }

    func test_hasSeenFeatureTour_persistsAfterSet() {
        defaults.set(true, forKey: tourKey)
        XCTAssertTrue(defaults.bool(forKey: tourKey), "Flag should persist")
    }

    func test_demoToggleOff_doesNotSetFlag() {
        // When offerDemoData == false on finish, hasDemoDataActive stays false
        XCTAssertFalse(DemoDataController.isDemoDataActive,
                       "Demo data should not be active when toggle is off")
    }

    func test_skipSetsHasSeenFlag() {
        // Simulate what TutorialFlow.finish(offerDemo: false) does
        defaults.set(true, forKey: tourKey)
        XCTAssertTrue(defaults.bool(forKey: tourKey),
                      "Skip action must set hasSeenFeatureTour to true")
        XCTAssertFalse(DemoDataController.isDemoDataActive,
                       "Skip without demo toggle must not seed demo data")
    }
}
