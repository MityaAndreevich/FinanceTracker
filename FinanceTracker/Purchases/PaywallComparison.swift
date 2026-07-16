//
//  PaywallComparison.swift
//  FinanceTracker
//
//  The free-vs-Premium table shown on the paywall.
//
//  The one rule that makes this file worth existing: **no cell is hand-typed.**
//  A row names a capability and a label key; whether the Free column shows a
//  check, a dash, or a number is *derived* from `AppCapability.requiresPremium`
//  and `AppCapability.freeLimit` — the same values the gates themselves read.
//
//  That is deliberate. The previous feature list drifted into advertising
//  "custom fields" and "advanced filters", which the app has never had, and
//  "unlimited transactions" as a paid perk when it is free. Copy that is typed
//  by hand next to a gate that is enforced in code will always drift, and for an
//  app whose entire pitch is honest billing, drifting in the direction of
//  over-promising is the worst bug we can ship. Here, raising `maxAccounts` to 3
//  or flipping a capability to free changes this table in the same commit,
//  because there is no second copy of the truth to forget.
//

import Foundation

enum PaywallComparison {

    /// What one cell of the table says.
    enum Value: Equatable {
        /// A plain checkmark: you get this.
        case included
        /// A dash: you don't. Never rendered as a red ✗ — the free column is not
        /// a list of failures.
        case excluded
        /// A hard ceiling on a counted thing ("2" accounts).
        case count(Int)
        /// No ceiling. Rendered as ∞ rather than the word, which would wrap the
        /// narrow value column in every locale with a long word for "unlimited".
        case unlimited
    }

    struct Row: Identifiable, Equatable {
        /// The gate this row describes. The single input the cells derive from.
        let capability: AppCapability
        /// Localization key for the row's left-hand label.
        let labelKey: String

        var id: String { labelKey }

        /// A counted capability shows its ceiling; everything else shows whether
        /// a free user has it at all.
        var free: Value {
            if let limit = capability.freeLimit { return .count(limit) }
            return capability.requiresPremium ? .excluded : .included
        }

        /// Premium lifts counted caps and includes everything else. There is no
        /// capability Premium lacks, so no row can ever be `.excluded` here.
        var premium: Value {
            capability.freeLimit == nil ? .included : .unlimited
        }
    }

    /// Free promises first, then what paying actually adds.
    ///
    /// Ordering is a claim in itself: a user scanning top-down should see how much
    /// they keep for nothing *before* they see what costs money.
    ///
    /// `.iCloudSync` is deliberately absent. Its gate exists (`AppCapability`
    /// declares it so the check is ready), but the feature ships in 1.0.3, and a
    /// paywall may only name things the user can use the moment they pay.
    static let rows: [Row] = [
        Row(capability: .manualEntry,
            labelKey: "paywall.compare.row.transactions"),
        Row(capability: .fullHistory,
            labelKey: "paywall.compare.row.history"),
        Row(capability: .basicAnalytics,
            labelKey: "paywall.compare.row.analytics"),
        Row(capability: .widget,
            labelKey: "paywall.compare.row.widget"),
        Row(capability: .exportCSVAll,
            labelKey: "paywall.compare.row.csv_export"),
        Row(capability: .addAccountBeyondFreeCap,
            labelKey: "paywall.compare.row.accounts"),
        Row(capability: .addCustomCategoryBeyondFreeCap,
            labelKey: "paywall.compare.row.categories"),
        Row(capability: .csvImport,
            labelKey: "paywall.compare.row.csv_import"),
        // CAVEAT: this label says "PDF & Excel" but derives from ONE capability.
        // That is the single crack in this file's no-second-copy rule, and it is
        // acceptable only while `.exportExcelAll` is gated identically —
        // `PaywallComparisonTests.excelSharesThePDFGate` fails the moment the
        // two diverge, at which point Excel needs its own row.
        Row(capability: .exportPDFAll,
            labelKey: "paywall.compare.row.reports_alltime"),
        Row(capability: .proactiveAlerts,
            labelKey: "paywall.compare.row.alerts"),
    ]

    /// Capabilities whose gate exists but whose feature has not shipped. A row for
    /// any of these is a promise we cannot keep on the day the card is charged.
    static let unshippedCapabilities: Set<AppCapability> = [.iCloudSync]
}

// MARK: - Spoken form

extension PaywallComparison.Value {

    /// VoiceOver reads the meaning, not the glyph: "∞" and "—" are useless spoken,
    /// and a bare "2" in the accounts row is ambiguous without its column.
    var accessibilityText: String {
        switch self {
        case .included:
            return NSLocalizedString("paywall.compare.value.included", comment: "")
        case .excluded:
            return NSLocalizedString("paywall.compare.value.excluded", comment: "")
        case .unlimited:
            return NSLocalizedString("paywall.compare.value.unlimited", comment: "")
        case .count(let n):
            return n.formatted(.number)
        }
    }
}

extension PaywallComparison.Row {

    /// "Accounts. Free: 2. Premium: unlimited." — the whole row in one utterance,
    /// because a VoiceOver user swiping cell-by-cell through a grid loses which
    /// column they are in.
    var accessibilityLabel: String {
        String(format: NSLocalizedString("paywall.compare.a11y.format", comment: ""),
               NSLocalizedString(labelKey, comment: ""),
               free.accessibilityText,
               premium.accessibilityText)
    }
}
