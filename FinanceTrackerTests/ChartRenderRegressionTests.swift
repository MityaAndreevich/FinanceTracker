//
//  ChartRenderRegressionTests.swift
//  FinanceTrackerTests
//
//  Repro harness for the device EXC_BREAKPOINT inside Charts when the SECOND
//  transaction lands. Unit tests over ChartGuards can't catch this class of bug:
//  the trap happens inside Charts' own scale/layout compute, so the ONLY way to
//  observe it is to actually host the view and force a layout pass — the same
//  `_UIHostingView.layoutSubviews` the crash report names.
//
//  Each test renders a real chart against a shape the real data path can produce.
//  A trap here aborts the test process — that is the signal.
//

import XCTest
import SwiftUI
import SwiftData
@testable import FinanceTracker

@MainActor
final class ChartRenderRegressionTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var window: UIWindow!

    /// A window passed to `makeKeyAndVisible()` outlives our reference to it, and
    /// so does the SwiftUI view graph inside it — which still holds SwiftData
    /// models. If the container is deallocated at tearDown, that graph renders
    /// once more against a destroyed store and traps with
    /// "This model instance was destroyed…" — an EXC_BREAKPOINT that looks exactly
    /// like the bug under investigation but is pure test-harness noise.
    /// Keeping every container alive for the process removes the false signal.
    private static var retainedContainers: [ModelContainer] = []

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        Self.retainedContainers.append(container)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        context = nil
        container = nil   // the static reference keeps the store alive
    }

    /// Host a view and force the real render/layout pass. Charts computes its
    /// scales here — a degenerate domain traps inside this call.
    private func render(_ view: some View, seconds: TimeInterval = 0.35) {
        let host = mount(view)
        pump(host, seconds: seconds)
    }

    /// Mount a view in a real window and keep it live, so later data changes go
    /// through Charts' *update* path (not a fresh build).
    private func mount(_ view: some View) -> UIViewController {
        let host = UIHostingController(rootView: view)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        return host
    }

    /// Force layout + spin the runloop so the display list actually renders
    /// (the crash is in CanvasDisplayList.updateValue during layoutSubviews).
    private func pump(_ host: UIViewController, seconds: TimeInterval = 0.35) {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Fixtures

    private func makeCategory(_ name: String, kind: String = "expense") -> FinanceTracker.Category {
        let c = FinanceTracker.Category(name: name, kindRaw: kind, icon: "cart", order: 0)
        context.insert(c)
        return c
    }

    @discardableResult
    private func addTransaction(cents: Int, income: Bool, dayOffset: Int = 0, category: FinanceTracker.Category) -> FinanceTracker.Transaction {
        let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        let tx = FinanceTracker.Transaction(
            typeRaw: income ? "income" : "expense",
            amountCents: cents,
            date: date,
            category: category
        )
        context.insert(tx)
        try? context.save()
        return tx
    }

    // MARK: - The real data path: a LIVE screen, transactions landing under it
    //
    // This is the reported scenario: the screen is already on-screen and the user
    // saves from QuickAdd. The chart takes Charts' *update* path (diff old → new
    // data), not a fresh build. Inserts go through `container.mainContext` — the
    // same context QuickAdd saves into, and the one `@Query` observes.

    func test_dashboard_liveUpdate_acrossFirstThreeTransactions() {
        let ctx = container.mainContext
        let food = insertCategory("Food", into: ctx)
        let rent = insertCategory("Rent", into: ctx)
        let fun = insertCategory("Fun", into: ctx)

        let host = mount(DashboardView().modelContainer(container))
        pump(host)   // empty state renders

        save(cents: 1_200, income: false, category: food, into: ctx)
        pump(host)   // QuickAddSave #1

        save(cents: 3_400, income: false, category: rent, into: ctx)
        pump(host)   // QuickAddSave #2  ← the reported crash point

        save(cents: 5_600, income: false, category: fun, into: ctx)
        pump(host)   // QuickAddSave #3
    }

    func test_analytics_liveUpdate_acrossFirstThreeTransactions() {
        let ctx = container.mainContext
        let food = insertCategory("Food", into: ctx)
        let rent = insertCategory("Rent", into: ctx)

        let host = mount(AnalyticsView().modelContainer(container))
        pump(host)

        save(cents: 1_200, income: false, category: food, into: ctx)
        pump(host)

        save(cents: 3_400, income: false, category: rent, into: ctx)
        pump(host)   // ← the reported crash point

        save(cents: 5_600, income: true, category: food, into: ctx)
        pump(host)
    }

    /// Two transactions in the SAME category — the donut goes 1 slice → 1 slice
    /// but the magnitude changes, and Dashboard's category tiles re-diff.
    func test_dashboard_liveUpdate_sameCategoryTwice() {
        let ctx = container.mainContext
        let food = insertCategory("Food", into: ctx)

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        save(cents: 1_200, income: false, category: food, into: ctx)
        pump(host)

        save(cents: 3_400, income: false, category: food, into: ctx)
        pump(host)
    }

    @discardableResult
    private func insertCategory(_ name: String, into ctx: ModelContext) -> FinanceTracker.Category {
        let c = FinanceTracker.Category(name: name, kindRaw: "expense", icon: "cart", order: 0)
        ctx.insert(c)
        try? ctx.save()
        return c
    }

    private func save(cents: Int, income: Bool, category: FinanceTracker.Category, into ctx: ModelContext) {
        let tx = FinanceTracker.Transaction(
            typeRaw: income ? "income" : "expense",
            amountCents: cents,
            date: Date(),
            category: category
        )
        ctx.insert(tx)
        try? ctx.save()
    }

    // MARK: - Pulse: value-domain shapes the count guard does NOT cover
    //
    // `canRenderContinuous` only checks the number of points. A dense day series
    // always has ≥2 points, so the guard always passes — but the *Y* domain can
    // still collapse to zero width (every day nets to 0), which no guard checks.

    private func pulse(_ values: [Int]) -> AnalyticsPulseView {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let totals = values.enumerated().map { i, cents in
            AnalyticsPulseView.DailyTotal(
                date: cal.date(byAdding: .day, value: i, to: start)!,
                cents: cents
            )
        }
        return AnalyticsPulseView(
            dailyTotals: totals,
            netCents: values.reduce(0, +),
            earnedCents: 0,
            spentCents: 0,
            currencyCode: "USD"
        )
    }

    func test_pulse_twoPoints() {
        render(pulse([-1_200, -3_400]))
    }

    func test_pulse_twoIdenticalPoints() {
        render(pulse([-1_200, -1_200]))
    }

    /// Zero-width Y domain: every day nets to exactly 0. Reachable with 2
    /// transactions — an income that exactly offsets an expense.
    func test_pulse_allZeroValues_zeroWidthYDomain() {
        render(pulse([0, 0, 0, 0, 0]))
    }

    /// Dense month series where a same-day income cancels the expense: the whole
    /// series is 0 → min == max == 0.
    func test_pulse_offsettingPair_zeroWidthYDomain() {
        render(pulse([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
    }

    // MARK: - Horizon: same question on the 12-month dense series

    private func horizon(_ pairs: [(income: Int, expense: Int)]) -> AnalyticsHorizonView {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let totals = pairs.enumerated().map { i, p in
            AnalyticsHorizonView.MonthlyTotal(
                date: cal.date(byAdding: .month, value: i, to: start)!,
                incomeCents: p.income,
                expenseCents: p.expense
            )
        }
        return AnalyticsHorizonView(monthlyTotals: totals, currencyCode: "USD")
    }

    func test_horizon_allZeroMonths_zeroWidthYDomain() {
        render(horizon(Array(repeating: (income: 0, expense: 0), count: 12)))
    }

    func test_horizon_singleNonZeroMonth() {
        var months = Array(repeating: (income: 0, expense: 0), count: 12)
        months[11] = (income: 0, expense: 1_200)
        render(horizon(months))
    }

    func test_horizon_offsettingMonth_netAllZero() {
        var months = Array(repeating: (income: 0, expense: 0), count: 12)
        months[11] = (income: 5_000, expense: 5_000)   // net 0 everywhere
        render(horizon(months))
    }

    // MARK: - Donut

    func test_donut_singleSlice() {
        render(CategoryDonutView(
            slices: [.init(id: "a", name: "Food", cents: 1_200, color: .red)],
            centerTitle: "Total",
            centerValue: "$12.00"
        ))
    }

    func test_donut_twoSlices() {
        render(CategoryDonutView(
            slices: [
                .init(id: "a", name: "Food", cents: 1_200, color: .red),
                .init(id: "b", name: "Rent", cents: 3_400, color: .blue),
            ],
            centerTitle: "Total",
            centerValue: "$46.00"
        ))
    }
}
