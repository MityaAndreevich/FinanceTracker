//
//  FreeTierLimits.swift
//  FinanceTracker
//
//  The single source of truth for the free/paid line (v1.0.2 monetization).
//
//  Two rules govern everything in this file:
//
//  1. Caps only ever block ADDING a NEW item. They never delete, hide, lock or
//     downgrade anything the user already created. A user who built 6 accounts
//     during the reverse trial keeps all 6 visible and editable forever — they
//     just cannot add a 7th until they subscribe. Their data is never hostage.
//
//  2. History and CSV export are free in every state. The escape hatch out of
//     this app is never gated; that is the whole brand.
//

import Foundation

/// Free-tier ceilings. Deliberately expressed as tunable constants rather than
/// scattered magic numbers: these thresholds are a launch guess and are expected
/// to move once we have conversion + gate-fire metrics from real users.
enum FreeTierLimits {

    /// Accounts (`Source`) a non-premium user may create. Nothing is seeded, so
    /// a free user starts at 0 and can build the minimal realistic setup
    /// (e.g. cash + card) before the gate fires on the 3rd.
    static let maxAccounts = 2

    /// User-created (`isUserDefined`) categories a non-premium user may add,
    /// ON TOP of the 13 seeded defaults, which are always available.
    static let maxCustomCategories = 3
}

/// Every capability whose availability depends on entitlement, plus the ones we
/// deliberately promise to keep free. Listing the free ones here — instead of
/// leaving them as an absence — is what lets the tests assert that history,
/// CSV export and the widget can never silently drift behind the paywall.
enum AppCapability: CaseIterable {

    // MARK: Free forever

    case manualEntry
    case quickAdd
    case fullHistory
    case basicAnalytics
    case widget

    /// CSV is the raw-data escape hatch: free at every scope.
    case exportCSVMonth
    case exportCSVAll

    /// Month-scoped export of every format stays free.
    case exportPDFMonth
    case exportExcelMonth

    // MARK: Premium

    /// The flexible column-mapping import flow.
    case csvImport

    /// All-time PDF / Excel are presentation conveniences, not the escape hatch.
    case exportPDFAll
    case exportExcelAll

    case addAccountBeyondFreeCap
    case addCustomCategoryBeyondFreeCap

    // MARK: Premium hooks — NOT built yet

    /// Declared so the gate exists the day the feature lands. Do not build here.
    case iCloudSync
    case proactiveAlerts

    var requiresPremium: Bool {
        switch self {
        case .manualEntry, .quickAdd, .fullHistory, .basicAnalytics, .widget,
             .exportCSVMonth, .exportCSVAll,
             .exportPDFMonth, .exportExcelMonth:
            return false

        case .csvImport,
             .exportPDFAll, .exportExcelAll,
             .addAccountBeyondFreeCap, .addCustomCategoryBeyondFreeCap,
             .iCloudSync, .proactiveAlerts:
            return true
        }
    }

    /// How many of this thing a free user may own. `nil` = not a counted cap.
    var freeLimit: Int? {
        switch self {
        case .addAccountBeyondFreeCap:         return FreeTierLimits.maxAccounts
        case .addCustomCategoryBeyondFreeCap:  return FreeTierLimits.maxCustomCategories
        default:                               return nil
        }
    }
}
