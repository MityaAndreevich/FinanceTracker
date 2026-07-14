//
//  ChartVisualSmokeTests.swift
//  FinanceTrackerTests
//
//  A guard that blanks every chart would be worse than the bug it prevents. This
//  renders each real chart at a normal size and writes a PNG so the output can be
//  looked at, not just asserted about. Non-blank is checked mechanically too: a
//  chart that drew nothing would be a single flat colour.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

@MainActor
final class ChartVisualSmokeTests: XCTestCase {

    private static let outDir = ProcessInfo.processInfo.environment["CHART_SMOKE_DIR"]

    private var window: UIWindow!

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
    }

    /// Render through a real hosting controller in a real window.
    ///
    /// NOT ImageRenderer: it proposes an unbounded/zero size to a `ScrollView`,
    /// which is what Pulse and Breakdown are rooted in, so it reports them blank
    /// whether or not a guard is present. A window lays out exactly like the app.
    private func snapshot(_ view: some View, size: CGSize, name: String) throws {
        let host = UIHostingController(rootView: view.background(Color.black))
        let w = UIWindow(frame: CGRect(origin: .zero, size: size))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        let renderer = UIGraphicsImageRenderer(bounds: host.view.bounds)
        let image = renderer.image { ctx in
            host.view.layer.render(in: ctx.cgContext)
        }
        guard let data = image.pngData() else { return XCTFail("\(name): no png data") }

        let dir = Self.outDir ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: dir).appendingPathComponent("chart-\(name).png")
        try data.write(to: url)
        print("[ChartSmoke] wrote \(url.path)")

        // A blanked chart renders as one uniform colour. Count distinct pixels to
        // prove something was actually drawn.
        XCTAssertTrue(distinctColorCount(image) > 4,
                      "\(name) rendered blank — the frame guard is suppressing a chart it should allow")
    }

    private func distinctColorCount(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 0 }
        let w = min(cg.width, 60), h = min(cg.height, 60)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var seen = Set<UInt32>()
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let rgba = UInt32(pixels[i]) << 24 | UInt32(pixels[i + 1]) << 16
                     | UInt32(pixels[i + 2]) << 8 | UInt32(pixels[i + 3])
            seen.insert(rgba)
        }
        return seen.count
    }

    func test_pulse_stillDraws() throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let totals = (0..<14).map { i in
            AnalyticsPulseView.DailyTotal(
                date: cal.date(byAdding: .day, value: i, to: start)!,
                cents: [-1_200, -3_400, 0, -800, 5_000][i % 5]
            )
        }
        try snapshot(
            AnalyticsPulseView(dailyTotals: totals, netCents: -400, earnedCents: 5_000,
                               spentCents: 5_400, currencyCode: "USD"),
            size: CGSize(width: 393, height: 560),
            name: "pulse"
        )
    }

    func test_horizon_stillDraws() throws {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let totals = (0..<12).map { i in
            AnalyticsHorizonView.MonthlyTotal(
                date: cal.date(byAdding: .month, value: i, to: start)!,
                incomeCents: 100_000 + i * 7_000,
                expenseCents: 80_000 + i * 3_000
            )
        }
        try snapshot(
            AnalyticsHorizonView(monthlyTotals: totals, currencyCode: "USD"),
            size: CGSize(width: 393, height: 460),
            name: "horizon"
        )
    }

    func test_breakdown_stillDraws() throws {
        try snapshot(
            AnalyticsBreakdownView(
                categories: [
                    .init(id: UUID(), name: "Housing", symbol: "house",
                          cents: 150_000, isIncome: false, color: .purple),
                    .init(id: UUID(), name: "Food & Drink", symbol: "cup.and.saucer",
                          cents: 48_000, isIncome: false, color: .orange),
                    .init(id: UUID(), name: "Transport", symbol: "car",
                          cents: 22_000, isIncome: false, color: .blue),
                ],
                currencyCode: "USD"
            ),
            size: CGSize(width: 393, height: 620),
            name: "breakdown"
        )
    }

    func test_dashboardDonut_stillDraws() throws {
        try snapshot(
            CategoryDonutView(
                slices: [
                    .init(id: "a", name: "Housing", cents: 150_000, color: .purple),
                    .init(id: "b", name: "Food", cents: 48_000, color: .orange),
                    .init(id: "c", name: "Transport", cents: 22_000, color: .blue),
                ],
                centerTitle: "dashboard.total_spent",
                centerValue: "$2,200",
                size: 150
            ),
            size: CGSize(width: 200, height: 200),
            name: "donut"
        )
    }
}
