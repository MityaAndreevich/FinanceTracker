//
//  GuideRouter.swift
//  FinanceTracker
//
//  "Show me" (1.0.7, User Guide step 2; DESIGN_USER_GUIDE §7,
//  outputs/GUIDE_STEP2_PLAN.md).
//
//  ONE ENTRY POINT: `GuideRouter.open(_:)`. A Guide card's Show me button
//  (step 3) and the DEBUG route harness are both thin callers of it, and
//  nothing else navigates on the Guide's behalf. `open` does not care who
//  called it, so step 3 adds a caller and changes nothing here.
//
//  How a destination is reached:
//    • `GuideDestination.route` says WHERE: a tab, a Settings path, and at most
//      one piece of in-screen work (open a sheet the screen owns, focus a field,
//      set a picker, scroll to a section).
//    • ContentView applies the tab, then, one main-queue hop later (after the
//      tab change and Settings' tab-leave reset have landed, the same hop
//      `.budgetCrabPendingIntent` uses), the Settings path and the in-screen work.
//    • The in-screen work waits in `pending` until the screen that owns it
//      `take`s it. Each sheet keeps its ONE home; the Guide never presents a
//      second copy of a screen's sheet from outside.
//

import SwiftUI
import Observation

/// Every place Show me can take the user. `guideRoot` joins in step 3, with the
/// Guide root it pops to.
enum GuideDestination: String, CaseIterable, Identifiable {
    case quickEntry, addForm, dashboard, dashboardQuickAdd, dashboardBudget
    case transactions, analyticsPulse, analyticsBreakdown, analyticsHorizon
    case reports, reportsSettings, alerts, recurring
    case categoriesAndAccounts, categoryLimits, dataImport, dataExport
    case general, privacy, premium, feedback, setupSiri

    var id: String { rawValue }
}

/// Work a destination screen does on arrival. Taken once, by the screen that owns it.
enum GuideScreenWork: Equatable {
    case focusQuickAdd, budgetSheet, addForm      // Dashboard
    case clearTransactionsSearch                  // Transactions
    case analytics(AnalyticsView.Screen)          // Analytics' segmented picker
    case dataSection(DataSettingsSection)         // Settings → Data
    case expenseCategories                        // Settings → Categories & Accounts
    case feedback                                 // Settings root's mail sheet
}

/// The sections of Settings → Data that Show me scrolls to.
enum DataSettingsSection: Hashable { case export, `import` }

struct GuideRoute: Equatable {
    static let dashboardTab = 0, transactionsTab = 1, analyticsTab = 3, settingsTab = 4

    /// nil only for a destination outside the app.
    var tab: Int?
    /// Applied when `tab` is Settings; empty = Settings' root.
    var settingsPath: [SettingsRoute] = []
    /// Quick Entry is ContentView's own sheet (the "+" tab's).
    var presentsQuickEntry = false
    var work: GuideScreenWork?
    var externalURL: URL?
}

extension GuideDestination {
    var route: GuideRoute {
        typealias R = GuideRoute
        switch self {
        case .quickEntry:            return R(tab: nil, presentsQuickEntry: true)
        case .addForm:               return R(tab: R.dashboardTab, work: .addForm)
        case .dashboard:             return R(tab: R.dashboardTab)
        case .dashboardQuickAdd:     return R(tab: R.dashboardTab, work: .focusQuickAdd)
        case .dashboardBudget:       return R(tab: R.dashboardTab, work: .budgetSheet)
        case .transactions:          return R(tab: R.transactionsTab, work: .clearTransactionsSearch)
        case .analyticsPulse:        return R(tab: R.analyticsTab, work: .analytics(.pulse))
        case .analyticsBreakdown:    return R(tab: R.analyticsTab, work: .analytics(.breakdown))
        case .analyticsHorizon:      return R(tab: R.analyticsTab, work: .analytics(.horizon))
        case .reports:               return R(tab: R.settingsTab, settingsPath: [.reports])
        case .reportsSettings:       return R(tab: R.settingsTab, settingsPath: [.reports, .reportsSettings])
        case .alerts:                return R(tab: R.settingsTab, settingsPath: [.alerts])
        case .recurring:             return R(tab: R.settingsTab, settingsPath: [.recurring])
        case .categoriesAndAccounts: return R(tab: R.settingsTab, settingsPath: [.categories])
        case .categoryLimits:        return R(tab: R.settingsTab, settingsPath: [.categories], work: .expenseCategories)
        case .dataImport:            return R(tab: R.settingsTab, settingsPath: [.data], work: .dataSection(.import))
        case .dataExport:            return R(tab: R.settingsTab, settingsPath: [.data], work: .dataSection(.export))
        case .general:               return R(tab: R.settingsTab, settingsPath: [.general])
        case .privacy:               return R(tab: R.settingsTab, settingsPath: [.privacy])
        case .premium:               return R(tab: R.settingsTab, settingsPath: [.premium])
        case .feedback:              return R(tab: R.settingsTab, work: .feedback)
        case .setupSiri:             return R(tab: nil, externalURL: URL(string: "shortcuts://"))
        }
    }
}

@MainActor
@Observable
final class GuideRouter {
    struct Request: Equatable {
        let id = UUID()
        let destination: GuideDestination
    }
    struct PendingWork: Equatable {
        let id = UUID()
        let work: GuideScreenWork
    }

    /// The latest `open`. ContentView observes it and applies `destination.route`.
    private(set) var request: Request?
    /// In-screen work waiting for its screen. Set by ContentView, taken by the screen.
    private(set) var pending: PendingWork?

    /// THE entry point. Every Show me, and the DEBUG harness, calls this and only this.
    func open(_ destination: GuideDestination) {
        request = Request(destination: destination)
    }

    /// ContentView, after the tab and path have landed.
    func post(_ work: GuideScreenWork?) {
        pending = work.map(PendingWork.init(work:))
    }

    /// The owning screen takes its work exactly once. `match` returns nil for work
    /// that belongs to another screen, which is then left waiting.
    func take<T>(_ match: (GuideScreenWork) -> T?) -> T? {
        guard let pending, let value = match(pending.work) else { return nil }
        self.pending = nil
        return value
    }
}

extension View {
    /// A Show-me destination's identity for the journey test: a container element
    /// that keeps its children accessible. Adds no view and no hit-testing.
    func guideScreenID(_ id: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}
