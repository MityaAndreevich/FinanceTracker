//
//  DonutSectorInsetTests.swift
//  FinanceTrackerTests
//
//  ISOLATION harness for the 1.0.3 ship blocker: a deterministic EXC_BREAKPOINT
//  on the FIRST QuickAdd against an existing 7-row store (7 renders clean, the
//  8th row traps). The device stack has zero app frames and no `Fatal error:`
//  line — the trap is inside Charts' own render, under
//  `SwiftUI.Canvas … CanvasDisplayList.updateValue()`.
//
//  WHAT PRIOR ROUNDS NEVER VARIED (this file's whole reason to exist):
//  every donut case ever written used slices of COMPARABLE magnitude
//  (ChartRenderRegressionTests: 1_200 vs 3_400) or a zero total. Nobody ever
//  rendered a donut whose slices differ by two or three orders of magnitude —
//  which is what an ordinary store looks like the moment a $3 coffee lands next
//  to a $2000 rent.
//
//  Why that shape is suspect. `CategoryDonutView` draws
//  `SectorMark(angle:innerRadius: .ratio(0.64), angularInset: 1.5).cornerRadius(3)`.
//  `angularInset` is a LINEAR inset in points, taken off BOTH angular edges of
//  the sector; at the inner radius it costs an angle of `inset / innerRadius`
//  per edge. For the Dashboard donut (size 150 → outer radius 75, inner radius
//  0.64 × 75 = 48) that is 1.5/48 = 0.03125 rad per edge, 0.0625 rad total —
//  about 1% of a full turn. So any category holding LESS THAN ~1% of the
//  month's expenses asks Charts to draw a sector whose width after insetting is
//  NEGATIVE, and to round the corners of it. That is degenerate geometry
//  produced by ordinary data, evaluated during the display-list build — exactly
//  where the device stack points, and exactly the delta a single small QuickAdd
//  introduces into a store that rendered clean at 7 rows.
//
//  A trap here aborts the test process; THAT is the signal. Each shape is its
//  own test method so the abort names the exact ratio that trips it.
//

import XCTest
import SwiftUI
import SwiftData
@testable import FinanceTracker

@MainActor
final class DonutSectorInsetTests: XCTestCase {

    // Containers outlive the window that still holds their models — see
    // ChartRenderRegressionTests for the "model instance was destroyed" trap
    // this avoids.
    private static var retainedContainers: [ModelContainer] = []
    private var container: ModelContainer!
    private var window: UIWindow!

    override func setUpWithError() throws {
        let schema = SharedModelContainer.fullSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        Self.retainedContainers.append(container)
    }

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        container = nil
    }

    // MARK: - Hosting

    @discardableResult
    private func mount(_ view: some View) -> UIViewController {
        let host = UIHostingController(rootView: view)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        return host
    }

    private func pump(_ host: UIViewController, seconds: TimeInterval = 0.35) {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func render(_ view: some View, seconds: TimeInterval = 0.35) {
        pump(mount(view), seconds: seconds)
    }

    private func donut(_ cents: [Int], size: CGFloat = 150) -> CategoryDonutView {
        let palette: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .gray]
        let slices = cents.enumerated().map { i, c in
            CategoryDonutView.Slice(
                id: "s\(i)",
                name: "Cat \(i)",
                cents: c,
                color: palette[i % palette.count]
            )
        }
        return CategoryDonutView(
            slices: slices,
            centerTitle: "Total",
            centerValue: "$0.00",
            size: size
        )
    }

    // MARK: - The untested gap: slices of wildly unequal magnitude
    //
    // Descending share for the smallest slice. The inset math above says the
    // sector goes degenerate somewhere below ~1%.

    func test_donut_smallestSlice_10pct() {
        render(donut([90_000, 10_000]))
    }

    func test_donut_smallestSlice_2pct() {
        render(donut([98_000, 2_000]))
    }

    func test_donut_smallestSlice_1pct() {
        render(donut([99_000, 1_000]))
    }

    func test_donut_smallestSlice_halfPct() {
        render(donut([199_000, 1_000]))
    }

    func test_donut_smallestSlice_tenthPct() {
        render(donut([999_000, 1_000]))
    }

    func test_donut_smallestSlice_hundredthPct() {
        render(donut([9_999_000, 1_000]))
    }

    /// The realistic 8th transaction: a $3.00 coffee entered against a month
    /// that already holds rent + groceries + a phone bill.
    func test_donut_coffeeAgainstRent() {
        render(donut([200_000, 42_000, 8_500, 300]))
    }

    /// Same shape at the Analytics donut's larger size (bigger inner radius →
    /// a smaller inset angle → the threshold moves, but does not vanish).
    func test_donut_coffeeAgainstRent_largeSize() {
        render(donut([200_000, 42_000, 8_500, 300], size: 220))
    }

    /// Six real categories plus one negligible one — the full Dashboard shape.
    func test_donut_sixCategoriesPlusNegligible() {
        render(donut([200_000, 42_000, 18_000, 9_000, 6_000, 3_000, 120]))
    }

    // MARK: - The same delta through the REAL screen
    //
    // Seven rows that render clean, then one small QuickAdd — the reported
    // repro, driven through the live update path (`@Query` observing the same
    // mainContext QuickAdd saves into).

    func test_dashboard_eighthRowIsTiny_liveUpdate() {
        let ctx = container.mainContext
        let rent = category("Rent", into: ctx)
        let food = category("Food", into: ctx)
        let bills = category("Bills", into: ctx)

        // A plausible 7-row month.
        save(200_000, category: rent, into: ctx)
        save(42_000, category: food, into: ctx)
        save(18_500, category: food, into: ctx)
        save(9_900, category: bills, into: ctx)
        save(6_400, category: food, into: ctx)
        save(3_200, category: bills, into: ctx)
        save(1_500, category: food, into: ctx)

        let host = mount(DashboardView().modelContainer(container))
        pump(host)   // 7 rows: the state the device renders CLEAN

        // The 8th row: one $3.00 coffee in a NEW category — 0.1% of the month.
        let coffee = category("Coffee", into: ctx)
        save(300, category: coffee, into: ctx)
        pump(host)   // ← the reported crash point
    }

    /// Same delta with a monthly budget set, so the Velocity hero (ring + pace)
    /// is in the tree alongside the donut.
    func test_dashboard_eighthRowIsTiny_withBudgetSet() {
        UserDefaults.standard.set(300_000, forKey: "monthlyBudgetCents")
        defer { UserDefaults.standard.removeObject(forKey: "monthlyBudgetCents") }

        let ctx = container.mainContext
        let rent = category("Rent", into: ctx)
        let food = category("Food", into: ctx)
        for cents in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500] {
            save(cents, category: cents > 20_000 ? rent : food, into: ctx)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        let coffee = category("Coffee", into: ctx)
        save(300, category: coffee, into: ctx)
        pump(host)
    }

    /// The 8th row is a SPLIT whose smallest share is negligible — the 1.0.3
    /// attribution path feeding the same donut.
    func test_dashboard_eighthRowIsSplitWithNegligibleShare() {
        let ctx = container.mainContext
        let rent = category("Rent", into: ctx)
        let food = category("Food", into: ctx)
        let fun = category("Fun", into: ctx)
        for cents in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500] {
            save(cents, category: cents > 20_000 ? rent : food, into: ctx)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        let parent = save(5_000, category: food, into: ctx)
        let tiny = TransactionSplit(amountCents: 200, category: fun, order: 0)
        let rest = TransactionSplit(amountCents: 4_800, category: food, order: 1)
        ctx.insert(tiny)
        ctx.insert(rest)
        parent.splits = [tiny, rest]
        try? ctx.save()
        pump(host)
    }

    /// The 8th row opens a NEW DAY (the store's other 7 are older), so every
    /// day-keyed series and the recent list re-diff at the same time.
    func test_dashboard_eighthRowOpensANewDay() {
        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for (i, cents) in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500].enumerated() {
            save(cents, category: food, into: ctx, dayOffset: i + 1)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        save(300, category: category("Coffee", into: ctx), into: ctx, dayOffset: 0)
        pump(host)
    }

    /// Cyrillic merchant + a Cyrillic custom category name, the way the founder
    /// enters them. (The parser output is English-keyed, but a CUSTOM category
    /// carries the user's own string into the slice name.)
    func test_dashboard_eighthRowCyrillicMerchant() {
        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for cents in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500] {
            save(cents, category: food, into: ctx)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        let coffee = category("Кофе и перекусы", into: ctx)
        let tx = save(300, category: coffee, into: ctx)
        tx.note = "кофе на Тверской"
        try? ctx.save()
        pump(host)
    }

    /// Seven categories → the donut folds the tail into the synthetic "__other"
    /// slice. That slice is built on a DIFFERENT code path from the rest, and no
    /// prior test has ever rendered it.
    func test_dashboard_eighthRowTriggersTheOtherFold() {
        let ctx = container.mainContext
        let cats = (0..<7).map { category("Cat\($0)", into: ctx) }
        for (i, cents) in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500].enumerated() {
            save(cents, category: cats[i], into: ctx)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)   // 7 categories → fold already active

        save(300, category: category("Cat7", into: ctx), into: ctx)
        pump(host)
    }

    /// All eight rows the same amount: every sector identical. The angular
    /// analogue of the "N identical points" domain collapse that round 3 found
    /// in the continuous charts, and never checked on a donut.
    func test_dashboard_allEqualAmounts() {
        let ctx = container.mainContext
        let cats = (0..<8).map { category("Cat\($0)", into: ctx) }
        for i in 0..<7 { save(5_000, category: cats[i], into: ctx) }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        save(5_000, category: cats[7], into: ctx)
        pump(host)
    }

    /// Budget explicitly 0 (the "unset" encoding) — `DailyAllowance.compute`
    /// must return nil rather than divide by it, and the hero must render
    /// without the ring while the donut updates underneath.
    func test_dashboard_eighthRow_budgetExplicitlyZero() {
        UserDefaults.standard.set(0, forKey: "monthlyBudgetCents")
        defer { UserDefaults.standard.removeObject(forKey: "monthlyBudgetCents") }

        XCTAssertNil(DailyAllowance.compute(monthlyBudgetCents: 0, spentThisMonthCents: 12_345))

        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for cents in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500] {
            save(cents, category: food, into: ctx)
        }

        let host = mount(DashboardView().modelContainer(container))
        pump(host)

        save(300, category: category("Coffee", into: ctx), into: ctx)
        pump(host)
    }

    // MARK: - Charts that are NOT on screen but are still in the view graph
    //
    // The brief scopes the search to "a Dashboard chart", because the Dashboard
    // is what is visible when the save happens. That scoping is wrong on a
    // TabView: tabs are lazily built but then RETAINED, so once Analytics has
    // been visited its Pulse / Horizon / Breakdown charts stay mounted and
    // re-render on the very same store change the QuickAdd produces — offscreen,
    // with no app frame and nothing visible to attribute it to. Every prior
    // harness mounted ONE view, so this delta has never been rendered.

    private func multiTab(selection: Binding<Int>) -> some View {
        TabView(selection: selection) {
            NavigationStack { DashboardView() }.tag(0)
            NavigationStack { AnalyticsView() }.tag(3)
        }
        .modelContainer(container)
    }

    /// Visit Analytics, come back to the Dashboard, then do the QuickAdd —
    /// the founder's actual session shape.
    func test_analyticsVisitedThenEighthRowSavedFromDashboard() {
        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for (i, cents) in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500].enumerated() {
            save(cents, category: food, into: ctx, dayOffset: i)
        }

        var tab = 0
        let binding = Binding(get: { tab }, set: { tab = $0 })
        let host = mount(multiTab(selection: binding))
        pump(host, seconds: 0.5)

        tab = 3
        pump(host, seconds: 0.8)   // Analytics builds: Pulse, Horizon, Breakdown

        tab = 0
        pump(host, seconds: 0.5)   // back to the Dashboard; Analytics stays alive

        save(300, category: category("Coffee", into: ctx), into: ctx)
        pump(host, seconds: 0.8)   // ← the save every retained chart re-renders on
    }

    /// Same, for the shape round 3 named as the reachable degenerate domain: an
    /// expenses-only store, where Horizon's income series is 12 flat zeros and
    /// Pulse's net series can collapse.
    func test_analyticsRetained_expensesOnlyStore_eighthRow() {
        UserDefaults.standard.set("income", forKey: "horizon_mode")
        defer { UserDefaults.standard.removeObject(forKey: "horizon_mode") }

        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for i in 0..<7 { save(1_000, category: food, into: ctx, dayOffset: i) }

        var tab = 0
        let binding = Binding(get: { tab }, set: { tab = $0 })
        let host = mount(multiTab(selection: binding))
        pump(host, seconds: 0.5)
        tab = 3
        pump(host, seconds: 0.8)
        tab = 0
        pump(host, seconds: 0.5)

        save(300, category: category("Coffee", into: ctx), into: ctx)
        pump(host, seconds: 0.8)
    }

    /// The most aggressive form: every chart in the app live at once, all
    /// re-rendering on the same save. Not faithful to any one screen — it is
    /// here to make a trap impossible to miss.
    func test_allChartsLive_eighthRow() {
        let ctx = container.mainContext
        let food = category("Food", into: ctx)
        for (i, cents) in [200_000, 42_000, 18_500, 9_900, 6_400, 3_200, 1_500].enumerated() {
            save(cents, category: food, into: ctx, dayOffset: i)
        }

        let both = ZStack {
            NavigationStack { DashboardView() }
            NavigationStack { AnalyticsView() }
        }
        .modelContainer(container)

        let host = mount(both)
        pump(host, seconds: 0.8)

        save(300, category: category("Coffee", into: ctx), into: ctx)
        pump(host, seconds: 0.8)
    }

    // MARK: - The assertion the guard must satisfy
    //
    // The render tests above prove the trap exists; this one states the rule in
    // terms a guard can enforce, so the fix has a red→green target that does not
    // depend on hosting a view.

    /// What the guards actually promise today, asserted directly on the values
    /// that reach `SectorMark`: every plotted magnitude finite and strictly
    /// positive, and the angular domain (0…total) of nonzero width.
    func test_plottedDonutValues_areFiniteAndSpanAPositiveDomain() {
        let cents = [200_000, 42_000, 8_500, 300]
        let slices = cents.enumerated().map {
            CategoryDonutView.Slice(id: "s\($0.offset)", name: "c", cents: $0.element, color: .red)
        }
        let plotted = ChartGuards.renderableSlices(slices, magnitude: \.cents)
        let total = plotted.reduce(0) { $0 + $1.cents }

        XCTAssertEqual(plotted.count, cents.count)
        for slice in plotted {
            XCTAssertGreaterThan(slice.cents, 0)
            XCTAssertTrue(Double(slice.cents).isFinite)
        }
        XCTAssertGreaterThan(total, 0, "angular domain 0…total must have positive width")
    }

    /// MEASUREMENT, NOT AN ASSERTION — deliberately does not fail.
    ///
    /// `angularInset: 1.5` is a linear inset taken off both angular edges of a
    /// sector; at the donut's inner radius (0.64 × 75 = 48pt) that costs
    /// 2 × 1.5 / 48 = 0.0625 rad ≈ 1% of a full turn. Any category holding less
    /// than ~1% of the month therefore asks Charts for a sector whose width
    /// after insetting is NEGATIVE — a $3 coffee against a $2500 month is 0.12%.
    ///
    /// This is real: the number below is negative for ordinary data. It is
    /// recorded here rather than asserted because every render case in this file
    /// draws exactly that shape and Charts does NOT trap on it in the simulator
    /// (iOS 18.6 and 26.5). Charts evidently clamps it. Turning this into a
    /// failure would be asserting an unproven cause — the mistake this bug has
    /// already cost three rounds. If on-device bisection ever attributes the
    /// trap to the Dashboard donut, START HERE: this is the one degenerate
    /// input the donut still carries.
    func test_measure_smallestSectorWidthAfterInset() {
        let cents = [200_000, 42_000, 8_500, 300]
        let total = Double(cents.reduce(0, +))
        let innerRadius = 150.0 / 2 * 0.64
        let insetAngle = 2 * 1.5 / innerRadius

        for c in cents {
            let sweep = 2 * Double.pi * Double(c) / total
            print("[donut-inset] \(c)¢ sweeps \(sweep) rad; after inset \(sweep - insetAngle) rad")
        }
        XCTAssertGreaterThan(total, 0)
    }

    // MARK: - The two geometries `renderableSlices` never covered
    //
    // Both bypass every existing guard: a single full-turn sector and a sector
    // narrower than its own inset are each non-empty, all-positive, and sum to a
    // positive total, so `renderableSlices` passes them straight through. The
    // simulator clamps both (every render case in this file is green); the
    // device does not. These assert the guard, not the render.

    /// One category is a full ring with no angle to divide. The view must take
    /// the `Circle().stroke` path, never a one-sector `Chart`.
    func test_singleSlice_takesTheRingPath_notTheChartPath() {
        let one = CategoryDonutView(
            slices: [.init(id: "a", name: "Shop", cents: 1_000, color: .red)],
            centerTitle: "Total",
            centerValue: "$10.00",
            size: 150
        )
        XCTAssertTrue(one.rendersAsSolidRing,
                      "a single renderable slice must render as a ring, not a 360° SectorMark")

        // The founder's exact repro: "1000 Amazon Shop" as the first expense of
        // the month, so the donut goes empty → one slice.
        let two = CategoryDonutView(
            slices: [
                .init(id: "a", name: "Shop", cents: 1_000, color: .red),
                .init(id: "b", name: "Food", cents: 4_200, color: .blue),
            ],
            centerTitle: "Total",
            centerValue: "$52.00",
            size: 150
        )
        XCTAssertFalse(two.rendersAsSolidRing, "two slices still belong on the Chart path")

        // A zero-magnitude second slice is dropped by renderableSlices, which
        // leaves ONE renderable slice — the ring path must still win.
        let dropped = CategoryDonutView(
            slices: [
                .init(id: "a", name: "Shop", cents: 1_000, color: .red),
                .init(id: "b", name: "Empty", cents: 0, color: .blue),
            ],
            centerTitle: "Total",
            centerValue: "$10.00",
            size: 150
        )
        XCTAssertTrue(dropped.rendersAsSolidRing,
                      "renderableSlices drops the 0¢ slice, so this is the single-slice case")
    }

    /// For n ≥ 2, the inset handed to `SectorMark` must leave every sector a
    /// positive width.
    func test_safeAngularInset_keepsEverySectorWidthPositive() {
        let side: CGFloat = 150
        let ratio: CGFloat = 0.64
        let defaultInset: CGFloat = 1.5

        func assertEverySectorSurvives(_ cents: [Int], line: UInt = #line) {
            let inset = ChartGuards.safeAngularInset(
                cents: cents, defaultInset: defaultInset,
                innerRadiusRatio: ratio, frameSide: side
            )
            let innerRadius = side / 2 * ratio
            let insetAngle = 2 * inset / innerRadius
            let total = CGFloat(cents.reduce(0, +))
            for c in cents {
                let sweep = 2 * CGFloat.pi * CGFloat(c) / total
                XCTAssertGreaterThan(
                    sweep - insetAngle, 0,
                    "\(c)¢ of \(Int(total))¢ keeps no width after a \(inset)pt inset",
                    line: line
                )
            }
        }

        // Comparable magnitudes: the default inset is affordable and kept.
        XCTAssertEqual(
            ChartGuards.safeAngularInset(cents: [4_200, 3_100, 2_800], defaultInset: defaultInset,
                                        innerRadiusRatio: ratio, frameSide: side),
            defaultInset
        )
        assertEverySectorSurvives([4_200, 3_100, 2_800])

        // A $3 coffee against rent — 0.12% of the month. The default inset
        // consumes it entirely, so the guard must drop to 0.
        XCTAssertEqual(
            ChartGuards.safeAngularInset(cents: [200_000, 42_000, 8_500, 300], defaultInset: defaultInset,
                                        innerRadiusRatio: ratio, frameSide: side),
            0
        )
        assertEverySectorSurvives([200_000, 42_000, 8_500, 300])
        assertEverySectorSurvives([99_000, 1_000])       // 1%, right at the boundary
        assertEverySectorSurvives([9_999_000, 1_000])    // 0.01%

        // Degenerate geometry inputs can never yield a positive inset.
        XCTAssertEqual(ChartGuards.safeAngularInset(cents: [1_000, 2_000], defaultInset: defaultInset,
                                                    innerRadiusRatio: ratio, frameSide: 0), 0)
        XCTAssertEqual(ChartGuards.safeAngularInset(cents: [], defaultInset: defaultInset,
                                                    innerRadiusRatio: ratio, frameSide: side), 0)
    }

    // MARK: - Fixtures

    @discardableResult
    private func category(_ name: String, into ctx: ModelContext) -> FinanceTracker.Category {
        let c = FinanceTracker.Category(name: name, kindRaw: "expense", icon: "cart", order: 0)
        ctx.insert(c)
        try? ctx.save()
        return c
    }

    @discardableResult
    private func save(
        _ cents: Int,
        category: FinanceTracker.Category,
        into ctx: ModelContext,
        dayOffset: Int = 0
    ) -> FinanceTracker.Transaction {
        // Stay inside the current month: the Dashboard's @Query is month-scoped,
        // and a row that falls out of it would silently weaken the case.
        let day = min(dayOffset, max(0, Calendar.current.component(.day, from: Date()) - 1))
        let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) ?? Date()
        let tx = FinanceTracker.Transaction(
            typeRaw: "expense",
            amountCents: cents,
            date: date,
            category: category
        )
        ctx.insert(tx)
        try? ctx.save()
        return tx
    }
}
