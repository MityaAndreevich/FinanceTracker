//
//  ShowSpendingIntent.swift
//  FinanceTracker
//
//  "Hey Siri, show this month's spending in Vela" → app opens to Analytics
//  for the requested period. Sets flags in App Group UserDefaults; ContentView
//  reads them on foreground and switches to the Analytics tab.
//

import AppIntents

struct ShowSpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Spending"
    static var description = IntentDescription(
        "Show spending breakdown in Vela.",
        categoryName: "Money"
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Period", default: PeriodAppEnum.thisMonth)
    var period: PeriodAppEnum

    func perform() async throws -> some IntentResult {
        UserDefaults.appGroup.set(period.rawValue, forKey: "pendingAnalyticsPeriod")
        UserDefaults.appGroup.set(true, forKey: "pendingNavigateToAnalytics")
        return .result()
    }
}

// MARK: - Period enum

enum PeriodAppEnum: String, AppEnum {
    case today
    case thisWeek
    case thisMonth
    case lastMonth
    case thisYear

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Period")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today: "Today",
        .thisWeek: "This Week",
        .thisMonth: "This Month",
        .lastMonth: "Last Month",
        .thisYear: "This Year",
    ]
}

// MARK: - PeriodScope mapping

extension PeriodScope {
    /// Maps a PeriodAppEnum raw value to a PeriodScope for use in AnalyticsView.
    static func from(periodAppRaw: String) -> PeriodScope {
        switch PeriodAppEnum(rawValue: periodAppRaw) {
        case .lastMonth:
            let date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return .month(date)
        default:
            return .currentMonth
        }
    }
}
