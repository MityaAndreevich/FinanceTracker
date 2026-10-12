//
//  SettingsRoute.swift
//  FinanceTracker
//
//  Every screen the Settings stack can push, as a VALUE (1.0.7, Guide step 2).
//
//  Why values: the User Guide's "Show me" must push a Settings child from
//  outside the view (DESIGN_USER_GUIDE §7), which needs a path the Settings
//  stack is bound to. A bound path only tracks value-based links, and mixing it
//  with destination-based `NavigationLink { … }` is what Round 9 R1 was
//  (fb9c075): the path and the stack disagreed after a deep pop. So the rule for
//  this stack is ALL VALUES. A destination-based link anywhere on it brings the
//  mix back. `SettingsStackDeepPopTests` guards the two journeys R1 broke.
//
//  One exception the API forces: `Picker(.navigationLink)` in Privacy pushes its
//  own list. The tab-leave `.id` reset in ContentView clears it regardless.
//

import SwiftUI

enum SettingsRoute: Hashable {
    case general, premium, data, categories, recurring, privacy
    case alerts, reports, reportsSettings, learnTips, setupGuide, about
    case tip(DailyTip)
    case article(HelpArticle)
}

extension View {
    /// Register on the ROOT of every stack that shows a Settings screen: the
    /// Settings tab, and `ReportsScreen` (Reports' bell links to `.reportsSettings`).
    func settingsRouteDestinations() -> some View {
        navigationDestination(for: SettingsRoute.self) { SettingsRouteView(route: $0) }
    }
}

private struct SettingsRouteView: View {
    let route: SettingsRoute

    var body: some View {
        switch route {
        case .general: GeneralSettingsView()
        case .premium: PremiumSettingsView()
        case .data: DataSettingsView()
        case .categories: CategoriesSourcesView()
        case .recurring: RecurringSettingsView()
        case .privacy: PrivacySettingsView()
        case .alerts: AlertsSettingsView()
        case .reports: ReportsView(initialPeriod: .month(containing: Date()))
        case .reportsSettings: ReportsSettingsView()
        case .learnTips: LearnAndTipsView()
        case .setupGuide: SetupGuideView()
        case .about: AboutView()
        case .tip(let tip): TipDetailView(tip: tip)
        case .article(let article): HelpArticleView(article: article)
        }
    }
}
