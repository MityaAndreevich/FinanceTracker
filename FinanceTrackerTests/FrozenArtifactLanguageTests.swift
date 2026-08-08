//
//  FrozenArtifactLanguageTests.swift
//  FinanceTrackerTests
//
//  TIER 1 of the `String(localized:)` staleness fix (Overnight 2026-08-05, Item 4a).
//
//  `LocalizedBundlePremiseTests` establishes the DEFECT: `String(localized:)`
//  ignores the in-app language override and keeps returning the launch language
//  for the rest of the process. This file is about the CONSEQUENCE, and it is a
//  different severity claim:
//
//      Session-scoped staleness is cosmetic — the next cold launch fixes it.
//      Staleness baked into an artifact that OUTLIVES the session is not.
//
//  Three producers bake it in:
//    * `ProactiveAlertScheduler` — a local notification's body is FROZEN at
//      schedule time. Switch to Russian and the reminder still arrives in
//      English, days later, when the app is not even running.
//    * `RecurrenceService`       — same mechanism, same freeze.
//    * `PDFExportService`        — a document the user keeps or forwards.
//
//  These tests drive the REAL production functions under the real override and
//  read the language back out of the artifact they produce. That is the whole
//  point: the premise tests measure a resolution path, these measure the thing
//  the user actually receives.
//
//  METHOD, inherited from LocalizedBundlePremiseTests: no process-locale string
//  is ever asserted. Every expected value is read straight out of `ru.lproj` and
//  compared against THAT, so the test says "the artifact agrees with the Russian
//  table" rather than "this equals «Отчёт»", which would depend on the machine.
//
//  @MainActor and .serialized are REQUIRED, not tidiness — `setLanguage` mutates
//  a `@Published` that the live host app's SwiftUI tree observes, and off the
//  main actor that crashed the host process AFTER a green suite. See the header
//  of LocalizedBundlePremiseTests.
//

import Foundation
import PDFKit
import SwiftData
import Testing
import UserNotifications
@testable import FinanceTracker

@Suite("Frozen artifacts honor the in-app language override", .serialized)
@MainActor
struct FrozenArtifactLanguageTests {

    // MARK: - Oracle

    /// The Russian value, read straight out of ru.lproj.
    private func russian(_ key: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: "ru", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        #expect(value != key, "precondition: \(key) must exist in ru.lproj")
        return value
    }

    private func english(_ key: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Asserts the key is actually a discriminator before relying on it. A key
    /// whose Russian and English values are identical (`alerts.notif.title` is
    /// "Budget Crab" in both) makes a language assertion vacuously true.
    private func requireTranslated(_ key: String) throws {
        #expect(try russian(key) != english(key),
                "precondition: \(key) must differ between ru and en, or this test proves nothing")
    }

    private func withRussian(_ body: () throws -> Void) rethrows {
        LocalizedBundle.shared.setLanguage("ru")
        defer { LocalizedBundle.shared.setLanguage("system") }
        try body()
    }

    // MARK: - ProactiveAlertScheduler (4 sites)

    @Test("a weekly alert scheduled after a switch to Russian has a Russian body")
    func proactiveAlertBodyHonorsTheOverride() throws {
        // NOT the title: `alerts.notif.title` is "Budget Crab" in every locale, so
        // asserting on it would pass no matter what the bundle resolved to.
        try requireTranslated("alerts.notif.body.safe.format")
        let format = try russian("alerts.notif.body.safe.format")
        let expected = String(format: format, Money.format(cents: 60_000, currencyCode: "USD"))

        try withRussian {
            let center = FakeNotificationCenter()
            ProactiveAlertScheduler.apply(
                plan: .init(
                    fireDate: Date().addingTimeInterval(3 * 24 * 3600),
                    body: .safeToSpend(amountCents: 60_000)
                ),
                currencyCode: "USD",
                center: center
            )

            let request = try #require(center.added.first)
            #expect(
                request.content.body == expected,
                "the notification body is frozen at schedule time — it arrives in the launch language"
            )
        }
    }

    @Test("the category-limit alert body honors the override too")
    func categoryLimitAlertBodyHonorsTheOverride() throws {
        try requireTranslated("alerts.notif.body.limit.format")
        let format = try russian("alerts.notif.body.limit.format")
        let expected = String(
            format: format,
            Money.format(cents: 12_000, currencyCode: "USD"),
            "Dining"
        )

        try withRussian {
            let center = FakeNotificationCenter()
            ProactiveAlertScheduler.apply(
                plan: .init(
                    fireDate: Date().addingTimeInterval(3 * 24 * 3600),
                    body: .categoryLimit(categoryUUID: UUID(), categoryName: "Dining", remainingCents: 12_000)
                ),
                currencyCode: "USD",
                center: center
            )

            let request = try #require(center.added.first)
            #expect(request.content.body == expected)
        }
    }

    // MARK: - RecurrenceService (3 sites)

    @Test("a recurring reminder composed after a switch to Russian is Russian")
    func recurringReminderHonorsTheOverride() throws {
        try requireTranslated("recurring.notif.title")
        try requireTranslated("recurring.notif.body")
        let expectedTitle = try russian("recurring.notif.title")
        let expectedBody = String(
            format: try russian("recurring.notif.body"),
            "Netflix",
            Money.format(cents: 1_599, currencyCode: "USD")
        )

        try withRussian {
            let content = RecurrenceService.notificationContent(
                merchant: "Netflix",
                amountCents: 1_599,
                currencyCode: "USD"
            )
            #expect(content.title == expectedTitle)
            #expect(content.body == expectedBody)
        }
    }

    @Test("the merchant fallback in a recurring reminder is localized too")
    func recurringReminderFallbackMerchantHonorsTheOverride() throws {
        try requireTranslated("recurring.notif.fallback_merchant")
        let fallback = try russian("recurring.notif.fallback_merchant")

        try withRussian {
            let content = RecurrenceService.notificationContent(
                merchant: nil,
                amountCents: 1_599,
                currencyCode: "USD"
            )
            #expect(content.body.contains(fallback))
        }
    }

    // MARK: - PDFExportService (10 sites)

    /// The strongest form of this test available: render the real PDF and read
    /// the text back out with PDFKit. A document the user keeps or forwards is
    /// the artifact with the longest life of the three, so it is worth asserting
    /// on the bytes rather than on a helper.
    @Test("a PDF exported after a switch to Russian contains Russian chrome")
    func exportedPDFHonorsTheOverride() throws {
        try requireTranslated("pdf.report.title")
        try requireTranslated("pdf.header.date")
        try requireTranslated("pdf.label.income")
        let title = try russian("pdf.report.title")
        let dateHeader = try russian("pdf.header.date")
        let incomeLabel = try russian("pdf.label.income")
        let englishTitle = try english("pdf.report.title")

        let schema = Schema([Transaction.self, Category.self, Source.self, TransactionSplit.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.insert(
            Transaction(
                typeRaw: "expense",
                amountCents: 2_500,
                currency: "USD",
                date: Date(),
                category: nil,
                merchant: "Coffee"
            )
        )

        try withRussian {
            let result = try PDFExportService.makeMonthlyReportPDF(
                modelContext: context,
                scope: .all,
                currencyCode: "USD"
            )
            let document = try #require(PDFDocument(data: result.data))
            let text = try #require(document.string)

            #expect(text.contains(title), "the report title is in the launch language")
            #expect(text.contains(dateHeader), "the table headers are in the launch language")
            #expect(text.contains(incomeLabel), "the summary labels are in the launch language")
            #expect(
                !text.contains(englishTitle),
                "the English title must be gone, not merely joined by the Russian one"
            )
        }
    }
}
