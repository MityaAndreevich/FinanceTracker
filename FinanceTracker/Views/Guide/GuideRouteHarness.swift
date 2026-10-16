//
//  GuideRouteHarness.swift
//  FinanceTracker
//
//  DEBUG-only, and absent unless launched with `--guide-route-harness`.
//
//  A second caller of `GuideRouter.open(_:)` for `GuideShowMeJourneyTests`,
//  until step 3's Show me buttons exist. It is a thin caller: every item is
//  `router.open(destination)` and nothing else.
//
//  Why a button and not a launch argument: a launch argument would fire on the
//  Dashboard at launch, so a journey could never START anywhere else, and a
//  route that did nothing would pass for every Dashboard destination.
//
//  Not a D51-class overlay (2026-10-15 amendment): one small button, outside
//  the tab bar and the navigation bar, no full-screen container, nothing in
//  the view tree at all without the argument. `ReleaseDebugAffordanceTests`
//  proves it is absent from Release; the journey test proves it is absent
//  from DEBUG without the argument.
//

#if DEBUG
import SwiftUI

struct GuideRouteHarness: View {
    static let launchArgument = "--guide-route-harness"
    static var isRequested: Bool { CommandLine.arguments.contains(launchArgument) }

    let router: GuideRouter

    /// Families keep each menu short enough to show without scrolling.
    private static let families: [(String, [GuideDestination])] = [
        ("tabs", [.dashboard, .transactions, .analyticsPulse, .analyticsBreakdown, .analyticsHorizon]),
        ("sheets", [.quickEntry, .addForm, .dashboardBudget, .feedback]),
        ("settings", [.general, .premium, .privacy, .alerts, .recurring, .categoriesAndAccounts,
                      .reports, .reportsSettings]),
        ("inScreen", [.dashboardQuickAdd, .categoryLimits, .dataImport, .dataExport]),
        ("external", [.setupSiri]),
    ]

    /// A destination added to the enum but not to a family still appears, so the
    /// harness can never silently lack one.
    private static var menus: [(String, [GuideDestination])] {
        let listed = Set(families.flatMap(\.1))
        let rest = GuideDestination.allCases.filter { !listed.contains($0) }
        return rest.isEmpty ? families : families + [("unsorted", rest)]
    }

    var body: some View {
        Menu {
            ForEach(Self.menus, id: \.0) { family in
                Menu(family.0) {
                    ForEach(family.1) { destination in
                        Button(destination.rawValue) { router.open(destination) }
                    }
                }
            }
        } label: {
            Image(systemName: "signpost.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityIdentifier("guide.harness")
    }
}
#endif
