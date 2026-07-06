//
//  ChartGuardsTests.swift
//  FinanceTrackerTests
//
//  Locks the single choke-point that keeps degenerate / non-finite values from
//  reaching Swift Charts (the fix for the device EXC_BREAKPOINT inside Charts).
//  Every assertion here maps to a concrete crash we observed or guarded:
//    - a zero-total donut (0/0 sweep angle)
//    - a single-point interpolated line (zero-width date domain / catmullRom ÷0)
//    - a NaN/±inf Double reaching a mark or a view dimension
//

import XCTest
@testable import FinanceTracker

final class ChartGuardsTests: XCTestCase {

    private struct Item { let cents: Int }

    // MARK: - Donut / SectorMark sanitation

    func test_renderableSlices_dropsNonPositive_andKeepsPositive() {
        let items = [Item(cents: 500), Item(cents: 0), Item(cents: -20), Item(cents: 300)]
        let kept = ChartGuards.renderableSlices(items, magnitude: \.cents)
        XCTAssertEqual(kept.map(\.cents), [500, 300], "0 and negative magnitudes must be dropped")
        // Every emitted magnitude is finite and strictly positive — nothing that
        // could produce a 0/0 or NaN sweep angle survives.
        XCTAssertTrue(kept.allSatisfy { $0.cents > 0 })
    }

    func test_renderableSlices_zeroTotal_returnsEmpty_forcingPlaceholder() {
        // Non-empty input, but every slice is 0 → total 0. Must collapse to empty
        // so the caller renders a placeholder instead of a degenerate SectorMark.
        let items = [Item(cents: 0), Item(cents: 0)]
        XCTAssertTrue(ChartGuards.renderableSlices(items, magnitude: \.cents).isEmpty)
    }

    func test_renderableSlices_emptyInput_returnsEmpty() {
        XCTAssertTrue(ChartGuards.renderableSlices([Item](), magnitude: \.cents).isEmpty)
    }

    func test_renderableSlices_allNegative_returnsEmpty() {
        let items = [Item(cents: -1), Item(cents: -99)]
        XCTAssertTrue(ChartGuards.renderableSlices(items, magnitude: \.cents).isEmpty)
    }

    // MARK: - Continuous (line / area) domain guard

    func test_canRenderContinuous_requiresAtLeastTwoPoints() {
        XCTAssertFalse(ChartGuards.canRenderContinuous(pointCount: 0))
        XCTAssertFalse(ChartGuards.canRenderContinuous(pointCount: 1),
                       "one point → zero-width domain / catmullRom ÷0 → Charts trap")
        XCTAssertTrue(ChartGuards.canRenderContinuous(pointCount: 2))
        XCTAssertTrue(ChartGuards.canRenderContinuous(pointCount: 31))
    }

    // MARK: - Non-finite coercion

    func test_finite_replacesNonFiniteWithZero_preservesSign() {
        XCTAssertEqual(ChartGuards.finite(.nan), 0)
        XCTAssertEqual(ChartGuards.finite(.infinity), 0)
        XCTAssertEqual(ChartGuards.finite(-.infinity), 0)
        XCTAssertEqual(ChartGuards.finite(42.5), 42.5)
        XCTAssertEqual(ChartGuards.finite(-42.5), -42.5, "legitimate negatives survive")
    }

    func test_dimension_clampsToFiniteNonNegative() {
        XCTAssertEqual(ChartGuards.dimension(.nan), 0)
        XCTAssertEqual(ChartGuards.dimension(-.infinity), 0)
        XCTAssertEqual(ChartGuards.dimension(-10), 0, "negative width/height → 0")
        XCTAssertEqual(ChartGuards.dimension(150), 150)
    }
}
