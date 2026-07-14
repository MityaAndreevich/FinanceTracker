//
//  PaywallComparisonTests.swift
//  FinanceTrackerTests
//
//  The paywall's free-vs-Premium table is the most dangerous copy in the app: it
//  is the one place we make a legally-binding claim about what money buys. These
//  tests pin the claims to the gates that actually enforce them.
//
//  The point is not that the table is *pretty*. It is that the table cannot lie —
//  not when someone raises a cap, not when someone flips a capability to free, and
//  not when someone lists a feature that hasn't shipped.
//

import Testing
import Foundation
@testable import FinanceTracker

@Suite("The paywall table says exactly what the gates enforce")
struct PaywallComparisonTests {

    // MARK: - The table cannot contradict the gate

    /// The whole reason `PaywallComparison` derives its cells instead of storing
    /// them. A free-forever capability shows a check in the Free column; a premium
    /// one shows a dash. There is no third possibility and no hand-written cell to
    /// get wrong.
    @Test("Every row's Free column matches AppCapability.requiresPremium")
    func freeColumnMatchesTheRealGate() {
        for row in PaywallComparison.rows where row.capability.freeLimit == nil {
            let expected: PaywallComparison.Value =
                row.capability.requiresPremium ? .excluded : .included
            #expect(row.free == expected,
                    "\(row.labelKey) advertises \(row.free) but the gate says requiresPremium=\(row.capability.requiresPremium)")
        }
    }

    /// Premium is a superset of Free by construction. A row that showed a dash in
    /// the Premium column would mean we took money for nothing.
    @Test("No row withholds anything from Premium")
    func premiumNeverExcludes() {
        for row in PaywallComparison.rows {
            #expect(row.premium != .excluded, "\(row.labelKey) is excluded on Premium")
        }
    }

    /// The counted caps print the numbers the gate counts against — not a number
    /// someone typed into a strings file and forgot when the cap moved.
    @Test("Cap rows print the real FreeTierLimits numbers")
    func capRowsShowRealLimits() throws {
        let accounts = try #require(comparisonRow(for: .addAccountBeyondFreeCap))
        #expect(accounts.free == .count(FreeTierLimits.maxAccounts))
        #expect(accounts.premium == .unlimited)

        let categories = try #require(comparisonRow(for: .addCustomCategoryBeyondFreeCap))
        #expect(categories.free == .count(FreeTierLimits.maxCustomCategories))
        #expect(categories.premium == .unlimited)
    }

    // MARK: - The table cannot over-promise

    /// iCloud sync ships in 1.0.3. Its *gate* exists today, which is exactly what
    /// makes it easy to list by accident — and a paywall may only name things the
    /// user can use the moment the card is charged.
    @Test("No row names a capability that hasn't shipped")
    func noUnshippedCapabilityIsAdvertised() {
        for row in PaywallComparison.rows {
            #expect(!PaywallComparison.unshippedCapabilities.contains(row.capability),
                    "\(row.labelKey) advertises unshipped \(row.capability)")
        }
    }

    /// A regression guard on the specific lie we shipped once already: transactions,
    /// history and CSV export are free, and the table must keep saying so. If a
    /// future commit gates any of these, this test fails *before* the copy does.
    @Test("The free promises are still promised as free")
    func freePromisesStayFree() throws {
        for capability in [AppCapability.manualEntry,
                           .fullHistory,
                           .basicAnalytics,
                           .widget,
                           .exportCSVAll] {
            let row = try #require(comparisonRow(for: capability),
                                   "\(capability) dropped off the paywall table")
            #expect(row.free == .included, "\(capability) is no longer shown as free")
        }
    }

    /// The four things money actually buys, each present and each shown as paid.
    @Test("The real premium gates are all listed, and listed as paid")
    func premiumGatesAreListed() throws {
        for capability in [AppCapability.csvImport,
                           .exportPDFAll,
                           .proactiveAlerts] {
            let row = try #require(comparisonRow(for: capability),
                                   "\(capability) is gated but never named on the paywall")
            #expect(row.free == .excluded)
            #expect(row.premium == .included)
        }
    }

    // MARK: - Copy exists in every shipping locale

    /// A missing translation renders the raw key ("paywall.compare.row.accounts")
    /// straight into the table, which looks like a bug and reads like a scam.
    @Test("Every row label and cell word is translated in all 5 locales",
          arguments: ["en", "ru", "uk", "es", "pt-BR"])
    func everyLabelIsLocalized(locale: String) throws {
        let strings = try #require(Self.strings(for: locale), "missing \(locale).lproj")

        var keys = PaywallComparison.rows.map(\.labelKey)
        keys += [
            "paywall.compare.header",
            "paywall.compare.free",
            "paywall.compare.premium",
            "paywall.compare.value.included",
            "paywall.compare.value.excluded",
            "paywall.compare.value.unlimited",
            "paywall.compare.a11y.format",
            "paywall.data_safety.title",
            "paywall.data_safety.body",
        ]

        for key in keys {
            let value = strings[key]
            #expect(value != nil, "\(locale) is missing \(key)")
            #expect(value?.isEmpty == false, "\(locale) has \(key) but it is blank")
        }
    }

    /// The reassurance is worthless if it doesn't actually say the reassuring part.
    /// This is a blunt check, but it catches the failure mode that matters: a
    /// translator shortening the promise into "Upgrade to keep your data", which
    /// would invert its meaning.
    @Test("The data-safety promise is a real sentence, not a stub",
          arguments: ["en", "ru", "uk", "es", "pt-BR"])
    func dataSafetyPromiseIsSubstantive(locale: String) throws {
        let strings = try #require(Self.strings(for: locale))
        let body = try #require(strings["paywall.data_safety.body"])
        #expect(body.count > 60, "\(locale) data-safety promise is too short to be the promise")
    }

    // MARK: - Helpers

    private func comparisonRow(for capability: AppCapability) -> PaywallComparison.Row? {
        PaywallComparison.rows.first { $0.capability == capability }
    }

    /// Reads the on-disk table for one locale rather than going through
    /// `localizedString`, which would silently fall back to English and make a
    /// missing translation look present.
    private static func strings(for locale: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable",
                                          ofType: "strings",
                                          inDirectory: nil,
                                          forLocalization: locale),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String]
        else { return nil }
        return dict
    }
}
