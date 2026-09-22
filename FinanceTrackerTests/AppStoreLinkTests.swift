//
//  AppStoreLinkTests.swift
//  FinanceTrackerTests
//
//  D7: "Rate the app" and "Tell a friend" shipped with `idTBD` in the App Store
//  URL from 1.0.0 through 1.0.4, landing users on an App Store error page. The
//  fix was a one-liner with no test, so it could come back as one. This pins the
//  real ID — the one `itunes.apple.com/lookup` resolves to Budget Crab — and
//  asserts its PRESENCE rather than the absence of "TBD".
//
//  Commissioned red 2026-09-21 by substituting the competitor ID 6758524287.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("App Store link")
struct AppStoreLinkTests {

    /// Budget Crab's App ID. 6758524287 is a COMPETITOR's — see the App-ID audit.
    static let budgetCrabAppID = "6784424678"

    @Test("the App Store URL carries Budget Crab's real App ID")
    @MainActor
    func appStoreURLCarriesTheRealID() {
        let url = AboutView.appStoreURL
        #expect(url.host == "apps.apple.com")
        #expect(url.lastPathComponent == "id" + Self.budgetCrabAppID)
    }
}
