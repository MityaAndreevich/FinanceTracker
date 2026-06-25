import Foundation
import Testing
import AppIntents
@testable import FinanceTracker

@Suite("VelaShortcuts")
struct VelaShortcutsTests {

    @Test func test_appShortcuts_containsThreeShortcuts() {
        #expect(VelaShortcuts.appShortcuts.count == 3)
    }

    @Test func test_periodAppEnum_rawValues() {
        #expect(PeriodAppEnum.today.rawValue == "today")
        #expect(PeriodAppEnum.thisWeek.rawValue == "thisWeek")
        #expect(PeriodAppEnum.thisMonth.rawValue == "thisMonth")
        #expect(PeriodAppEnum.lastMonth.rawValue == "lastMonth")
        #expect(PeriodAppEnum.thisYear.rawValue == "thisYear")
    }

    @Test func test_transactionTypeAppEnum_defaultIsExpense() {
        let intent = AddTransactionIntent()
        #expect(intent.type == .expense)
    }

    @Test func test_periodScopeMapping_lastMonth_isNotCurrentMonth() {
        let scope = PeriodScope.from(periodAppRaw: "lastMonth")
        #expect(!scope.isCurrentMonth)
    }

    @Test func test_periodScopeMapping_unknown_fallsBackToCurrentMonth() {
        let scope = PeriodScope.from(periodAppRaw: "unknown")
        #expect(scope.isCurrentMonth)
    }
}
