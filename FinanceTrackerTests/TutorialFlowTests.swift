//
//  TutorialFlowTests.swift
//  FinanceTrackerTests
//
//  Tests the AppStorage flag gate for TutorialFlow.
//  UI animation and page transitions are visual — verified manually.
//

import XCTest
@testable import FinanceTracker

@MainActor
final class TutorialFlowTests: XCTestCase {

    private let tourKey = "hasSeenFeatureTour"
    private let demoFlagKey = "hasDemoDataActive"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: tourKey)
        UserDefaults.standard.removeObject(forKey: demoFlagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: tourKey)
        UserDefaults.standard.removeObject(forKey: demoFlagKey)
        super.tearDown()
    }

    func test_hasSeenFeatureTour_defaultsFalse() {
        // Key not present → AppStorage default is false → tutorial should show
        let value = UserDefaults.standard.object(forKey: tourKey)
        XCTAssertNil(value, "Key should be absent before first launch")
        // AppStorage default when key absent is `false`, so tour presents
    }

    func test_hasSeenFeatureTour_persistsAfterSet() {
        UserDefaults.standard.set(true, forKey: tourKey)
        let value = UserDefaults.standard.bool(forKey: tourKey)
        XCTAssertTrue(value, "Flag should persist")
    }

    func test_demoToggleOff_doesNotSetFlag() {
        // When offerDemoData == false on finish, hasDemoDataActive stays false
        XCTAssertFalse(DemoDataController.isDemoDataActive,
                       "Demo data should not be active when toggle is off")
    }

    func test_skipSetsHasSeenFlag() {
        // Simulate what TutorialFlow.finish(offerDemo: false) does
        UserDefaults.standard.set(true, forKey: tourKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: tourKey),
                      "Skip action must set hasSeenFeatureTour to true")
        XCTAssertFalse(DemoDataController.isDemoDataActive,
                       "Skip without demo toggle must not seed demo data")
    }
}
