//
//  ReportPDFRenderTests.swift
//  FinanceTrackerTests
//
//  PIXELS, not text (rule 5: PDFKit text extraction is inadmissible — it drops
//  U+2212 and U+2026 and has produced false results three ways). The idiom is
//  PDFExportRenderTests', rebuilt here rather than shared because that file is
//  the 1.0.5 guard and stays untouched: rasterize the cell the renderer says it
//  drew into, ink-crop it, and compare against a reference of the same string
//  drawn in the same font, right-aligned to the same edge, in a rect too wide
//  to clip. Ink-diff 0 = nothing was lost; a non-nil ink box = something was
//  drawn (presence, rule 4).
//
//  LOCALE MATRIX: `Money.format` follows the PROCESS locale, so the separator
//  and symbol placement rows of DESIGN §10.4 come from running this suite under
//  `-testLanguage xx -testRegion YY`; the currency column is iterated here.
//  Recorded runs are in the Phase 1 report.
//

import Foundation
import PDFKit
import SwiftData
import XCTest
@testable import FinanceTracker

final class ReportPDFRenderTests: XCTestCase {

    private static let pageSize = PDFExportService.pageSize
    private static let currencies = ["USD", "RUB", "MXN", "BRL", "UAH", "EUR", "JPY"]

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 2
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    // MARK: - Fixture: a month with big, awkward figures and ten categories (so "Other" folds)

    private static let labels: [UUID: ReportSnapshot.CategoryLabel] = {
        var d: [UUID: ReportSnapshot.CategoryLabel] = [:]
        for name in ["Groceries", "Rent", "Transport", "Health", "Utilities", "Dining", "Clothes", "Gifts", "Pets", "Books"] {
            d[UUID()] = .init(name: name, symbol: "tag", themeKey: name.lowercased())
        }
        return d
    }()

    private func snapshot() throws -> ReportSnapshot {
        let ids = Array(Self.labels.keys)
        var parents: [ReportInput.Parent] = []
        var rows: [CategoryAttribution.Row] = []
        // 1 234 567.89 down to 12.34 across ten categories, plus one income.
        let amounts = [123_456_789, 98_765_432, 7_654_321, 654_321, 54_321, 4_321, 321, 1_234, 12_345, 5]
        for (i, cents) in amounts.enumerated() {
            let p = ReportInput.Parent(uuid: UUID(), date: date(2026, 9, 1 + i), amountCents: cents, isIncome: false,
                                       merchant: "M\(i)", categoryLabel: Self.labels[ids[i]]!)
            parents.append(p)
            rows.append(.init(amountCents: cents, categoryUUID: ids[i], date: p.date, isIncome: false))
        }
        let pay = ReportInput.Parent(uuid: UUID(), date: date(2026, 9, 2), amountCents: 250_000_000, isIncome: true,
                                     merchant: nil, categoryLabel: Self.labels[ids[0]]!)
        parents.append(pay)
        let previous = [SafeToSpend.Entry(amountCents: 111_111_111, date: date(2026, 8, 3), isIncome: false),
                        SafeToSpend.Entry(amountCents: 200_000_000, date: date(2026, 8, 1), isIncome: true)]
        let input = ReportInput(parents: parents, rows: rows, labels: Self.labels, previousEntries: previous, limitedCategories: [])
        return try XCTUnwrap(ReportBuilder.build(input: input, period: .month(containing: date(2026, 9, 15)),
                                                 calendar: cal, monthlyBudgetCents: 300_000_000))
    }

    // MARK: - The guard

    /// Every amount cell on page 1 — summary (3 rows × up to 3 columns) and the
    /// categories table — renders byte-identical ink to a reference that cannot
    /// clip. Across seven currencies in whatever locale this process runs in.
    func testPage1MoneyCellsRenderWithoutLoss() throws {
        let s = try snapshot()
        var failures: [String] = []
        var cellsChecked = 0

        for currency in Self.currencies {
            let out = ReportPDFRenderer.makeReportPDFWithGeometry(
                snapshot: s, period: s.period, transactions: [], currencyCode: currency,
                includeTransactions: false, bundle: .main, locale: .current, calendar: cal
            )
            let document = try XCTUnwrap(PDFDocument(data: out.result.data), "\(currency): PDF did not parse")
            let page = try XCTUnwrap(document.page(at: 0), "\(currency): no page")
            let g = out.geometry
            let summaryLayout = try XCTUnwrap(g.summaryLayout, "\(currency): summary geometry not recorded")
            let categoryLayout = try XCTUnwrap(g.categoryLayout, "\(currency): category geometry not recorded")
            XCTAssertEqual(g.summaryRowYs.count, 3, "\(currency): three summary rows")
            XCTAssertEqual(g.categoryRowYs.count, ReportPDFRenderer.maxNamedCategories + 1, "\(currency): eight named + Other")

            for (i, row) in out.content.summary.enumerated() {
                let y = g.summaryRowYs[i]
                let cells: [(String, CGRect)] = [
                    (row.current, summaryLayout.valueRect(column: 0, rowY: y)),
                    (row.previous ?? "", summaryLayout.valueRect(column: 1, rowY: y)),
                    (row.change ?? "", summaryLayout.valueRect(column: 2, rowY: y)),
                ]
                for (text, rect) in cells where !text.isEmpty {
                    if let f = try check(page: page, text: text, font: summaryLayout.font, cell: rect, tag: "\(currency) summary[\(i)] \(text)") {
                        failures.append(f)
                    }
                    cellsChecked += 1
                }
            }
            for (i, row) in out.content.categories.enumerated() {
                let rect = categoryLayout.amountRect(rowY: g.categoryRowYs[i])
                if let f = try check(page: page, text: row.amount, font: categoryLayout.amountFont, cell: rect, tag: "\(currency) category[\(i)] \(row.amount)") {
                    failures.append(f)
                }
                cellsChecked += 1
            }
        }

        XCTAssertGreaterThanOrEqual(cellsChecked, 7 * (9 + 9), "the matrix did not run: \(cellsChecked) cells")
        XCTAssertTrue(failures.isEmpty, "money cells lost ink:\n" + failures.joined(separator: "\n"))
    }

    /// One visible control: a single cell, so its PASS is a line in the log.
    func testControlSingleSummaryCell() throws {
        let s = try snapshot()
        let out = ReportPDFRenderer.makeReportPDFWithGeometry(
            snapshot: s, period: s.period, transactions: [], currencyCode: "USD",
            includeTransactions: false, bundle: .main, locale: .current, calendar: cal
        )
        let page = try XCTUnwrap(PDFDocument(data: out.result.data)?.page(at: 0))
        let layout = try XCTUnwrap(out.geometry.summaryLayout)
        let text = out.content.summary[0].current
        XCTAssertNil(try check(page: page, text: text, font: layout.font, cell: layout.valueRect(column: 0, rowY: out.geometry.summaryRowYs[0]), tag: text))
    }

    /// The unavailable page draws the unavailable statement (presence) and no
    /// summary figures; the footer still numbers the page.
    func testUnavailableReportDrawsTheStatementNotANumber() throws {
        let out = ReportPDFRenderer.makeReportPDFWithGeometry(
            snapshot: nil, period: .month(containing: date(2026, 9, 15)), transactions: [], currencyCode: "USD",
            includeTransactions: false, bundle: .main, locale: .current, calendar: cal
        )
        XCTAssertNotNil(out.content.unavailable)
        XCTAssertTrue(out.content.summary.isEmpty)
        XCTAssertNil(out.geometry.summaryLayout, "no summary must be drawn on an unavailable report")
        let page = try XCTUnwrap(PDFDocument(data: out.result.data)?.page(at: 0))
        // Ink where the statement goes: below the three header lines, above the footer.
        let band = CGRect(x: PDFExportService.leftMargin, y: 100, width: 540, height: 120)
        let bitmap = try rasterize(page, pdfRect: Self.flipped(band), scale: 2)
        XCTAssertNotNil(bitmap.inkBox(), "the unavailable statement drew nothing")
        XCTAssertEqual(out.geometry.pages, 1)
    }

    /// A year with transactions on renders ≥ 3 pages, and the transaction
    /// table's amount column on page 2 is drawn by the SAME allocator the
    /// 1.0.5 guard pins (no second copy): its ink matches a reference too.
    @MainActor
    func testMultiPageYearUsesTheSharedTableAllocator() throws {
        let schema = Schema([Transaction.self, FinanceTracker.Category.self, Source.self, TransactionSplit.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let food = FinanceTracker.Category(name: "Food", kindRaw: "expense", icon: nil, order: 1)
        context.insert(food)
        var txs: [Transaction] = []
        for i in 0..<120 {
            let tx = Transaction(typeRaw: "expense", amountCents: 100_000 + i * 1_234_567, currency: "USD",
                                 date: cal.date(byAdding: .day, value: i * 3, to: date(2026, 1, 1))!,
                                 category: food, merchant: "Shop \(i)")
            context.insert(tx); txs.append(tx)
        }
        try context.save()
        let period = ReportPeriod.year(containing: date(2026, 6, 1))
        let categories = try context.fetch(FetchDescriptor<FinanceTracker.Category>())
        let input = LedgerAggregator.makeReportInput(transactions: txs, categories: categories, period: period, calendar: cal, bundle: .main)
        let s = try XCTUnwrap(ReportBuilder.build(input: input, period: period, calendar: cal, monthlyBudgetCents: 0))
        let sorted = txs.sorted { $0.date > $1.date }
        let out = ReportPDFRenderer.makeReportPDFWithGeometry(
            snapshot: s, period: period, transactions: sorted, currencyCode: "USD",
            includeTransactions: true, bundle: .main, locale: .current, calendar: cal
        )
        let document = try XCTUnwrap(PDFDocument(data: out.result.data))
        XCTAssertGreaterThanOrEqual(document.pageCount, 3, "120 rows after the analysis must paginate")
        XCTAssertEqual(out.geometry.pages, document.pageCount)

        // Page 2 starts with the table header (+24) at topMargin, then rows of rowHeight.
        let rows = PDFExportService.rowContents(sorted, currencyCode: "USD")
        let layout = PDFExportService.tableLayout(rows: rows, headers: .localized())
        let page2 = try XCTUnwrap(document.page(at: 1))
        let firstPageRows = Self.rowsOnPage1(out: out)
        let y = PDFExportService.topMargin + 24
        let row = rows[firstPageRows]
        XCTAssertNil(try check(page: page2, text: row.amount, font: layout.amountFont, cell: layout.amountRect(rowY: y), tag: "page 2 row 0 \(row.amount)"))
    }

    /// How many table rows fit on page 1 after the analysis — derived from the
    /// recorded geometry, not transcribed: the last category row's y, plus the
    /// row height, plus the section gap, plus the table header.
    private static func rowsOnPage1(out: (result: PDFExportResult, content: ReportPDFRenderer.Page1Content, geometry: ReportPDFRenderer.Page1Geometry)) -> Int {
        let lastCategoryY = out.geometry.categoryRowYs.last ?? 0
        let tableStart = lastCategoryY + PDFExportService.rowHeight + ReportPDFRenderer.sectionGap + 24
        let limit = pageSize.height - PDFExportService.bottomMargin
        return max(0, Int((limit - tableStart) / PDFExportService.rowHeight))
    }

    // MARK: - The check

    /// Nil = the cell's ink equals the reference's ink. A string otherwise.
    private func check(page: PDFPage, text: String, font: UIFont, cell: CGRect, tag: String) throws -> String? {
        let scale: CGFloat = 8
        let real = try rasterize(page, pdfRect: Self.flipped(cell), scale: scale)
        let reference = try referencePage(for: text, font: font, cell: cell)
        let ref = try rasterize(reference, pdfRect: Self.flipped(cell), scale: scale)
        guard let realBox = real.inkBox() else { return "\(tag): NO INK in the cell" }
        guard let refBox = ref.inkBox() else { return "\(tag): reference drew nothing (test bug)" }
        let a = real.cropped(to: realBox), b = ref.cropped(to: refBox)
        let diff = differingPixels(a, b)
        if diff != 0 {
            return "\(tag): ink differs by \(diff) px (real \(a.width)×\(a.height), ref \(b.width)×\(b.height))\n" + a.art().prefix(6).joined(separator: "\n")
        }
        return nil
    }

    private static func flipped(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: pageSize.height - r.maxY, width: r.width, height: r.height)
    }

    private func referencePage(for s: String, font: UIFont, cell: CGRect) throws -> PDFPage {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: Self.pageSize.height)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.alignment = .right
        let wide = CGRect(x: 8, y: cell.minY, width: cell.maxX - 8, height: cell.height)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            s.draw(in: wide, withAttributes: [.font: font, .paragraphStyle: style])
        }
        let document = try XCTUnwrap(PDFDocument(data: data))
        return try XCTUnwrap(document.page(at: 0))
    }

    private struct Bitmap {
        let width: Int, height: Int
        let pixels: [UInt8]
        func inkBox() -> (x0: Int, y0: Int, x1: Int, y1: Int)? {
            var x0 = width, y0 = height, x1 = -1, y1 = -1
            for y in 0..<height {
                for x in 0..<width where pixels[y * width + x] < 250 {
                    x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
                }
            }
            return x1 < 0 ? nil : (x0, y0, x1, y1)
        }
        func cropped(to box: (x0: Int, y0: Int, x1: Int, y1: Int)) -> Bitmap {
            let w = box.x1 - box.x0 + 1, h = box.y1 - box.y0 + 1
            var out = [UInt8](repeating: 255, count: w * h)
            for y in 0..<h { for x in 0..<w { out[y * w + x] = pixels[(y + box.y0) * width + (x + box.x0)] } }
            return Bitmap(width: w, height: h, pixels: out)
        }
        func art() -> [String] {
            let ramp = Array(" .:-=+*#%@")
            return (0..<height).map { y in
                "|" + (0..<width).map { x in
                    let v = Int(pixels[y * width + x])
                    return String(ramp[min(ramp.count - 1, max(0, (255 - v) * ramp.count / 256))])
                }.joined() + "|"
            }
        }
    }

    private func rasterize(_ page: PDFPage, pdfRect: CGRect, scale: CGFloat) throws -> Bitmap {
        let w = Int((pdfRect.width * scale).rounded()), h = Int((pdfRect.height * scale).rounded())
        let ctx = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -pdfRect.minX, y: -pdfRect.minY)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
        let stride = ctx.bytesPerRow
        let raw = try XCTUnwrap(ctx.data).assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 255, count: w * h)
        for y in 0..<h { for x in 0..<w { pixels[y * w + x] = raw[y * stride + x] } }
        return Bitmap(width: w, height: h, pixels: pixels)
    }

    private func differingPixels(_ a: Bitmap, _ b: Bitmap, tolerance: UInt8 = 8) -> Int {
        guard a.width == b.width, a.height == b.height else { return -1 }
        var n = 0
        for i in 0..<a.pixels.count where abs(Int(a.pixels[i]) - Int(b.pixels[i])) > Int(tolerance) { n += 1 }
        return n
    }
}
