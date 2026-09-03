//
//  PDFExportRenderTests.swift
//  FinanceTrackerTests
//
//  GROUND TRUTH. PDFExportLayoutTests measures a MODEL of the drawing path
//  (`boundingRect(with:options:)` + CTTypesetterSuggestLineBreak). This file
//  measures the drawing path itself: it calls the real
//  `PDFExportService.makeMonthlyReportPDF`, which calls the real
//  `String.draw(in:withAttributes:)` on the real 56×16 amount cell, and then
//  reads the resulting PDF back two independent ways.
//
//  Nothing here re-implements the drawing. The service's row drawing is private,
//  but it is reachable in full through `makeMonthlyReportPDF` with a one-row
//  in-memory store — the same route FrozenArtifactLanguageTests already uses.
//  The only thing this file transcribes is WHERE the amount cell is, and that
//  transcription is self-checked at runtime (see `verifyRowGeometry`) rather
//  than trusted.
//
//  ── WHAT EACH READING IS FOR ────────────────────────────────────────────────
//  READING 1 (positional, PDFKit): what text is POSITIONED inside the cell. A
//  wrapped second line is laid out below the rect, so its glyphs should fall
//  outside and not be selected. Defeatable if the drawing path emits clipped
//  glyphs at in-rect coordinates anyway — in which case this reading pins
//  nothing and must be dropped rather than shipped.
//
//  READING 2 (visual, bitmap): rasterise the cell out of the real PDF, and
//  rasterise the SAME string drawn by the SAME rasteriser into a deliberately
//  oversized rect. Compare pixels. This catches mid-glyph clipping, which
//  Reading 1 over-reports because a glyph can be positioned inside the rect and
//  still be visually cut in half. No OCR anywhere.
//
//  ── PDFKit TEXT EXTRACTION IS NOT ADMISSIBLE EVIDENCE HERE ──────────────────
//  PDFKit text extraction is NOT admissible evidence about this PDF's rendering,
//  in any form. It has been wrong three times, in three different ways, and each
//  time it was wrong in the direction of looking correct. Pixels only. Any future
//  "cheap check" built on PDFDocument.string, page.selection or characterBounds
//  is prohibited — it will be green and it will mean nothing.
//
//  The three:
//    1. U+2212 MINUS SIGN is never reported. The ru_RU control's cell is
//       byte-identical to the unconstrained render — the minus is demonstrably on
//       the page — and the selection still comes back "89,90 $". Reading 1 had to
//       be made sign-blind, which costs it the ability to catch a lost sign.
//    2. U+2026 is never reported either. `.byTruncatingTail` draws a visible
//       ellipsis; the extracted text is "−4 000,0" with no ellipsis in it. The
//       ellipsis assertion had to be moved to pixel geometry (dots sit low and
//       short on the baseline; digits fill the x-height).
//    3. `page.string`'s character indices do NOT map to `characterBounds(at:)`.
//       The drift grows with the text above, and it silently relocated a row
//       lookup into the PAGE FOOTER. Selection also bleeds across the column gap
//       and returns the trailing "d" of "Uncategorized" attached to the amount.
//
//  What (3) cost, recorded so the next reader does not repeat it: the first
//  version of the multi-page check reported FIVE failures of the form
//  'page 1, last row R029: the amount cell contains "" but the row's amount is
//  "89,90 US$"' — the exact shape of the defect this suite exists to catch, all
//  five false. The second version, still text-based, reported three more of the
//  form 'contains "d89,90 US$"'. The render was correct the whole time. The check
//  that finally held rasterises a strip of the amount column, groups bands of
//  ink, and compares them ink-cropped — no text, and no coordinates either.
//
//  Comparison is done on INK-CROPPED bitmaps (each cropped to its own ink
//  bounding box) as well as raw ones. Ink-cropping makes the reading survive the
//  eventual fix's change of alignment: right-aligning the amount moves the ink
//  without losing any of it, and only the raw comparison would (wrongly) call
//  that a failure.
//

import XCTest
import PDFKit
import SwiftData
import UIKit
@testable import FinanceTracker

final class PDFExportRenderTests: XCTestCase {

    // MARK: - Corpus

    private struct Case {
        let currencyCode: String
        let cents: Int
        let note: String
        let isControl: Bool

        init(_ currencyCode: String, _ cents: Int, _ note: String, isControl: Bool = false) {
            self.currencyCode = currencyCode
            self.cents = cents
            self.note = note
            self.isControl = isControl
        }
    }

    /// The five cases named in the brief. The LOCALE is the process locale — the
    /// service formats through `Money.formatSigned`, whose formatter is pinned to
    /// `.autoupdatingCurrent`, so it cannot be varied per-case from inside the
    /// process. Run the bundle under `-testLanguage ru -testRegion RU` to put
    /// Elena's exact string through this path. Every assertion below is written
    /// against the string this run actually produced, so the file is honest in
    /// any locale.
    ///
    /// HOW TO RUN IT, and why the locale is not optional:
    ///     scripts/run-tests.sh -only-testing:FinanceTrackerTests/PDFExportRenderTests \
    ///         -testLanguage ru -testRegion RU        # Elena's exact string
    ///     …                                -testLanguage en -testRegion US
    ///     …                                -testLanguage de -testRegion DE
    ///
    /// Observed 2026-08-26: under ru_RU and en_US the control renders in full and
    /// both controls are GREEN. Under the simulator's own default (en_RU) and
    /// under de/DE the control is RED — and correctly so. In those locales USD
    /// formats as "−89,90 US$" (68.12pt), so the 56pt column cannot fit EIGHTY-NINE
    /// DOLLARS. That is not the control breaking; it is the column being too narrow
    /// for every amount those locales can produce.
    private static let corpus: [Case] = [
        Case("RUB", 400_000, "Elena's exact amount"),
        Case("RUB",  25_000, "the row that loses only its currency symbol"),
        Case("USD", 123_456, "the bare-minus case"),
        Case("EUR", 123_456, "de_DE grouping"),
        // Predicted from the mechanism to render "−12"; now measured instead.
        Case("RUB", 1_234_567, "two grouping separators"),
        // An English interface in Russia: RUB formats with the CODE, not the
        // symbol, so eighty-nine roubles is wider than four thousand dollars.
        Case("RUB",   8_990, "small amount, en-language RUB"),
        Case("USD",   8_990, "CONTROL — must render in full", isControl: true)
    ]

    // MARK: - Geometry (transcribed from PDFExportService, self-checked at runtime)

    private static let pageSize = CGSize(width: 612, height: 792)
    /// y of the FIRST body row in the service's top-left drawing space:
    /// topMargin 36 → title +30 → subtitle +18 → +12 → summary 3×18 → +16 → header +24.
    /// The vertical block above the table is fixed-height, so this is a constant —
    /// and it is checked at runtime by `verifyRowGeometry`, not trusted.
    private static let firstRowTopLeftY: CGFloat = 190
    private static let rowMarker = "ROWMARK"

    /// The COLUMN geometry is no longer transcribed at all: it is read from the
    /// service's own `TableLayout`, the single source the header row and the body
    /// rows both draw from. A test that copies column literals is a second source,
    /// and a second source is the defect this fix removed.

    private static var rowFont: UIFont { UIFont.systemFont(ofSize: 12, weight: .regular) }

    /// UIKit top-left drawing space → PDF user space (origin bottom-left).
    private static func flipped(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: pageSize.height - r.maxY, width: r.width, height: r.height)
    }

    /// The cell plus 20pt BELOW it — where a wrapped second line would land if
    /// `draw(in:)` did not clip to its rect. Evidence, not a guard.
    private static func plusBelow(_ cell: CGRect) -> CGRect {
        CGRect(x: cell.minX, y: cell.minY - 20, width: cell.width, height: cell.height + 20)
    }

    // MARK: - The real render

    private struct Rendered {
        let page: PDFPage
        /// Exactly the string `drawTransactionRow` handed to `.draw(in:)`.
        let amount: String
        let unconstrainedWidth: CGFloat
        /// The amount cell, in the service's own top-left drawing space.
        let amountCell: CGRect
        let amountFont: UIFont
        let layout: PDFExportService.TableLayout
    }

    private func renderRealPDF(_ c: Case) throws -> Rendered {
        let schema = Schema([Transaction.self, Category.self, Source.self, TransactionSplit.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.insert(
            Transaction(
                typeRaw: "expense",
                amountCents: c.cents,
                currency: c.currencyCode,
                date: Date(),
                category: nil,
                merchant: Self.rowMarker
            )
        )

        let result = try PDFExportService.makeMonthlyReportPDF(
            modelContext: context,
            scope: .all,
            currencyCode: c.currencyCode
        )
        let document = try XCTUnwrap(PDFDocument(data: result.data), "PDF did not parse")
        let page = try XCTUnwrap(document.page(at: 0), "PDF has no first page")

        // The row the service formatted, and the geometry it allocated for it —
        // both read from the service, neither re-derived here.
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        let rows = PDFExportService.rowContents(txs, currencyCode: c.currencyCode)
        let layout = PDFExportService.tableLayout(rows: rows, headers: .localized())
        let amount = try XCTUnwrap(rows.first?.amount, "the store produced no row")
        let cell = layout.amountRect(rowY: Self.firstRowTopLeftY)
        let w = (amount as NSString).size(withAttributes: [.font: layout.amountFont]).width

        try verifyRowGeometry(page: page, cell: cell, label: "\(c.currencyCode) \(c.cents)")
        _ = container // keep the container alive for the duration of the render
        return Rendered(page: page, amount: amount, unconstrainedWidth: w,
                        amountCell: cell, amountFont: layout.amountFont, layout: layout)
    }

    /// The one transcription in this file, checked instead of trusted: the row
    /// marker drawn in the title column of the first body row must sit inside the
    /// 16pt band this file believes the first row occupies. If the service's
    /// vertical layout ever moves, this fails loudly instead of silently reading
    /// an empty rectangle.
    private func verifyRowGeometry(page: PDFPage, cell: CGRect, label: String) throws {
        let text = page.string ?? ""
        let ns = text as NSString
        let range = ns.range(of: Self.rowMarker)
        XCTAssertNotEqual(range.location, NSNotFound,
                          "\(label): row marker \"\(Self.rowMarker)\" is not in the PDF text at all")
        guard range.location != NSNotFound else { return }

        let bounds = page.characterBounds(at: range.location)
        let band = Self.flipped(cell)
        XCTAssertTrue(bounds.midY > band.minY && bounds.midY < band.maxY,
            "\(label): first body row is not where this file thinks it is. Marker glyph "
            + "midY=\(bounds.midY), expected inside the cell band \(band.minY)…\(band.maxY). "
            + "Every measurement below would be reading the wrong rectangle.")
    }

    // MARK: - The reference render (same string, deliberately oversized rect)

    /// The same string, the same font, the same origin, the same rasteriser — but
    /// a rect wide enough that nothing can wrap and tall enough that nothing can
    /// clip. The page is deliberately wider than US Letter so the oversized rect
    /// fits on it; the comparison only ever reads x ∈ [520, 576], which is
    /// identical in both documents.
    ///
    /// The rect keeps the production cell's RIGHT edge and extends far to the
    /// left, and the text is right-aligned exactly as the service aligns it. That
    /// matters: it puts every glyph at the same sub-pixel x as the real render, so
    /// a correct render compares byte-identical instead of merely similar.
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
        let document = try XCTUnwrap(PDFDocument(data: data), "reference PDF did not parse")
        return try XCTUnwrap(document.page(at: 0), "reference PDF has no page")
    }

    // MARK: - Rasterisation

    private struct Bitmap {
        let width: Int
        let height: Int
        let pixels: [UInt8]   // 8-bit grey, 255 = paper

        func inkBox() -> (x0: Int, y0: Int, x1: Int, y1: Int)? {
            var x0 = width, y0 = height, x1 = -1, y1 = -1
            for y in 0..<height {
                for x in 0..<width where pixels[y * width + x] < 250 {
                    x0 = min(x0, x); x1 = max(x1, x)
                    y0 = min(y0, y); y1 = max(y1, y)
                }
            }
            return x1 < 0 ? nil : (x0, y0, x1, y1)
        }

        func cropped(to box: (x0: Int, y0: Int, x1: Int, y1: Int)) -> Bitmap {
            let w = box.x1 - box.x0 + 1
            let h = box.y1 - box.y0 + 1
            var out = [UInt8](repeating: 255, count: w * h)
            for y in 0..<h {
                for x in 0..<w {
                    out[y * w + x] = pixels[(y + box.y0) * width + (x + box.x0)]
                }
            }
            return Bitmap(width: w, height: h, pixels: out)
        }

        /// Not OCR — a human-readable dump of the pixels, so a reader of the log
        /// can see what is in the cell without opening the PDF.
        func art() -> [String] {
            let ramp = Array(" .:-=+*#%@")
            var rows: [String] = []
            for y in 0..<height {
                var line = ""
                for x in 0..<width {
                    let v = Int(pixels[y * width + x])
                    let idx = min(ramp.count - 1, max(0, (255 - v) * ramp.count / 256))
                    line.append(ramp[idx])
                }
                rows.append("|" + line + "|")
            }
            return rows
        }
    }

    private func rasterize(_ page: PDFPage, pdfRect: CGRect, scale: CGFloat) throws -> Bitmap {
        let w = Int((pdfRect.width * scale).rounded())
        let h = Int((pdfRect.height * scale).rounded())
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), "could not create a bitmap context")

        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -pdfRect.minX, y: -pdfRect.minY)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        let stride = ctx.bytesPerRow
        let base = try XCTUnwrap(ctx.data, "bitmap context has no backing store")
        let raw = base.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 255, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                pixels[y * w + x] = raw[y * stride + x]
            }
        }
        return Bitmap(width: w, height: h, pixels: pixels)
    }

    private func differingPixels(_ a: Bitmap, _ b: Bitmap, tolerance: UInt8 = 8) -> Int {
        guard a.width == b.width, a.height == b.height else { return -1 }
        var n = 0
        for i in 0..<a.pixels.count {
            let d = Int(a.pixels[i]) - Int(b.pixels[i])
            if abs(d) > Int(tolerance) { n += 1 }
        }
        return n
    }

    // MARK: - Per-case measurement, used by every test below

    private struct Measurement {
        let amount: String
        let unconstrainedWidth: CGFloat
        let cell: CGRect
        let amountFontSize: CGFloat
        /// READING 1
        let selectedInCell: String
        /// READING 1, cell inflated 1pt horizontally — PDFKit drops a glyph that
        /// starts exactly on the rect edge, which is where the leading sign sits.
        let selectedInInflatedCell: String
        /// The code points actually drawn. The whole ru/de question is whether the
        /// grouping separator is breakable, and only the scalars can settle it.
        let scalars: String
        /// READING 2
        let rawDiff: Int
        let inkDiff: Int
        let inkSizeReal: String
        let inkSizeReference: String
        let art: [String]
        let artBelow: [String]
    }

    private func measure(_ c: Case) throws -> Measurement {
        let real = try renderRealPDF(c)
        let reference = try referencePage(for: real.amount, font: real.amountFont, cell: real.amountCell)
        let cellPDF = Self.flipped(real.amountCell)

        let selection = real.page.selection(for: cellPDF)?.string ?? ""
        let inflated = real.page.selection(for: cellPDF.insetBy(dx: -1, dy: 0))?.string ?? ""
        let scalars = real.amount.unicodeScalars
            .map { String(format: "U+%04X", $0.value) }.joined(separator: " ")

        let scale: CGFloat = 8
        let realCell = try rasterize(real.page, pdfRect: cellPDF, scale: scale)
        let refCell = try rasterize(reference, pdfRect: cellPDF, scale: scale)

        let rawDiff = differingPixels(realCell, refCell)

        var inkDiff = -1
        var realInkSize = "no ink"
        var refInkSize = "no ink"
        if let rb = realCell.inkBox(), let fb = refCell.inkBox() {
            let rc = realCell.cropped(to: rb)
            let fc = refCell.cropped(to: fb)
            realInkSize = "\(rc.width)×\(rc.height)"
            refInkSize = "\(fc.width)×\(fc.height)"
            inkDiff = differingPixels(rc, fc)
        } else if realCell.inkBox() == nil && refCell.inkBox() == nil {
            inkDiff = 0
            realInkSize = "no ink"; refInkSize = "no ink"
        }

        let art = try rasterize(real.page, pdfRect: cellPDF, scale: 1).art()
        let artBelow = try rasterize(real.page, pdfRect: Self.plusBelow(cellPDF), scale: 1).art()

        return Measurement(amount: real.amount,
                           unconstrainedWidth: real.unconstrainedWidth,
                           cell: real.amountCell,
                           amountFontSize: real.amountFont.pointSize,
                           selectedInCell: selection,
                           selectedInInflatedCell: inflated,
                           scalars: scalars,
                           rawDiff: rawDiff, inkDiff: inkDiff,
                           inkSizeReal: realInkSize, inkSizeReference: refInkSize,
                           art: art, artBelow: artBelow)
    }

    /// Text-reading normalisation, and every part of it is a concession forced by
    /// a MEASURED instrument artifact, not a convenience:
    ///
    ///  • U+2212 MINUS SIGN is removed from BOTH sides. PDFKit's text extraction
    ///    does not report it even when it is unquestionably drawn: in the ru_RU
    ///    control the cell's pixels are byte-identical to the unconstrained render
    ///    (Reading 2, ink-diff 0) — the minus is on the page — yet the selection
    ///    comes back "89,90 $". Without this, Reading 1 could never go green for
    ///    any amount at all, and a guard that cannot be satisfied is not a guard.
    ///    THE COST IS REAL AND MUST BE STATED: Reading 1 is therefore blind to a
    ///    lost sign. A PDF that printed +4 000,00 ₽ for an expense would pass it.
    ///    Only Reading 2 can catch that, which is one more reason Reading 2 is the
    ///    guard and this one is corroboration.
    ///
    ///  • U+00A0 is folded to a space, because the extractor reports the drawn
    ///    NBSP as an ordinary space.
    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{2212}", with: "")
         .replacingOccurrences(of: "-", with: "")
         .replacingOccurrences(of: "\u{00A0}", with: " ")
         .replacingOccurrences(of: "\n", with: "")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - READING 1 — positional

    /// The text POSITIONED inside the amount cell must be the whole amount.
    func testReading1_TextInAmountCellIsTheWholeAmount() throws {
        var failures: [String] = []
        for c in Self.corpus {
            let m = try measure(c)
            let got = normalize(m.selectedInInflatedCell)
            let want = normalize(m.amount)
            if got != want {
                failures.append("  \(c.currencyCode) \(c.cents) (\(c.note)): drew \"\(m.amount)\" "
                    + "(\(String(format: "%.2f", m.unconstrainedWidth))pt in a "
                    + "\(String(format: "%.2f", m.cell.width))pt column) but the amount cell "
                    + "contains only \"\(got)\"  [cell-exact reading: \"\(normalize(m.selectedInCell))\"]")
            }
        }
        XCTAssertTrue(failures.isEmpty,
            "\(failures.count) of \(Self.corpus.count) amounts are not fully positioned inside "
            + "their allocated cell in the REAL rendered PDF:\n"
            + failures.joined(separator: "\n"))
    }

    /// The control, asserted alone so its PASS is visible in the result bundle.
    func testReading1_ControlRendersInFull() throws {
        let c = try XCTUnwrap(Self.corpus.first { $0.isControl })
        let m = try measure(c)
        XCTAssertEqual(normalize(m.selectedInInflatedCell), normalize(m.amount),
            "CONTROL BROKEN (Reading 1): \"\(m.amount)\" is \(String(format: "%.2f", m.unconstrainedWidth))pt "
            + "and must render in full; the cell contains \"\(normalize(m.selectedInInflatedCell))\"")
    }

    // MARK: - READING 2 — visual

    /// The pixels in the amount cell must be the pixels of the same string drawn
    /// with nothing constraining it. Compared ink-cropped, so alignment may change
    /// but ink may not go missing.
    func testReading2_AmountCellPixelsMatchTheUnconstrainedRender() throws {
        var failures: [String] = []
        for c in Self.corpus {
            let m = try measure(c)
            if m.inkDiff != 0 {
                failures.append("  \(c.currencyCode) \(c.cents) (\(c.note)): \"\(m.amount)\" — "
                    + "ink in cell \(m.inkSizeReal) vs unconstrained \(m.inkSizeReference), "
                    + "\(m.inkDiff < 0 ? "different size" : "\(m.inkDiff) px differ") "
                    + "(raw window diff \(m.rawDiff) px)")
            }
        }
        XCTAssertTrue(failures.isEmpty,
            "\(failures.count) of \(Self.corpus.count) amount cells do not visually contain the "
            + "amount that was drawn into them:\n" + failures.joined(separator: "\n"))
    }

    func testReading2_ControlRendersInFull() throws {
        let c = try XCTUnwrap(Self.corpus.first { $0.isControl })
        let m = try measure(c)
        XCTAssertEqual(m.inkDiff, 0,
            "CONTROL BROKEN (Reading 2): \"\(m.amount)\" renders as \(m.inkSizeReal) of ink where "
            + "the unconstrained render is \(m.inkSizeReference). If the control cannot match, the "
            + "rasterisation pipeline is wrong and neither reading means anything.")
    }

    // MARK: - The premise of the fix, measured rather than assumed

    /// Constraint (a) of the fix says `.byTruncatingTail` makes silent loss
    /// impossible. The documentation implies that; this drawing path has already
    /// been caught not behaving the way the documentation implies, so it is
    /// measured here on the exact string that started this — with the NBSP
    /// grouping separator that CoreText swears is unbreakable and that
    /// `draw(in:)` breaks anyway.
    ///
    /// Both halves matter. WITHOUT the style the text must still be silently
    /// lost — if that ever stops being true, this whole instrument has lost its
    /// premise and should be re-derived rather than trusted.
    func testTruncatingTailSuppressesTheNBSPWrapAndLeavesAnEllipsis() throws {
        let s = "\u{2212}4\u{00A0}000,00\u{00A0}\u{20BD}"   // −4 000,00 ₽
        let font = Self.rowFont
        let cell = CGRect(x: 100, y: 100, width: 56, height: 16)

        func render(_ style: NSParagraphStyle?) throws -> PDFPage {
            var attrs: [NSAttributedString.Key: Any] = [.font: font]
            if let style { attrs[.paragraphStyle] = style }
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Self.pageSize))
            let data = renderer.pdfData { ctx in
                ctx.beginPage()
                s.draw(in: cell, withAttributes: attrs)
            }
            let doc = try XCTUnwrap(PDFDocument(data: data))
            return try XCTUnwrap(doc.page(at: 0))
        }

        let truncating = NSMutableParagraphStyle()
        truncating.lineBreakMode = .byTruncatingTail

        let bare = try render(nil)
        let styled = try render(truncating)
        let window = Self.flipped(cell)

        let bareInk = try XCTUnwrap(rasterize(bare, pdfRect: window, scale: 8).inkBox(),
                                    "the unstyled render put no ink in the cell at all")
        let styledInk = try XCTUnwrap(rasterize(styled, pdfRect: window, scale: 8).inkBox(),
                                      "the truncating render put no ink in the cell at all")
        let bareWidth = CGFloat(bareInk.x1 - bareInk.x0 + 1) / 8
        let styledWidth = CGFloat(styledInk.x1 - styledInk.x0 + 1) / 8
        let styledText = styled.selection(for: window)?.string ?? ""

        let bareArt = try rasterize(bare, pdfRect: window, scale: 1).art()
        let styledArt = try rasterize(styled, pdfRect: window, scale: 1).art()
        var premise: [String] = []
        premise.append("")
        premise.append("PARAGRAPH-STYLE PREMISE — \"\(s)\" in a \(cell.width)pt × \(cell.height)pt cell")
        premise.append(String(repeating: "─", count: 78))
        premise.append("  NO STYLE (what shipped): ink \(String(format: "%.2f", bareWidth))pt wide")
        premise.append(contentsOf: bareArt.map { "    " + $0 })
        premise.append("  byTruncatingTail: ink \(String(format: "%.2f", styledWidth))pt wide, "
                       + "extracted text \"\(styledText)\"")
        premise.append(contentsOf: styledArt.map { "    " + $0 })
        premise.append(String(repeating: "─", count: 78))
        print(premise.joined(separator: "\n"))

        XCTAssertLessThan(bareWidth, 20,
            "PREMISE GONE: without a paragraph style this path used to keep only \"−4\" "
            + "(about 14pt of ink). It now keeps \(bareWidth)pt. The defect this suite "
            + "was built for no longer reproduces, so re-derive the instrument.")

        XCTAssertGreaterThan(styledWidth, 40,
            "byTruncatingTail did NOT suppress the NBSP wrap: the cell still holds only "
            + "\(styledWidth)pt of ink, so the line still broke at the NBSP instead of "
            + "filling the column and truncating.")

        // The ellipsis has to be asserted VISUALLY, and the reason is itself a
        // finding: PDFKit does not report U+2026 in extracted text any more than it
        // reports U+2212. The styled cell above extracts as "−4 000,0" while the
        // pixels plainly show three dots after it. Text extraction is not a witness
        // to what a reader of the PDF sees; pixels are.
        //
        // Signature of an ellipsis: the trailing ink sits on the baseline and is
        // short. Digits fill the x-height; three dots do not.
        let styledBitmap = try rasterize(styled, pdfRect: window, scale: 8)
        let box = try XCTUnwrap(styledBitmap.inkBox())
        let tailFrom = max(box.x0, box.x1 - Int(6 * 8))   // last 6pt of ink
        var tailTop = box.y1
        var tailBottom = box.y0
        for y in box.y0...box.y1 {
            for x in tailFrom...box.x1 where styledBitmap.pixels[y * styledBitmap.width + x] < 250 {
                tailTop = min(tailTop, y)
                tailBottom = max(tailBottom, y)
            }
        }
        let tailHeight = CGFloat(tailBottom - tailTop + 1) / 8
        let inkHeight = CGFloat(box.y1 - box.y0 + 1) / 8
        print("  ellipsis check      : trailing 6pt of ink is \(String(format: "%.2f", tailHeight))pt tall "
              + "against a \(String(format: "%.2f", inkHeight))pt line; extracted text "
              + "\"\(styledText)\" (PDFKit reports neither U+2026 nor U+2212)")

        XCTAssertLessThan(tailHeight, inkHeight * 0.45,
            "byTruncatingTail dropped text without a visible ellipsis: the trailing ink is "
            + "\(tailHeight)pt tall in a \(inkHeight)pt line, which is glyph-shaped, not "
            + "dot-shaped. Truncation that leaves no cue is the same defect class as the "
            + "clipping it replaced.")
    }

    // MARK: - C1 — MULTI-PAGE

    /// Every other case in this file is a ONE-ROW report. Elena's real export
    /// spans pages, and the fix restructured code that runs per page: the table
    /// header is redrawn in a different call context on page 2+.
    ///
    /// The fixture is built so that a per-page allocation could not hide: 79 rows
    /// of −$89.90 and ONE row of −$999,999,999.99, placed LAST so it lands on the
    /// final page. If columns were sized per page, pages 1–2 would be laid out for
    /// a narrow amount and the last page for a wide one, and the header ink would
    /// not line up between pages.
    ///
    /// The geometry assertions read INK POSITIONS out of the rendered pages, in
    /// absolute page coordinates. They do not consult the layout, so they cannot
    /// be satisfied by a test and a service agreeing with each other about a wrong
    /// answer.
    func testMultiPageColumnGeometryIsIdenticalOnEveryPage() throws {
        let schema = Schema([Transaction.self, Category.self, Source.self, TransactionSplit.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rowCount = 80
        let base = Date(timeIntervalSince1970: 1_760_000_000)
        for i in 0..<rowCount {
            context.insert(
                Transaction(
                    typeRaw: "expense",
                    amountCents: (i == rowCount - 1) ? 99_999_999_999 : 8_990,
                    currency: "USD",
                    date: base.addingTimeInterval(-Double(i) * 86_400),
                    category: nil,
                    merchant: String(format: "R%03d", i)
                )
            )
        }

        let result = try PDFExportService.makeMonthlyReportPDF(
            modelContext: context, scope: .all, currencyCode: "USD")
        let doc = try XCTUnwrap(PDFDocument(data: result.data), "PDF did not parse")
        XCTAssertGreaterThanOrEqual(doc.pageCount, 3,
            "the fixture must span at least three pages; it produced \(doc.pageCount)")

        let txs = try context.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let rows = PDFExportService.rowContents(txs, currencyCode: "USD")
        let layout = PDFExportService.tableLayout(rows: rows, headers: .localized())
        let headers = PDFExportService.HeaderLabels.localized()

        var out: [String] = []
        out.append("")
        out.append("MULTI-PAGE — \(doc.pageCount) pages, \(rowCount) rows, widest amount on the LAST page")
        out.append(String(repeating: "═", count: 96))

        // (a)+(b): the repeated header, measured in absolute page coordinates.
        var headerBoxes: [(page: Int, x0: Int, x1: Int)] = []
        var headerCrops: [Bitmap] = []
        let scale: CGFloat = 4
        for p in 0..<doc.pageCount {
            let page = try XCTUnwrap(doc.page(at: p))
            let text = (page.string ?? "") as NSString
            let r = text.range(of: headers.date)
            XCTAssertNotEqual(r.location, NSNotFound,
                "page \(p + 1) carries no table header — the header is not repeated")
            guard r.location != NSNotFound else { continue }
            let b = page.characterBounds(at: r.location)
            let band = CGRect(x: PDFExportService.tableLeft - 2,
                              y: b.minY - 4,
                              width: PDFExportService.tableRight - PDFExportService.tableLeft + 4,
                              height: b.height + 8)
            let bmp = try rasterize(page, pdfRect: band, scale: scale)
            let box = try XCTUnwrap(bmp.inkBox(), "page \(p + 1) header band has no ink")
            headerBoxes.append((p + 1, box.x0, box.x1))
            headerCrops.append(bmp.cropped(to: box))
            out.append(String(format: "  page %d header ink: x %.2f … %.2f pt (absolute)",
                              p + 1,
                              PDFExportService.tableLeft - 2 + CGFloat(box.x0) / scale,
                              PDFExportService.tableLeft - 2 + CGFloat(box.x1) / scale))
        }

        let firstBox = try XCTUnwrap(headerBoxes.first)
        for hb in headerBoxes.dropFirst() {
            XCTAssertEqual(hb.x0, firstBox.x0,
                "page \(hb.page)'s header starts at a different x than page \(firstBox.page)'s — "
                + "the columns MOVED between pages, so the allocation is per-page")
            XCTAssertEqual(hb.x1, firstBox.x1,
                "page \(hb.page)'s header ends at a different x than page \(firstBox.page)'s")
        }
        let firstCrop = try XCTUnwrap(headerCrops.first)
        for (i, crop) in headerCrops.enumerated().dropFirst() {
            XCTAssertEqual(differingPixels(firstCrop, crop), 0,
                "page \(i + 1)'s header is not pixel-identical to page 1's. Same strings, same "
                + "font — so any difference is COLUMN GEOMETRY differing between pages.")
        }

        // (c): the rows that straddle a page break, and the wide row on the last page.
        // ── Rows are found in PIXELS, not in PDFKit's text ──────────────────
        // page.string's character indices do NOT map to characterBounds(at:) —
        // the offsets drift by roughly a row per page of text, which put an
        // earlier version of this check in the FOOTER and produced a confident,
        // wrong failure. Text extraction here also reaches across the column gap
        // and returns the trailing "d" of "Uncategorized" with the amount.
        //
        // So: rasterise a vertical strip of the amount column, find the bands of
        // ink, and compare each band's ink against the unconstrained render of the
        // amount that band is supposed to hold. Ink-cropping is translation
        // invariant, so this needs no row coordinates at all.
        let stripScale: CGFloat = 4
        let footerFreeBottom: CGFloat = 52   // PDF y below this is the page footer

        func amountBands(_ page: PDFPage) throws -> [Bitmap] {
            let strip = CGRect(x: layout.amountX, y: footerFreeBottom,
                               width: layout.amountWidth,
                               height: Self.pageSize.height - footerFreeBottom)
            let bmp = try rasterize(page, pdfRect: strip, scale: stripScale)
            var bands: [Bitmap] = []
            var y = 0
            while y < bmp.height {
                var inked = false
                for x in 0..<bmp.width where bmp.pixels[y * bmp.width + x] < 250 { inked = true; break }
                if !inked { y += 1; continue }
                var end = y
                var gap = 0
                var scan = y
                while scan < bmp.height, gap < 3 {
                    var rowInk = false
                    for x in 0..<bmp.width where bmp.pixels[scan * bmp.width + x] < 250 { rowInk = true; break }
                    if rowInk { end = scan; gap = 0 } else { gap += 1 }
                    scan += 1
                }
                let slice = bmp.cropped(to: (x0: 0, y0: y, x1: bmp.width - 1, y1: end))
                if let box = slice.inkBox() {
                    let cropped = slice.cropped(to: box)
                    // The header's separator rule crosses this strip and is a band
                    // like any other — 1pt tall against ~12pt of text. Drop rules.
                    if cropped.height >= Int(3 * stripScale) { bands.append(cropped) }
                }
                y = end + 1
            }
            return bands
        }

        func referenceInk(_ amount: String) throws -> Bitmap {
            let cell = layout.amountRect(rowY: Self.firstRowTopLeftY)
            let refPage = try referencePage(for: amount, font: layout.amountFont, cell: cell)
            let strip = CGRect(x: layout.amountX, y: footerFreeBottom,
                               width: layout.amountWidth,
                               height: Self.pageSize.height - footerFreeBottom)
            let bmp = try rasterize(refPage, pdfRect: strip, scale: stripScale)
            let box = try XCTUnwrap(bmp.inkBox(), "reference render for \"\(amount)\" has no ink")
            return bmp.cropped(to: box)
        }

        out.append("")
        out.append("  rows found by ink in the amount column (first band per page is the header label):")

        var rowCursor = 0
        for p in 0..<doc.pageCount {
            let page = try XCTUnwrap(doc.page(at: p))
            let bands = try amountBands(page)
            XCTAssertGreaterThan(bands.count, 1, "page \(p + 1) has no body rows in the amount column")
            let dataBands = Array(bands.dropFirst())   // drop the repeated header label
            out.append(String(format: "    page %d: %d bands → %d data rows (rows R%03d…R%03d)",
                              p + 1, bands.count, dataBands.count,
                              rowCursor, rowCursor + dataBands.count - 1))

            for (i, band) in dataBands.enumerated() {
                let idx = rowCursor + i
                guard idx == rowCursor || idx == rowCursor + dataBands.count - 1 else { continue }
                guard idx < rows.count else {
                    XCTFail("found more rendered rows than the fixture has (\(idx + 1) > \(rows.count)) "
                            + "— the band detector is counting something that is not a row")
                    continue
                }
                let want = rows[idx].amount
                let ref = try referenceInk(want)
                let diff = differingPixels(band, ref)
                let where_ = (i == 0) ? "first" : "last "
                out.append(String(format: "      %@ row R%03d  \"%@\"  ink %dx%d vs %dx%d  diff %d",
                                  where_ as NSString, idx, want as NSString,
                                  band.width, band.height, ref.width, ref.height, diff))
                XCTAssertEqual(diff, 0,
                    "page \(p + 1), \(where_.trimmingCharacters(in: .whitespaces)) row "
                    + "R\(String(format: "%03d", idx)): the amount cell renders \(band.width)×\(band.height) "
                    + "of ink where the unconstrained render of \"\(want)\" is \(ref.width)×\(ref.height). "
                    + "A row at a page seam lost part of its amount.")
            }
            rowCursor += dataBands.count
        }

        XCTAssertEqual(rowCursor, rowCount,
            "found \(rowCursor) body rows across \(doc.pageCount) pages, but the fixture has "
            + "\(rowCount). Rows went missing at a page boundary.")

        out.append("")
        out.append(String(format: "  amount column: x=%.1f w=%.2f, right edge %.1f, font %.1fpt",
                          layout.amountX, layout.amountWidth,
                          layout.amountX + layout.amountWidth, layout.amountFont.pointSize))
        out.append(String(repeating: "═", count: 96))
        print(out.joined(separator: "\n"))
    }

    // MARK: - C2 — the branch that enforces "money may never truncate"

    /// The clamp is 170pt and the widest amount in the corpus is ~91pt, so
    /// `moneyNeed > maxAmountWidth` — the font-shrink branch — was never taken by
    /// any test. It carries the most important rule in the fix.
    ///
    /// REACHABILITY, established from the code rather than assumed:
    ///   • manual entry is capped: `amountCents <= 10_000_000_000_000`
    ///     (AddTransactionView.swift:502, EditTransactionView.swift:506)
    ///   • CSV import is NOT capped: CSVImportService.swift:710 takes whatever
    ///     `Money.parseCents` returns, so any Int-sized value is reachable.
    /// The first case below is therefore a reachable state through the UI; the
    /// second is reachable through import.
    func testMoneyNeverTruncatesAtTheWidestReachableAmounts() throws {
        var out: [String] = []
        out.append("")
        out.append("WIDEST REACHABLE AMOUNTS — does the money column still hold them whole?")
        out.append(String(repeating: "═", count: 96))

        for (cents, why) in [(10_000_000_000_000, "manual-entry cap (AddTransactionView:502)"),
                             (9_000_000_000_000_000, "CSV import — no cap (CSVImportService:710)")] {
            let m = try measure(Case("USD", cents, why))
            let shrank = m.amountFontSize < PDFExportService.bodyFont.pointSize
            let drop = PDFExportService.bodyFont.ascender
                - UIFont.systemFont(ofSize: m.amountFontSize, weight: .regular).ascender
            out.append("")
            out.append("  \(why)")
            out.append("    \"\(m.amount)\" = \(String(format: "%.2f", m.unconstrainedWidth))pt "
                       + "in a \(String(format: "%.2f", m.cell.width))pt column, font "
                       + "\(m.amountFontSize)pt \(shrank ? "← SHRANK" : "(no shrink needed)")")
            out.append("    baseline drop \(String(format: "%.2f", drop))pt, "
                       + "ink-diff \(m.inkDiff) px, raw diff \(m.rawDiff) px")

            XCTAssertEqual(m.inkDiff, 0,
                "MONEY TRUNCATED at \(cents) cents (\(why)): the cell renders \(m.inkSizeReal) of "
                + "ink where the unconstrained render is \(m.inkSizeReference). A truncated "
                + "monetary value is a wrong monetary value.")
            XCTAssertEqual(normalize(m.selectedInInflatedCell), normalize(m.amount),
                "the amount cell does not contain the whole amount at \(cents) cents")
            // The row pitch is 18pt and the cell is 16pt, so a baseline nudge over
            // 2pt would push a shrunken amount into the NEXT row's band.
            XCTAssertLessThanOrEqual(drop, 2.0,
                "the baseline nudge for the shrunken amount font is \(drop)pt, which is more than "
                + "the 2pt of slack between the 18pt row pitch and the 16pt cell — a shrunken "
                + "amount would encroach on the row below.")
        }

        // What the floor would have to face. Reported, not asserted — the point is
        // to put a NUMBER under the question of what happens below 7pt.
        let floorFont = UIFont.systemFont(ofSize: 7, weight: .regular)
        let hugest = Money.format(amount: Decimal(Int.max) / 100, currencyCode: "USD")
        let atFloor = (hugest as NSString).size(withAttributes: [.font: floorFont]).width
        let atBody = (hugest as NSString).size(withAttributes: [.font: PDFExportService.bodyFont]).width
        out.append("")
        out.append("  BELOW-THE-FLOOR HEADROOM (reported, not asserted):")
        out.append("    Int.max cents → \"\(hugest)\"")
        out.append("      at 12pt: \(String(format: "%.2f", atBody))pt   "
                   + "at the 7pt floor: \(String(format: "%.2f", atFloor))pt")
        out.append("    The whole table is 540pt wide, so at the floor this leaves "
                   + "\(String(format: "%.2f", 540 - atFloor))pt for the other three columns.")
        out.append(String(repeating: "═", count: 96))
        print(out.joined(separator: "\n"))
    }

    /// Replaces a proposed `PDFExportError.amountTooWideToRender` throw. That
    /// throw would have been unreachable BY TYPE, and an unreachable error case in
    /// a shipping API is a promise nobody can check — plus its one behaviour is
    /// bad: no report at all for the whole month because of one imported row.
    ///
    /// This is the test that makes the throw unnecessary. While it is green, the
    /// widest amount the store can hold still fits the table with a title column
    /// left over. If the money type changes or the table narrows it goes red, and
    /// the behaviour gets designed then, against a real case.
    ///
    /// THE REACHABLE CEILING, established in
    /// outputs/DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:
    ///   • the UI caps at 10^13 cents (AddTransactionView:502, EditTransactionView:506)
    ///   • CSV import caps nothing, and `AmountParsing.parseCents` ends in
    ///     `intValue * 100 + fracValue` — which TRAPS above Int.max, and at ≥20
    ///     integer digits returns `Int(intDigits) ?? 0`, i.e. silently ZERO.
    /// So the largest value that can actually land in the store is Int.max cents:
    /// here the type's maximum and the reachable maximum coincide, and both are
    /// reported below so the headroom is stated twice over.
    func testTheWidestStorableAmountStillFitsTheTable() {
        let typeMax = Int.max
        let reachableMax = Int.max      // see derivation above

        var out: [String] = []
        out.append("")
        out.append("WIDEST STORABLE AMOUNT vs THE TABLE (\(PDFExportService.tableLeft)…\(PDFExportService.tableRight))")
        out.append(String(repeating: "═", count: 96))
        out.append("  type maximum      : \(typeMax) cents")
        out.append("  reachable maximum : \(reachableMax) cents  (parseCents traps above this; "
                   + "≥20 digits silently yields 0)")

        let amount = Money.formatSigned(cents: reachableMax, isPositive: false, currencyCode: "USD")
        let row = PDFExportService.RowContent(
            date: "26.08.2026",
            title: String(repeating: "W", count: 200),   // a title fighting for the same space
            category: "Коммунальные услуги",             // the widest seeded category name
            amount: amount
        )
        let layout = PDFExportService.tableLayout(rows: [row], headers: .localized())
        let drawn = (amount as NSString).size(withAttributes: [.font: layout.amountFont]).width

        out.append("")
        out.append("  formatted         : \"\(amount)\"")
        out.append(String(format: "  at %.1fpt          : %.2fpt in a %.2fpt column",
                          layout.amountFont.pointSize, drawn, layout.amountWidth))
        out.append(String(format: "  columns           : date %.1f+%.2f  title %.1f+%.2f  category %.1f+%.2f  amount %.1f+%.2f",
                          layout.dateX, layout.dateWidth, layout.titleX, layout.titleWidth,
                          layout.categoryX, layout.categoryWidth, layout.amountX, layout.amountWidth))
        out.append(String(format: "  right edge        : %.1f", layout.amountX + layout.amountWidth))
        out.append(String(repeating: "═", count: 96))
        print(out.joined(separator: "\n"))

        XCTAssertLessThanOrEqual(drawn, layout.amountWidth,
            "MONEY WOULD TRUNCATE at the widest storable amount: \"\(amount)\" is \(drawn)pt at "
            + "\(layout.amountFont.pointSize)pt in a \(layout.amountWidth)pt column. This is the "
            + "case the rejected throw would have covered — design the behaviour now.")
        XCTAssertGreaterThan(layout.titleWidth, 0,
            "the amount column consumed the entire table; there is no title column left")
        XCTAssertLessThanOrEqual(layout.dateX + layout.dateWidth, layout.titleX,
            "date and title columns overlap")
        XCTAssertLessThanOrEqual(layout.titleX + layout.titleWidth, layout.categoryX,
            "title and category columns overlap")
        XCTAssertLessThanOrEqual(layout.categoryX + layout.categoryWidth, layout.amountX,
            "category and amount columns overlap — the amount would overdraw the category")
        XCTAssertEqual(layout.amountX + layout.amountWidth, PDFExportService.tableRight, accuracy: 0.01,
            "the table's right edge moved off \(PDFExportService.tableRight)")
    }

    // MARK: - C3 — the summary block, which stays fixed-geometry

    /// The summary's value column is a literal 366×18 rect at 14pt semibold. That
    /// is a scope decision, and a scope decision needs a NUMBER: this reports the
    /// largest total that renders in full, so "366 is probably enough" is replaced
    /// by a margin someone can check against the manual-entry cap.
    func testReportSummaryBlockMargin() {
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let columnWidth: CGFloat = 366
        func w(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
        func total(_ v: Decimal) -> String { Money.format(amount: v, currencyCode: "USD") }

        var out: [String] = []
        out.append("")
        out.append("SUMMARY BLOCK — value column \(columnWidth)pt, \(font.pointSize)pt semibold, "
                   + "locale \(Locale.current.identifier)")
        out.append(String(repeating: "─", count: 96))
        out.append("  The summary sums into a Decimal, NOT an Int — computeSummary() accumulates")
        out.append("  Decimal(amountCents)/100 — so the ceiling here is not Int.max cents.")
        out.append("")

        var lastFitting: (digits: Int, s: String, w: CGFloat)?
        var firstOverflow: (digits: Int, s: String, w: CGFloat)?
        var value = Decimal(1) / 100
        for digits in 1...34 {
            let s = total(value)
            let width = w(s)
            if width <= columnWidth {
                lastFitting = (digits, s, width)
            } else if firstOverflow == nil {
                firstOverflow = (digits, s, width)
            }
            out.append(String(format: "  10^%-2d cents → %-42@ %7.2fpt  %@",
                              digits - 3, s as NSString, width,
                              (width <= columnWidth ? "fits" : "OVERFLOWS") as NSString))
            value *= 10
        }

        out.append("")
        if let fit = lastFitting {
            out.append("  widest total that renders IN FULL : \"\(fit.s)\" "
                       + "(\(String(format: "%.2f", fit.w))pt of \(columnWidth)pt)")
        }
        if let over = firstOverflow {
            out.append("  first total that TRUNCATES        : \"\(over.s)\" "
                       + "(\(String(format: "%.2f", over.w))pt — ellipsised)")
        } else {
            out.append("  NO total overflows within 10^31 currency units.")
        }
        out.append("")
        out.append("  For scale: Int.max cents is 92 233 720 368 547 758.07 — one transaction can")
        out.append("  never exceed that, and the manual-entry cap is 10^13 cents "
                   + "(100 000 000 000.00).")
        let intMax = total(Decimal(Int.max) / 100)
        out.append("  Int.max cents renders \"\(intMax)\" = \(String(format: "%.2f", w(intMax)))pt "
                   + "→ \(w(intMax) <= columnWidth ? "FITS" : "OVERFLOWS")")
        out.append(String(repeating: "─", count: 96))
        print(out.joined(separator: "\n"))

        XCTAssertNotNil(lastFitting, "measured nothing — this reporter reported nothing")
    }

    // MARK: - Reporter

    func testReportRenderedAmountCells() throws {
        var out: [String] = []
        out.append("")
        out.append("REAL RENDERED PDF — amount cell read from PDFExportService.TableLayout, "
                   + "first body row y=\(Self.firstRowTopLeftY) (top-left space)")
        out.append("process locale: \(Locale.current.identifier)   "
                   + "autoupdating: \(Locale.autoupdatingCurrent.identifier)   "
                   + "languages: \(Locale.preferredLanguages.prefix(2).joined(separator: ","))")
        out.append(String(repeating: "═", count: 110))

        for c in Self.corpus {
            let m = try measure(c)
            out.append("")
            out.append("CASE \(c.currencyCode) \(c.cents)\(c.isControl ? "  ◂CTRL" : "")  — \(c.note)")
            out.append("  drawn string        : \"\(m.amount)\"  (\(String(format: "%.2f", m.unconstrainedWidth))pt "
                       + "in a \(String(format: "%.2f", m.cell.width))pt column at x=\(String(format: "%.1f", m.cell.minX)), "
                       + "font \(m.amountFontSize)pt)")
            out.append("  scalars             : \(m.scalars)")
            out.append("  READING 1 cell      : \"\(normalize(m.selectedInCell))\"")
            out.append("  READING 1 cell±1pt  : \"\(normalize(m.selectedInInflatedCell))\"")
            out.append("  READING 2 ink       : cell \(m.inkSizeReal) vs unconstrained \(m.inkSizeReference), "
                       + "ink-diff \(m.inkDiff) px, raw-window diff \(m.rawDiff) px")
            out.append("  what is VISIBLE in the cell (1px per pt, ink = darker chars):")
            out.append(contentsOf: m.art.map { "    " + $0 })
            out.append("  the cell PLUS 20pt below it (does a second line leak onto the page?):")
            out.append(contentsOf: m.artBelow.map { "    " + $0 })
        }

        // Constraint (g): the DATE column had never been measured. Nor had the
        // title/category allocation been looked at as a whole. Print the entire
        // allocation for one representative row so the margins are on the record.
        let sample = try renderRealPDF(Self.corpus[0])
        let l = sample.layout
        let rows = try XCTUnwrap(
            PDFExportService.rowContents(
                [Transaction(typeRaw: "expense", amountCents: 400_000, currency: "RUB",
                             date: Date(), category: nil, merchant: Self.rowMarker)],
                currencyCode: "RUB"
            ).first
        )
        let bf = PDFExportService.bodyFont
        func w(_ str: String) -> CGFloat { (str as NSString).size(withAttributes: [.font: bf]).width }
        out.append("")
        out.append("FULL COLUMN ALLOCATION for that one-row report (table 36…576):")
        out.append(String(format: "  date     x=%6.1f w=%6.2f   content \"%@\" = %.2fpt  → margin %.2fpt",
                          l.dateX, l.dateWidth, rows.date, w(rows.date), l.dateWidth - w(rows.date)))
        out.append(String(format: "  title    x=%6.1f w=%6.2f   content \"%@\" = %.2fpt  → margin %.2fpt",
                          l.titleX, l.titleWidth, rows.title, w(rows.title), l.titleWidth - w(rows.title)))
        out.append(String(format: "  category x=%6.1f w=%6.2f   content \"%@\" = %.2fpt  → margin %.2fpt",
                          l.categoryX, l.categoryWidth, rows.category, w(rows.category),
                          l.categoryWidth - w(rows.category)))
        out.append(String(format: "  amount   x=%6.1f w=%6.2f   content \"%@\" = %.2fpt  → margin %.2fpt",
                          l.amountX, l.amountWidth, rows.amount, w(rows.amount),
                          l.amountWidth - w(rows.amount)))
        out.append(String(format: "  right edge = %.1f (must be 576)", l.amountX + l.amountWidth))

        out.append(String(repeating: "═", count: 110))
        print(out.joined(separator: "\n"))
        XCTAssertFalse(Self.corpus.isEmpty, "empty corpus — this reporter reported nothing")
        XCTAssertEqual(l.amountX + l.amountWidth, PDFExportService.tableRight, accuracy: 0.01,
                       "the table's right edge moved off 576")
    }
}
