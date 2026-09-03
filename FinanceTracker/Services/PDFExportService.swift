//
//  PDFExportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//
//  EVERY code-resolved string here passes an EXPLICIT `bundle:`. That is not
//  style — `String(localized:)`'s `#bundle` default does not honor the in-app
//  language override (LocalizedBundlePremiseTests), and a PDF is the longest-lived
//  artifact this app produces: the user keeps it, or forwards it to someone else.
//  A report exported right after switching to Russian would have Russian rows
//  (those go through NSLocalizedString) and English chrome. Pinned by
//  FrozenArtifactLanguageTests.
//
//  ── EVERY .draw(in:) HERE CARRIES AN EXPLICIT PARAGRAPH STYLE ────────────────
//  `String.draw(in:withAttributes:)` with no paragraph style word-wraps and then
//  clips to the rect, and the clipped remainder is drawn NOWHERE — no ellipsis,
//  no cue. A TestFlight user reported a 4000,00 ₽ expense printing as "−4"; that
//  is this API, and it was reproduced byte-for-byte out of a real PDF by
//  PDFExportRenderTests.
//
//  Worse, the legacy drawing path breaks lines where CoreText says it cannot:
//  the ru_RU grouping separator is U+00A0 NO-BREAK SPACE, `CTTypesetterSuggest`
//  `LineBreak` reports no break opportunity there, and `draw(in:)` broke there
//  anyway for "−4 000,00 ₽" — leaving "−4".
//
//  And it is not even consistent about that. Measured in the same suite, at the
//  same 56pt: "−12 345,67 ₽" and "−RUB 89.90" both contain the same NBSP and both
//  char-wrapped mid-number instead ("−12 345," and "−RUB 89"). We have not found
//  the rule, and no rule inferred from six samples should be trusted. The only
//  reliable answer to "what does this cell show" is a rendered PDF, read back —
//  which is what PDFExportRenderTests does, and why it is the acceptance guard.
//
//  `.byTruncatingTail` on every site makes silent loss structurally impossible:
//  overflow becomes an ellipsis the user can see. It is a floor, not the fix.
//  The columns are also sized from the content actually being exported, and the
//  money column is sized so that it never needs the ellipsis at all — a
//  truncated monetary value is a WRONG monetary value.
//

import Foundation
import SwiftData
import UIKit

struct PDFExportResult {
    let data: Data
    let filename: String
}

enum PDFExportService {

    /// US Letter page in points.
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let leftMargin: CGFloat = 36
    private static let rightMargin: CGFloat = 36
    private static let topMargin: CGFloat = 36
    private static let bottomMargin: CGFloat = 48
    private static let rowHeight: CGFloat = 18

    // MARK: - Table geometry
    //
    // ONE source, used by the header row AND the body rows. They used to be two
    // independent sets of literals — that is how the header's 366pt summary rect
    // stayed correct while the body's 56pt amount rect silently ate every amount
    // over 1000. Nothing below may hard-code a column x or width.
    //
    // `internal`, not `private`, for exactly one reason: PDFExportRenderTests
    // must READ this geometry instead of transcribing it. A test that copies the
    // literals is a second source, and a second source is the defect.

    static let tableLeft: CGFloat = 36
    static let tableRight: CGFloat = 576
    /// Height of every column rect in the table. One line of 12pt text.
    static let rowCellHeight: CGFloat = 16

    private static let columnGap: CGFloat = 6
    private static let cellPadding: CGFloat = 4

    private static let minTitleWidth: CGFloat = 80
    private static let maxDateWidth: CGFloat = 110
    private static let minDateWidth: CGFloat = 44
    private static let maxCategoryWidth: CGFloat = 150
    private static let minCategoryWidth: CGFloat = 52
    private static let maxAmountWidth: CGFloat = 170
    /// The amount font shrinks rather than the amount truncating. This is where
    /// shrinking stops; below it, the column is allowed to exceed its clamp and
    /// take the space from the title instead. Money never truncates.
    private static let amountFontFloor: CGFloat = 7

    static var headerFont: UIFont { UIFont.systemFont(ofSize: 12, weight: .semibold) }
    static var bodyFont: UIFont { UIFont.systemFont(ofSize: 12, weight: .regular) }

    /// The four strings of one table row, formatted ONCE. The layout is measured
    /// from these and the row is drawn from these, so what was measured is
    /// necessarily what is drawn.
    struct RowContent {
        let date: String
        let title: String
        let category: String
        let amount: String
    }

    struct HeaderLabels {
        let date: String
        let title: String
        let category: String
        let amount: String

        static func localized() -> HeaderLabels {
            let bundle = LocalizedBundle.shared.bundle
            return HeaderLabels(
                date: String(localized: "pdf.header.date", bundle: bundle),
                title: String(localized: "pdf.header.title", bundle: bundle),
                category: String(localized: "pdf.header.category", bundle: bundle),
                amount: String(localized: "pdf.header.amount", bundle: bundle)
            )
        }
    }

    struct TableLayout {
        let dateX: CGFloat
        let dateWidth: CGFloat
        let titleX: CGFloat
        let titleWidth: CGFloat
        let categoryX: CGFloat
        let categoryWidth: CGFloat
        let amountX: CGFloat
        let amountWidth: CGFloat
        /// Shrunk only if the widest amount could not fit the clamp at body size.
        let amountFont: UIFont

        func dateRect(rowY: CGFloat) -> CGRect {
            CGRect(x: dateX, y: rowY, width: dateWidth, height: rowCellHeight)
        }
        func titleRect(rowY: CGFloat) -> CGRect {
            CGRect(x: titleX, y: rowY, width: titleWidth, height: rowCellHeight)
        }
        func categoryRect(rowY: CGFloat) -> CGRect {
            CGRect(x: categoryX, y: rowY, width: categoryWidth, height: rowCellHeight)
        }
        /// Nudged down by the ascender difference so a shrunken amount still sits
        /// on the row's baseline instead of floating above it.
        func amountRect(rowY: CGFloat) -> CGRect {
            let drop = max(0, PDFExportService.bodyFont.ascender - amountFont.ascender)
            return CGRect(x: amountX, y: rowY + drop, width: amountWidth, height: rowCellHeight)
        }
        func headerAmountRect(rowY: CGFloat) -> CGRect {
            CGRect(x: amountX, y: rowY, width: amountWidth, height: rowCellHeight)
        }
    }

    private static func textWidth(_ s: String, font: UIFont) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: font]).width
    }

    /// Content-derived column allocation, computed ONCE per export.
    ///
    /// Priority when 540pt is not enough for everything:
    ///   1. the money column gets what it needs (font shrinks before it truncates),
    ///   2. the title column keeps a floor,
    ///   3. category, then date, give up width — visibly, with an ellipsis.
    static func tableLayout(rows: [RowContent], headers: HeaderLabels) -> TableLayout {
        let total = tableRight - tableLeft
        let hf = headerFont
        let bf = bodyFont

        var dateNeed = textWidth(headers.date, font: hf)
        var categoryNeed = textWidth(headers.category, font: hf)
        for row in rows {
            dateNeed = max(dateNeed, textWidth(row.date, font: bf))
            categoryNeed = max(categoryNeed, textWidth(row.category, font: bf))
        }
        dateNeed += cellPadding
        categoryNeed += cellPadding

        func widestAmount(_ font: UIFont) -> CGFloat {
            rows.reduce(0) { max($0, textWidth($1.amount, font: font)) }
        }

        var amountFont = bf
        var moneyNeed = widestAmount(bf) + cellPadding
        if moneyNeed > maxAmountWidth {
            var size = bf.pointSize - 0.5
            while size >= amountFontFloor {
                let candidate = UIFont.systemFont(ofSize: size, weight: .regular)
                amountFont = candidate
                moneyNeed = widestAmount(candidate) + cellPadding
                if moneyNeed <= maxAmountWidth { break }
                size -= 0.5
            }
        }

        // The header LABEL may truncate — it is a label. The VALUE may not.
        let headerAmountNeed = min(textWidth(headers.amount, font: hf) + cellPadding, maxAmountWidth)
        let amountWidth = max(moneyNeed, headerAmountNeed)

        var dateWidth = min(dateNeed, maxDateWidth)
        var categoryWidth = min(categoryNeed, maxCategoryWidth)
        var titleWidth = total - 3 * columnGap - dateWidth - categoryWidth - amountWidth

        if titleWidth < minTitleWidth {
            let deficit = minTitleWidth - titleWidth
            let fromCategory = min(deficit, max(0, categoryWidth - minCategoryWidth))
            categoryWidth -= fromCategory
            let stillShort = deficit - fromCategory
            if stillShort > 0 {
                dateWidth -= min(stillShort, max(0, dateWidth - minDateWidth))
            }
            titleWidth = total - 3 * columnGap - dateWidth - categoryWidth - amountWidth
        }
        titleWidth = max(0, titleWidth)

        let dateX = tableLeft
        let titleX = dateX + dateWidth + columnGap
        let categoryX = titleX + titleWidth + columnGap
        let amountX = tableRight - amountWidth

        return TableLayout(
            dateX: dateX, dateWidth: dateWidth,
            titleX: titleX, titleWidth: titleWidth,
            categoryX: categoryX, categoryWidth: categoryWidth,
            amountX: amountX, amountWidth: amountWidth,
            amountFont: amountFont
        )
    }

    // MARK: - Paragraph styles
    //
    // Fresh instances rather than shared statics: NSParagraphStyle is a mutable
    // reference type and sharing one across a drawing pass is the sort of thing
    // Swift 6 concurrency checking is right to dislike.

    private static func truncatingStyle(_ alignment: NSTextAlignment) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.alignment = alignment
        return style
    }

    /// `currencyCode` should be the user's `defaultCurrencyCode` — passed in by
    /// the caller so PDF rendering does not assume per-transaction currency.
    static func makeMonthlyReportPDF(
        modelContext: ModelContext,
        scope: CSVExportScope,
        currencyCode: String
    ) throws -> PDFExportResult {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)
        let summary = computeSummary(txs)

        // Format every row once, then measure the columns from those exact
        // strings, then draw those exact strings. Measuring one string and
        // drawing another is how a column ends up too narrow for its content.
        let rows = rowContents(txs, currencyCode: currencyCode)
        let headers = HeaderLabels.localized()
        let layout = tableLayout(rows: rows, headers: headers)

        // Compute page layout first so we know how many pages we have.
        let pageBounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        // Phase 1: pre-flight pagination — count pages so we can show "Page X of Y".
        let totalPages = countPages(txs: txs)

        let data = renderer.pdfData { ctx in
            var pageIndex = 1
            ctx.beginPage()
            var y: CGFloat = topMargin

            // Title block (only on first page)
            y = drawTitle(String(localized: "pdf.report.title", bundle: LocalizedBundle.shared.bundle), y: y)
            let rangeText = (scope == .month)
                ? String(localized: "pdf.range.month", bundle: LocalizedBundle.shared.bundle)
                : String(localized: "pdf.range.all", bundle: LocalizedBundle.shared.bundle)
            y = drawSubTitle(rangeText, y: y)

            y += 12
            y = drawSummary(summary, currencyCode: currencyCode, y: y)
            y += 16

            y = drawTableHeader(headers, layout: layout, y: y)

            for row in rows {
                if y + rowHeight > pageSize.height - bottomMargin {
                    drawPageFooter(pageIndex: pageIndex, totalPages: totalPages)
                    ctx.beginPage()
                    pageIndex += 1
                    y = topMargin
                    y = drawTableHeader(headers, layout: layout, y: y)
                }
                y = drawTransactionRow(row, layout: layout, y: y)
            }

            drawPageFooter(pageIndex: pageIndex, totalPages: totalPages)
        }

        let filename = (scope == .month)
            ? "BudgetCrab_Report_ThisMonth.pdf"
            : "BudgetCrab_Report_All.pdf"

        return PDFExportResult(data: data, filename: filename)
    }

    /// Formats the rows once. `internal` so PDFExportRenderTests can measure the
    /// SAME strings the export draws, rather than re-deriving them and hoping.
    static func rowContents(_ txs: [Transaction], currencyCode: String) -> [RowContent] {
        txs.map { tx in
            let categoryName = tx.category.displayNameOrFallback()
            let merchant = tx.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
            return RowContent(
                date: shortDate(tx.date),
                title: (merchant?.isEmpty == false) ? tx.merchant! : categoryName,
                category: categoryName,
                amount: Money.formatSigned(
                    cents: tx.amountCents,
                    isPositive: tx.isIncome,
                    currencyCode: currencyCode
                )
            )
        }
    }

    // MARK: - Data

    private static func fetchTransactions(modelContext: ModelContext, scope: CSVExportScope) throws -> [Transaction] {
        let all = try modelContext.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )

        guard scope == .month else { return all }

        let cal = Calendar.current
        let now = Date()
        return all.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    private static func computeSummary(_ txs: [Transaction]) -> (income: Decimal, expense: Decimal, net: Decimal) {
        var income: Decimal = 0
        var expense: Decimal = 0

        for tx in txs {
            let amount = Decimal(tx.amountCents) / 100
            if tx.isIncome { income += amount }
            else { expense += amount }
        }

        let net = income - expense
        return (income, expense, net)
    }

    // MARK: - Pagination math

    /// Best-effort page count: assumes the title/summary block takes ~140pt on page 1.
    private static func countPages(txs: [Transaction]) -> Int {
        let firstPageAvailable = pageSize.height - bottomMargin - 140 - rowHeight // header
        let otherPageAvailable = pageSize.height - topMargin - bottomMargin - rowHeight

        let firstPageRows = max(0, Int(firstPageAvailable / rowHeight))
        if txs.count <= firstPageRows { return 1 }

        let remaining = txs.count - firstPageRows
        let otherPageRows = max(1, Int(otherPageAvailable / rowHeight))
        return 1 + Int(ceil(Double(remaining) / Double(otherPageRows)))
    }

    // MARK: - Drawing helpers

    private static func drawTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 22, weight: .bold)
        text.draw(
            in: CGRect(x: leftMargin, y: y, width: pageSize.width - leftMargin - rightMargin, height: 28),
            withAttributes: [.font: font, .paragraphStyle: truncatingStyle(.natural)]
        )
        return y + 30
    }

    private static func drawSubTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: truncatingStyle(.natural)
        ]
        text.draw(
            in: CGRect(x: leftMargin, y: y, width: pageSize.width - leftMargin - rightMargin, height: 18),
            withAttributes: attrs
        )
        return y + 18
    }

    private static func drawSummary(
        _ s: (income: Decimal, expense: Decimal, net: Decimal),
        currencyCode: String,
        y: CGFloat
    ) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let small = UIFont.systemFont(ofSize: 13, weight: .regular)

        func line(_ label: String, _ value: String, y: CGFloat) -> CGFloat {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: small,
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: truncatingStyle(.natural)
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: truncatingStyle(.natural)
            ]
            label.draw(in: CGRect(x: leftMargin, y: y, width: 160, height: 18), withAttributes: labelAttrs)
            value.draw(in: CGRect(x: leftMargin + 174, y: y, width: 366, height: 18), withAttributes: valueAttrs)
            return y + 18
        }

        var yy = y
        yy = line(String(localized: "pdf.label.income", bundle: LocalizedBundle.shared.bundle),
                  Money.format(amount: s.income, currencyCode: currencyCode),
                  y: yy)
        yy = line(String(localized: "pdf.label.expenses", bundle: LocalizedBundle.shared.bundle),
                  Money.format(amount: s.expense, currencyCode: currencyCode),
                  y: yy)
        yy = line(String(localized: "pdf.label.net", bundle: LocalizedBundle.shared.bundle),
                  Money.format(amount: s.net, currencyCode: currencyCode),
                  y: yy)
        return yy
    }

    private static func drawTableHeader(_ headers: HeaderLabels, layout: TableLayout, y: CGFloat) -> CGFloat {
        let font = headerFont
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: truncatingStyle(.natural)
        ]
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: truncatingStyle(.right)
        ]

        headers.date.draw(in: layout.dateRect(rowY: y), withAttributes: attrs)
        headers.title.draw(in: layout.titleRect(rowY: y), withAttributes: attrs)
        headers.category.draw(in: layout.categoryRect(rowY: y), withAttributes: attrs)
        headers.amount.draw(in: layout.headerAmountRect(rowY: y), withAttributes: amountAttrs)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: tableLeft, y: y + 18))
        path.addLine(to: CGPoint(x: tableRight, y: y + 18))
        UIColor.separator.setStroke()
        path.lineWidth = 1
        path.stroke()

        return y + 24
    }

    private static func drawTransactionRow(
        _ row: RowContent,
        layout: TableLayout,
        y: CGFloat
    ) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .paragraphStyle: truncatingStyle(.natural)
        ]
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: layout.amountFont,
            .paragraphStyle: truncatingStyle(.right)
        ]

        row.date.draw(in: layout.dateRect(rowY: y), withAttributes: attrs)
        row.title.draw(in: layout.titleRect(rowY: y), withAttributes: attrs)
        row.category.draw(in: layout.categoryRect(rowY: y), withAttributes: attrs)
        row.amount.draw(in: layout.amountRect(rowY: y), withAttributes: amountAttrs)

        return y + rowHeight
    }

    private static func drawPageFooter(pageIndex: Int, totalPages: Int) {
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.tertiaryLabel,
            .paragraphStyle: truncatingStyle(.natural)
        ]
        let text = String(
            format: NSLocalizedString("pdf.footer.page.format", comment: ""),
            pageIndex, totalPages
        )
        let footerY = pageSize.height - bottomMargin + 12
        text.draw(
            in: CGRect(x: leftMargin, y: footerY, width: pageSize.width - leftMargin - rightMargin, height: 14),
            withAttributes: attrs
        )
    }

    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: date)
    }
}
