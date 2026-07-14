//
//  ChartDegenerateFrameTests.swift
//  FinanceTrackerTests
//
//  The missing test case: the earlier harnesses varied the DATA and always hosted
//  the charts in a valid frame. The device evidence points the other way —
//  "Invalid frame dimension (negative or non-finite)" spams right before every
//  crash, alongside a `_UIButtonBarButton` width == 0 constraint break. So the
//  degenerate input is the FRAME, not the data: Charts is asked to lay out in a
//  zero / negative / NaN box and traps in its own recursive scale/layout math
//  (which is why the crash has no app frame on the stack, and why it is
//  non-deterministic by transaction count — it fired at #2, #3 and #17).
//
//  These tests hold the data constant and valid, and make the GEOMETRY
//  degenerate. Each one hosts a real chart in a bad frame and forces a layout
//  pass. Before the guard, the ones marked REPRO trap; after it, they must all
//  render a placeholder instead.
//

import XCTest
import SwiftUI
import SwiftData
@testable import FinanceTracker

@MainActor
final class ChartDegenerateFrameTests: XCTestCase {

    private var window: UIWindow!
    private static var retainedContainers: [ModelContainer] = []
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self])
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

    /// Force a layout pass on a view hosted inside a deliberately degenerate box.
    private func render(_ view: some View, in size: CGSize) {
        let host = UIHostingController(
            rootView: view.frame(width: size.width, height: size.height)
        )
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
    }

    // MARK: - Degenerate boxes
    //
    // A chart's height is pinned in the view (240 / 320 / 280), but its WIDTH is
    // always proposed by the parent — so a collapsing parent is the reachable
    // case on device.

    private static let degenerateSizes: [(name: String, size: CGSize)] = [
        ("zero width",      CGSize(width: 0,            height: 240)),
        ("negative width",  CGSize(width: -120,         height: 240)),
        ("NaN width",       CGSize(width: CGFloat.nan, height: 240)),
        ("infinite width",  CGSize(width: CGFloat.infinity, height: 240)),
        ("zero height",     CGSize(width: 350,          height: 0)),
        ("negative height", CGSize(width: 350,          height: -240)),
        ("NaN height",      CGSize(width: 350, height: CGFloat.nan)),
        ("NaN both",        CGSize(width: CGFloat.nan, height: CGFloat.nan)),
        ("zero both",       CGSize(width: 0,            height: 0)),
    ]

    // MARK: - Fixtures (valid data — only the frame is degenerate)

    private func pulse() -> AnalyticsPulseView {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let totals = (0..<14).map { i in
            AnalyticsPulseView.DailyTotal(
                date: cal.date(byAdding: .day, value: i, to: start)!,
                cents: [-1_200, -3_400, 0, -800, 5_000][i % 5]
            )
        }
        return AnalyticsPulseView(
            dailyTotals: totals, netCents: -400,
            earnedCents: 5_000, spentCents: 5_400, currencyCode: "RUB"
        )
    }

    private func horizon() -> AnalyticsHorizonView {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let totals = (0..<12).map { i in
            AnalyticsHorizonView.MonthlyTotal(
                date: cal.date(byAdding: .month, value: i, to: start)!,
                incomeCents: 100_000 + i * 1_000,
                expenseCents: 80_000 + i * 2_000
            )
        }
        return AnalyticsHorizonView(monthlyTotals: totals, currencyCode: "RUB")
    }

    private func donut() -> CategoryDonutView {
        CategoryDonutView(
            slices: [
                .init(id: "a", name: "Food & Drink", cents: 35_000, color: .red),
                .init(id: "b", name: "Transport", cents: 12_000, color: .blue),
            ],
            centerTitle: "dashboard.total_spent",
            centerValue: "47 000 ₽",
            size: 150
        )
    }

    private func breakdown() -> AnalyticsBreakdownView {
        AnalyticsBreakdownView(
            categories: [
                .init(id: UUID(), name: "Food & Drink", symbol: "cup.and.saucer",
                      cents: 35_000, isIncome: false, color: .red),
                .init(id: UUID(), name: "Transport", symbol: "car",
                      cents: 12_000, isIncome: false, color: .blue),
            ],
            currencyCode: "RUB"
        )
    }

    // MARK: - REPRO: every real chart, in every degenerate box

    func test_pulse_inDegenerateFrames() {
        for (name, size) in Self.degenerateSizes {
            print("[Frame] Pulse @ \(name) -> \(size)")
            render(pulse(), in: size)
        }
    }

    func test_horizon_inDegenerateFrames() {
        for (name, size) in Self.degenerateSizes {
            print("[Frame] Horizon @ \(name) -> \(size)")
            render(horizon(), in: size)
        }
    }

    func test_donut_inDegenerateFrames() {
        for (name, size) in Self.degenerateSizes {
            print("[Frame] Donut @ \(name) -> \(size)")
            render(donut(), in: size)
        }
    }

    func test_breakdown_inDegenerateFrames() {
        for (name, size) in Self.degenerateSizes {
            print("[Frame] Breakdown @ \(name) -> \(size)")
            render(breakdown(), in: size)
        }
    }

    func test_daySpendingSheet_inDegenerateFrames() {
        for (name, size) in Self.degenerateSizes {
            print("[Frame] DaySpendingSheet @ \(name) -> \(size)")
            render(DaySpendingSheet(day: Date(), currencyCode: "RUB")
                .modelContainer(container), in: size)
        }
    }

    /// The donut's size is a caller-supplied scalar, so a non-finite value would
    /// go straight into `.frame(width:height:)`. Nothing passes a computed size
    /// today (Dashboard hardcodes 150) — this locks that in.
    func test_donut_withNonFiniteSizeParameter() {
        for bad in [CGFloat.nan, -50, 0, .infinity] {
            print("[Frame] Donut size parameter = \(bad)")
            render(
                CategoryDonutView(
                    slices: [.init(id: "a", name: "Food", cents: 35_000, color: .red)],
                    centerTitle: "dashboard.total_spent",
                    centerValue: "350 ₽",
                    size: bad
                ),
                in: CGSize(width: 350, height: 350)
            )
        }
    }

    // MARK: - The guard itself
    //
    // Surviving a degenerate frame is not the bar — the charts already did that
    // in the simulator, while the device still trapped. The bar is that Charts is
    // never *asked* to lay out in a degenerate box in the first place. That is a
    // property of ChartGuards.canRenderInBox, so assert it directly: every box
    // the app can propose is either renderable, or refused.

    func test_everyDegenerateBox_isRefused() {
        for (name, size) in Self.degenerateSizes {
            XCTAssertFalse(
                ChartGuards.canRenderInBox(size),
                "\(name) must be refused — Charts would build a scale on it otherwise"
            )
        }
    }

    func test_realChartBoxes_areAccepted() {
        // The boxes the charts actually pin, at a plausible iPhone width. The
        // guard must not blank a chart that is perfectly fine to draw.
        XCTAssertTrue(ChartGuards.canRenderInBox(CGSize(width: 353, height: 240)), "Pulse")
        XCTAssertTrue(ChartGuards.canRenderInBox(CGSize(width: 353, height: 320)), "Horizon")
        XCTAssertTrue(ChartGuards.canRenderInBox(CGSize(width: 353, height: 280)), "Breakdown donut")
        XCTAssertTrue(ChartGuards.canRenderInBox(CGSize(width: 150, height: 150)), "Dashboard donut")
    }
}
