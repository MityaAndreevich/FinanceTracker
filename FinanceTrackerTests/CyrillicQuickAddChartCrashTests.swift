//
//  CyrillicQuickAddChartCrashTests.swift
//  FinanceTrackerTests
//
//  The "2nd transaction" crash, driven down the REAL path end to end:
//
//      SeedService (real categories)
//        -> QuickAddParser.parse("кофе 350")   (real parser, Cyrillic)
//        -> QuickAddSaveService.save(...)      (real category resolution)
//        -> render the real Dashboard / Analytics charts (real layout pass)
//
//  The earlier harness fed hand-built structs and rendered clean, which only
//  proved the *numeric* guards hold. It never ran the parser, so it could not
//  produce whatever the Cyrillic path stores. Nothing here is synthetic: if a
//  parsed Cyrillic entry can put a degenerate value into a chart, this is where
//  it surfaces.
//

import XCTest
import SwiftUI
import SwiftData
@testable import FinanceTracker

@MainActor
final class CyrillicQuickAddChartCrashTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var window: UIWindow!

    /// See ChartRenderRegressionTests: a key window outlives the test, so the
    /// store must outlive it too or the leftover view graph traps on a destroyed
    /// model and mimics the very bug under investigation.
    private static var retainedContainers: [ModelContainer] = []

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        Self.retainedContainers.append(container)
        context = container.mainContext

        // The real default taxonomy — category resolution depends on it.
        SeedService.seedIfNeeded(modelContext: context)
        QuickAddSaveService._resetDedupCacheForTesting()
    }

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        context = nil
        container = nil
    }

    // MARK: - Real save path

    /// Parse + save exactly as the + sheet does, and report what the parser
    /// actually produced so a degenerate value is visible in the log even if the
    /// render survives.
    @discardableResult
    private func quickAdd(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> FinanceTracker.Transaction {
        guard let parsed = QuickAddParser.parse(text) else {
            XCTFail("QuickAddParser returned nil for \(text.debugDescription)", file: file, line: line)
            throw SkipError()
        }
        let tx = try QuickAddSaveService.save(
            parsed: parsed,
            modelContext: context,
            defaultCurrencyCode: "RUB"
        )
        let cat = tx.category
        print("""
        [QuickAdd] input=\(text.debugDescription) \
        amountCents=\(parsed.amountCents) type=\(parsed.typeRaw) \
        merchant=\(String(describing: parsed.merchant)) \
        suggested=\(String(describing: parsed.suggestedCategoryName)) \
        -> category.name=\(cat.name.debugDescription) \
        displayName=\(cat.displayName().debugDescription) \
        nameKey=\(String(describing: cat.nameKey)) \
        uuid=\(cat.uuid)
        """)
        return tx
    }

    private struct SkipError: Error {}

    private func render(_ view: some View, seconds: TimeInterval = 0.4) {
        let host = UIHostingController(rootView: view)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - The reported flow, in Cyrillic

    func test_cyrillic_twoTransactions_dashboardRenders() throws {
        let host = UIHostingController(rootView: DashboardView().modelContainer(container))
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        host.view.frame = w.bounds

        func pump() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        }
        pump()

        try quickAdd("кофе 350")
        pump()                      // save #1

        try quickAdd("продукты 1200")
        pump()                      // save #2  ← the reported crash point
    }

    func test_cyrillic_twoTransactions_analyticsRenders() throws {
        try quickAdd("кофе 350")
        try quickAdd("продукты 1200")
        render(AnalyticsView().modelContainer(container))
    }

    /// Bare Cyrillic word with no amount, and amount-first / mixed forms.
    func test_cyrillic_variants_parseAndRender() throws {
        let inputs = ["кофе 350", "350 кофе", "кофе", "12 кофе", "кофе 350 такси 120"]
        for input in inputs {
            guard let parsed = QuickAddParser.parse(input) else {
                print("[QuickAdd] input=\(input.debugDescription) -> parser returned nil")
                continue
            }
            print("[QuickAdd] input=\(input.debugDescription) amountCents=\(parsed.amountCents) merchant=\(String(describing: parsed.merchant)) suggested=\(String(describing: parsed.suggestedCategoryName))")
            _ = try? QuickAddSaveService.save(
                parsed: parsed,
                modelContext: context,
                defaultCurrencyCode: "RUB"
            )
        }
        render(DashboardView().modelContainer(container))
        render(AnalyticsView().modelContainer(container))
    }

    /// Mixed Latin + Cyrillic in one entry.
    func test_mixedLatinCyrillic_rendersDashboard() throws {
        try quickAdd("coffee кофе 350")
        try quickAdd("12 такси taxi")
        render(DashboardView().modelContainer(container))
    }

    // MARK: - Geometry, not data
    //
    // The device stack traps inside Charts with NO app frame on it: our content
    // closures are not executing, so Charts is failing in its own layout/scale
    // math on geometry it already holds. That happens when the plot area
    // collapses (a zero/negative width or height divides in the scale mapping).
    // The plot area collapses for reasons the simulator does not reproduce by
    // default — Dynamic Type and Bold Text inflate axis labels until the plot
    // between them has no room left.

    private func render(
        _ view: some View,
        sizeCategory: ContentSizeCategory,
        seconds: TimeInterval = 0.4
    ) {
        render(view.environment(\.sizeCategory, sizeCategory), seconds: seconds)
    }

    /// Every Dynamic Type step, largest first, with real Cyrillic data behind it.
    func test_dashboard_atEveryDynamicTypeSize_afterCyrillicSaves() throws {
        try quickAdd("кофе 350")
        try quickAdd("продукты 1200")

        for size in Self.allSizeCategories {
            print("[DynamicType] Dashboard @ \(size)")
            render(DashboardView().modelContainer(container), sizeCategory: size, seconds: 0.25)
        }
    }

    func test_analytics_atEveryDynamicTypeSize_afterCyrillicSaves() throws {
        try quickAdd("кофе 350")
        try quickAdd("продукты 1200")

        for size in Self.allSizeCategories {
            print("[DynamicType] Analytics @ \(size)")
            render(AnalyticsView().modelContainer(container), sizeCategory: size, seconds: 0.25)
        }
    }

    /// The charts in isolation at the accessibility sizes, where the axis labels
    /// are largest relative to the fixed chart heights (Pulse 240pt, Horizon 320pt).
    func test_charts_atAccessibilitySizes_inNarrowWidth() throws {
        try quickAdd("кофе 350")
        try quickAdd("продукты 1200")

        for size in Self.accessibilitySizeCategories {
            print("[DynamicType] Pulse+Horizon @ \(size)")
            render(AnalyticsView().modelContainer(container), sizeCategory: size, seconds: 0.25)
            render(DaySpendingSheet(day: Date(), currencyCode: "RUB").modelContainer(container),
                   sizeCategory: size, seconds: 0.25)
        }
    }

    private static let accessibilitySizeCategories: [ContentSizeCategory] = [
        .accessibilityMedium,
        .accessibilityLarge,
        .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge,
    ]

    private static let allSizeCategories: [ContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge,
        .extraExtraLarge, .extraExtraExtraLarge,
    ] + accessibilitySizeCategories

    /// The one chart in the app with a STRING domain: DaySpendingSheet plots
    /// `y: .value("category", slice.name)`. A blank or duplicate category name
    /// coming out of the Cyrillic path would collapse that categorical domain.
    func test_daySpendingSheet_stringDomain_afterCyrillicSaves() throws {
        try quickAdd("кофе 350")
        try quickAdd("продукты 1200")
        render(DaySpendingSheet(day: Date(), currencyCode: "RUB")
            .modelContainer(container))
    }
}
