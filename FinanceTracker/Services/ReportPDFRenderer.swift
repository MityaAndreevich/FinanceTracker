//
//  ReportPDFRenderer.swift
//  FinanceTracker
//
//  The report PDF: the analysis on the first page, then (optionally) the
//  transaction table. Composes `PDFExportService`'s page, fonts, allocator,
//  table and footer — it carries no second copy of any of them, because the
//  1.0.5 clipping defect was exactly a second copy (`PDFExportService.swift`
//  "Table geometry").
//
//  Everything is Core Graphics / NSString drawing. No `ImageRenderer`, no
//  SwiftUI: this project has measured that route rendering blank inside a
//  ScrollView and dropping materials, and CG rects are what the ink-box pixel
//  idiom can verify (`ReportPDFRenderTests`).
//
//  MONEY NEVER TRUNCATES. Every amount column here is sized from the widest
//  string it will draw, and its font shrinks in 0.5pt steps down to
//  `PDFExportService.amountFontFloor` before the column is allowed to grow into
//  its neighbours — the same rule as the transaction table.
//

import Foundation
import UIKit

enum ReportPDFRenderer {

    private static var page: CGSize { PDFExportService.pageSize }
    private static var left: CGFloat { PDFExportService.leftMargin }
    private static var right: CGFloat { PDFExportService.pageSize.width - PDFExportService.rightMargin }
    private static var contentWidth: CGFloat { right - left }
    private static var top: CGFloat { PDFExportService.topMargin }
    private static var bottomLimit: CGFloat { PDFExportService.pageSize.height - PDFExportService.bottomMargin }
    private static let lineHeight: CGFloat = 18
    static let sectionGap: CGFloat = 14
    static let maxNamedCategories = ReportsView.maxNamedCategories

    static var labelFont: UIFont { UIFont.systemFont(ofSize: 13, weight: .regular) }
    static var valueFont: UIFont { UIFont.systemFont(ofSize: 13, weight: .semibold) }
    static var sectionFont: UIFont { UIFont.systemFont(ofSize: 11, weight: .semibold) }

    // MARK: - Geometry, internal so the render tests READ it rather than transcribe it

    /// The summary table: label | this period | previous | change.
    struct SummaryLayout {
        let labelX: CGFloat, labelWidth: CGFloat
        let columnWidth: CGFloat
        let font: UIFont
        func valueX(column: Int) -> CGFloat { labelX + labelWidth + CGFloat(column) * (columnWidth + gap) }
        var gap: CGFloat { 8 }
        func valueRect(column: Int, rowY: CGFloat) -> CGRect {
            CGRect(x: valueX(column: column), y: rowY, width: columnWidth, height: PDFExportService.rowCellHeight)
        }
    }

    /// The categories table: name | amount | share | bar.
    struct CategoryLayout {
        let nameX: CGFloat, nameWidth: CGFloat
        let amountX: CGFloat, amountWidth: CGFloat
        let shareX: CGFloat, shareWidth: CGFloat
        let barX: CGFloat, barWidth: CGFloat
        let amountFont: UIFont
        func amountRect(rowY: CGFloat) -> CGRect {
            let drop = max(0, PDFExportService.bodyFont.ascender - amountFont.ascender)
            return CGRect(x: amountX, y: rowY + drop, width: amountWidth, height: PDFExportService.rowCellHeight)
        }
    }

    /// The strings the first page draws, formatted ONCE — measured from and
    /// drawn from the same values (the PDFExportService rule).
    struct Page1Content {
        struct SummaryRow { let label: String; let current: String; let previous: String?; let change: String? }
        struct CategoryRow { let name: String; let amount: String; let share: String; let fraction: Double }
        let title: String
        let periodLabel: String
        let generated: String
        let summary: [SummaryRow]
        let summaryHeaders: (current: String, previous: String, change: String)
        let budgetTitle: String
        let budgetLine: String?
        let overLimit: String?
        let categoriesTitle: String
        let categories: [CategoryRow]
        let emptyCategories: String?
        let unavailable: (title: String, body: String)?
        let transactionsOmitted: String?
    }

    static func fittedFont(for strings: [String], width: CGFloat, base: UIFont, floor: CGFloat = PDFExportService.amountFontFloor) -> UIFont {
        var size = base.pointSize
        while size > floor {
            let font = UIFont.systemFont(ofSize: size, weight: base.fontDescriptor.symbolicTraits.contains(.traitBold) ? .semibold : .regular)
            let widest = strings.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            if widest <= width { return font }
            size -= 0.5
        }
        return UIFont.systemFont(ofSize: floor, weight: .regular)
    }

    static func summaryLayout(rows: [Page1Content.SummaryRow]) -> SummaryLayout {
        let labelWidth: CGFloat = 120
        let gap: CGFloat = 8
        let columnWidth = (contentWidth - labelWidth - 2 * gap) / 3
        let strings = rows.flatMap { [$0.current, $0.previous ?? "", $0.change ?? ""] }
        let font = fittedFont(for: strings, width: columnWidth - 4, base: valueFont)
        return SummaryLayout(labelX: left, labelWidth: labelWidth, columnWidth: columnWidth, font: font)
    }

    static func categoryLayout(rows: [Page1Content.CategoryRow]) -> CategoryLayout {
        let amountStrings = rows.map(\.amount)
        let amountWidth: CGFloat = 130
        let shareWidth: CGFloat = 44
        let barWidth: CGFloat = 120
        let gap: CGFloat = 8
        let nameWidth = contentWidth - amountWidth - shareWidth - barWidth - 3 * gap
        let font = fittedFont(for: amountStrings, width: amountWidth - 4, base: PDFExportService.bodyFont)
        return CategoryLayout(
            nameX: left, nameWidth: nameWidth,
            amountX: left + nameWidth + gap, amountWidth: amountWidth,
            shareX: left + nameWidth + gap + amountWidth + gap, shareWidth: shareWidth,
            barX: right - barWidth, barWidth: barWidth,
            amountFont: font
        )
    }

    // MARK: - Content

    static func page1Content(
        snapshot: ReportSnapshot?, period: ReportPeriod, transactionCount: Int,
        currencyCode: String, includeTransactions: Bool, bundle: Bundle, locale: Locale, calendar: Calendar, now: Date
    ) -> Page1Content {
        func L(_ key: String) -> String { String(localized: String.LocalizationValue(key), bundle: bundle) }
        let df = DateFormatter(); df.locale = locale; df.dateStyle = .medium; df.timeStyle = .short
        let generated = String(format: L("pdf.report.generated.format"), df.string(from: now))
        let title = L("pdf.report.title")
        let periodLabel = period.label(locale: locale, calendar: calendar)

        guard let s = snapshot else {
            return Page1Content(
                title: title, periodLabel: periodLabel, generated: generated, summary: [],
                summaryHeaders: (L("pdf.report.this_period"), L("pdf.report.previous"), L("pdf.report.change")),
                budgetTitle: L("pdf.report.budget"), budgetLine: nil, overLimit: nil,
                categoriesTitle: L("pdf.report.categories"), categories: [], emptyCategories: nil,
                unavailable: (L("totals_unavailable.title"), L("totals_unavailable.body")),
                transactionsOmitted: includeTransactions ? nil : String(format: L("pdf.report.transactions_omitted.format"), transactionCount)
            )
        }

        func money(_ cents: Int, signed: Bool = false, positive: Bool = true) -> String {
            signed ? Money.formatSigned(cents: abs(cents), isPositive: positive, currencyCode: currencyCode)
                   : Money.format(cents: cents, currencyCode: currencyCode)
        }
        func change(_ d: ReportSnapshot.Delta?) -> String? {
            guard let d else { return nil }
            if d.cents == 0 { return L("reports.compare.unchanged") }
            let cents = Money.formatSigned(cents: abs(d.cents), isPositive: d.cents > 0, currencyCode: currencyCode)
            if let pct = d.percent { return cents + String(format: " (%@%.0f%%)", d.cents > 0 ? "+" : "−", abs(pct)) }
            return cents
        }
        let c = s.comparison
        let summary: [Page1Content.SummaryRow] = [
            .init(label: L("pdf.label.income"), current: money(s.totals.incomeCents),
                  previous: c.map { money($0.previous.incomeCents) }, change: change(c?.income)),
            .init(label: L("pdf.label.expenses"), current: money(s.totals.expenseCents),
                  previous: c.map { money($0.previous.expenseCents) }, change: change(c?.expense)),
            .init(label: L("pdf.label.net"), current: money(s.totals.netCents, signed: true, positive: s.totals.netCents >= 0),
                  previous: c.map { money($0.previous.netCents, signed: true, positive: $0.previous.netCents >= 0) }, change: change(c?.net)),
        ]

        var budgetLine: String?
        var overLimit: String?
        if let b = s.budget {
            budgetLine = String(format: L("reports.budget.line.format"), money(b.budgetCents), money(b.spentCents),
                                Money.formatSigned(cents: abs(b.remainingCents), isPositive: b.remainingCents >= 0, currencyCode: currencyCode))
            if b.overLimitCount == 1 { overLimit = L("reports.budget.over_limit.one") }
            else if b.overLimitCount > 1 { overLimit = String(format: L("reports.budget.over_limit.other.format"), b.overLimitCount) }
        }

        var categories: [Page1Content.CategoryRow] = []
        let sorted = s.expenseCategories
        let fold = CategoryBreakdown.fold(sorted, maxNamed: maxNamedCategories, cents: \.cents)
        let named = fold?.named ?? sorted
        for cat in named {
            let name = cat.label.name.isEmpty ? L("category.uncategorized") : cat.label.name
            categories.append(.init(name: name, amount: money(cat.cents), share: String(format: "%.0f%%", cat.share * 100), fraction: cat.share))
        }
        if let fold, fold.otherCents > 0 {
            let share = s.totals.expenseCents > 0 ? Double(fold.otherCents) / Double(s.totals.expenseCents) : 0
            categories.append(.init(name: L("analytics.breakdown.other"), amount: money(fold.otherCents),
                                    share: String(format: "%.0f%%", share * 100), fraction: share))
        }

        return Page1Content(
            title: title, periodLabel: periodLabel, generated: generated, summary: summary,
            summaryHeaders: (L("pdf.report.this_period"), L("pdf.report.previous"), L("pdf.report.change")),
            budgetTitle: L("pdf.report.budget"), budgetLine: budgetLine, overLimit: overLimit,
            categoriesTitle: L("pdf.report.categories"), categories: categories,
            emptyCategories: categories.isEmpty ? L("reports.empty.no_expenses") : nil,
            unavailable: nil,
            transactionsOmitted: includeTransactions ? nil : String(format: L("pdf.report.transactions_omitted.format"), transactionCount)
        )
    }

    // MARK: - Render

    /// Where page 1 actually drew its money — recorded during the render so
    /// `ReportPDFRenderTests` reads the geometry instead of transcribing it.
    /// Rows are top-left UIKit coordinates on page 1.
    struct Page1Geometry {
        var summaryRowYs: [CGFloat] = []
        var categoryRowYs: [CGFloat] = []
        var summaryLayout: SummaryLayout?
        var categoryLayout: CategoryLayout?
        var pages = 0
    }

    static func makeReportPDF(
        snapshot: ReportSnapshot?,
        period: ReportPeriod,
        transactions: [Transaction],
        currencyCode: String,
        includeTransactions: Bool,
        bundle: Bundle,
        locale: Locale = .current,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> PDFExportResult {
        makeReportPDFWithGeometry(snapshot: snapshot, period: period, transactions: transactions,
                                  currencyCode: currencyCode, includeTransactions: includeTransactions,
                                  bundle: bundle, locale: locale, calendar: calendar, now: now).result
    }

    static func makeReportPDFWithGeometry(
        snapshot: ReportSnapshot?,
        period: ReportPeriod,
        transactions: [Transaction],
        currencyCode: String,
        includeTransactions: Bool,
        bundle: Bundle,
        locale: Locale = .current,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> (result: PDFExportResult, content: Page1Content, geometry: Page1Geometry) {
        let content = page1Content(snapshot: snapshot, period: period, transactionCount: transactions.count,
                                   currencyCode: currencyCode, includeTransactions: includeTransactions,
                                   bundle: bundle, locale: locale, calendar: calendar, now: now)
        let rows = includeTransactions ? PDFExportService.rowContents(transactions, currencyCode: currencyCode) : []
        let headers = PDFExportService.HeaderLabels.localized()
        let tableLayout = PDFExportService.tableLayout(rows: rows, headers: headers)

        // Two passes: the first only counts pages so the footer can say "of N".
        let totalPages = render(content: content, rows: rows, headers: headers, tableLayout: tableLayout, totalPages: nil).geometry.pages
        let final = render(content: content, rows: rows, headers: headers, tableLayout: tableLayout, totalPages: totalPages)
        let filename = "BudgetCrab_Report_\(period.identity(calendar: calendar).replacingOccurrences(of: ":", with: "_")).pdf"
        return (PDFExportResult(data: final.data, filename: filename), content, final.geometry)
    }

    private static func render(
        content: Page1Content, rows: [PDFExportService.RowContent], headers: PDFExportService.HeaderLabels,
        tableLayout: PDFExportService.TableLayout, totalPages: Int?
    ) -> (data: Data, geometry: Page1Geometry) {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        var geometry = Page1Geometry()
        var pages: Int { get { geometry.pages } set { geometry.pages = newValue } }
        let data = renderer.pdfData { ctx in
            ctx.beginPage(); pages = 1
            var y = top
            y = PDFExportService.drawTitle(content.title, y: y)
            y = PDFExportService.drawSubTitle(content.periodLabel, y: y)
            y = PDFExportService.drawSubTitle(content.generated, y: y)
            y += sectionGap

            if let unavailable = content.unavailable {
                y = drawParagraph(unavailable.title, font: valueFont, y: y)
                y = drawParagraph(unavailable.body, font: labelFont, color: .secondaryLabel, y: y)
                y += sectionGap
            } else {
                y = drawSummary(content, y: y, geometry: &geometry)
                y += sectionGap
                if let budget = content.budgetLine {
                    y = drawSection(content.budgetTitle, y: y)
                    y = drawParagraph(budget, font: labelFont, y: y)
                    if let over = content.overLimit { y = drawParagraph(over, font: labelFont, color: .secondaryLabel, y: y) }
                    y += sectionGap
                }
                y = drawSection(content.categoriesTitle, y: y)
                if let empty = content.emptyCategories {
                    y = drawParagraph(empty, font: labelFont, color: .secondaryLabel, y: y)
                } else {
                    y = drawCategories(content.categories, y: y, geometry: &geometry)
                }
                y += sectionGap
            }

            if let omitted = content.transactionsOmitted {
                y = drawParagraph(omitted, font: labelFont, color: .secondaryLabel, y: y)
            } else if !rows.isEmpty {
                if y + 24 + PDFExportService.rowHeight > bottomLimit {
                    PDFExportService.drawPageFooter(pageIndex: pages, totalPages: totalPages ?? pages)
                    ctx.beginPage(); pages += 1; y = top
                }
                y = PDFExportService.drawTableHeader(headers, layout: tableLayout, y: y)
                for row in rows {
                    if y + PDFExportService.rowHeight > bottomLimit {
                        PDFExportService.drawPageFooter(pageIndex: pages, totalPages: totalPages ?? pages)
                        ctx.beginPage(); pages += 1; y = top
                        y = PDFExportService.drawTableHeader(headers, layout: tableLayout, y: y)
                    }
                    y = PDFExportService.drawTransactionRow(row, layout: tableLayout, y: y)
                }
            }
            PDFExportService.drawPageFooter(pageIndex: pages, totalPages: totalPages ?? pages)
        }
        return (data, geometry)
    }

    private static func drawSection(_ text: String, y: CGFloat) -> CGFloat {
        text.uppercased().draw(
            in: CGRect(x: left, y: y, width: contentWidth, height: 14),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.secondaryLabel,
                             .paragraphStyle: PDFExportService.truncatingStyle(.natural)]
        )
        return y + 16
    }

    private static func drawParagraph(_ text: String, font: UIFont, color: UIColor = .label, y: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: 400), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil
        )
        text.draw(in: CGRect(x: left, y: y, width: contentWidth, height: ceil(bounds.height) + 2), withAttributes: attrs)
        return y + ceil(bounds.height) + 4
    }

    static func drawSummary(_ content: Page1Content, y startY: CGFloat, geometry: inout Page1Geometry) -> CGFloat {
        let layout = summaryLayout(rows: content.summary)
        geometry.summaryLayout = layout
        var y = startY
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.secondaryLabel,
                                                          .paragraphStyle: PDFExportService.truncatingStyle(.right)]
        content.summaryHeaders.current.uppercased().draw(in: layout.valueRect(column: 0, rowY: y), withAttributes: headerAttrs)
        content.summaryHeaders.previous.uppercased().draw(in: layout.valueRect(column: 1, rowY: y), withAttributes: headerAttrs)
        content.summaryHeaders.change.uppercased().draw(in: layout.valueRect(column: 2, rowY: y), withAttributes: headerAttrs)
        y += lineHeight
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor.secondaryLabel,
                                                         .paragraphStyle: PDFExportService.truncatingStyle(.natural)]
        // Values: right-aligned, in the fitted font; wrap disabled — the fit
        // guarantees a single line, and the ink test proves nothing was lost.
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: layout.font, .paragraphStyle: PDFExportService.truncatingStyle(.right)]
        for row in content.summary {
            geometry.summaryRowYs.append(y)
            row.label.draw(in: CGRect(x: layout.labelX, y: y, width: layout.labelWidth, height: PDFExportService.rowCellHeight), withAttributes: labelAttrs)
            row.current.draw(in: layout.valueRect(column: 0, rowY: y), withAttributes: valueAttrs)
            if let p = row.previous { p.draw(in: layout.valueRect(column: 1, rowY: y), withAttributes: valueAttrs) }
            if let c = row.change { c.draw(in: layout.valueRect(column: 2, rowY: y), withAttributes: valueAttrs) }
            y += lineHeight
        }
        return y
    }

    static func drawCategories(_ rows: [Page1Content.CategoryRow], y startY: CGFloat, geometry: inout Page1Geometry) -> CGFloat {
        let layout = categoryLayout(rows: rows)
        geometry.categoryLayout = layout
        var y = startY
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: PDFExportService.bodyFont, .paragraphStyle: PDFExportService.truncatingStyle(.natural)]
        let amountAttrs: [NSAttributedString.Key: Any] = [.font: layout.amountFont, .paragraphStyle: PDFExportService.truncatingStyle(.right)]
        let shareAttrs: [NSAttributedString.Key: Any] = [.font: PDFExportService.bodyFont, .foregroundColor: UIColor.secondaryLabel,
                                                         .paragraphStyle: PDFExportService.truncatingStyle(.right)]
        for row in rows {
            geometry.categoryRowYs.append(y)
            row.name.draw(in: CGRect(x: layout.nameX, y: y, width: layout.nameWidth, height: PDFExportService.rowCellHeight), withAttributes: nameAttrs)
            row.amount.draw(in: layout.amountRect(rowY: y), withAttributes: amountAttrs)
            row.share.draw(in: CGRect(x: layout.shareX, y: y, width: layout.shareWidth, height: PDFExportService.rowCellHeight), withAttributes: shareAttrs)
            // The bar: a track and a fill proportional to the share. Pure CG.
            let trackRect = CGRect(x: layout.barX, y: y + 5, width: layout.barWidth, height: 6)
            UIColor.separator.withAlphaComponent(0.5).setFill()
            UIBezierPath(roundedRect: trackRect, cornerRadius: 3).fill()
            let fillWidth = max(0, min(1, row.fraction)) * layout.barWidth
            if fillWidth > 0 {
                UIColor.darkGray.setFill()
                UIBezierPath(roundedRect: CGRect(x: layout.barX, y: y + 5, width: fillWidth, height: 6), cornerRadius: 3).fill()
            }
            y += PDFExportService.rowHeight
        }
        return y
    }
}
