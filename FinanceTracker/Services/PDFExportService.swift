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

    /// `currencyCode` should be the user's `defaultCurrencyCode` — passed in by
    /// the caller so PDF rendering does not assume per-transaction currency.
    static func makeMonthlyReportPDF(
        modelContext: ModelContext,
        scope: CSVExportScope,
        currencyCode: String
    ) throws -> PDFExportResult {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)
        let summary = computeSummary(txs)

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

            y = drawTableHeader(y: y)

            for tx in txs {
                if y + rowHeight > pageSize.height - bottomMargin {
                    drawPageFooter(pageIndex: pageIndex, totalPages: totalPages)
                    ctx.beginPage()
                    pageIndex += 1
                    y = topMargin
                    y = drawTableHeader(y: y)
                }
                y = drawTransactionRow(tx, currencyCode: currencyCode, y: y)
            }

            drawPageFooter(pageIndex: pageIndex, totalPages: totalPages)
        }

        let filename = (scope == .month)
            ? "BudgetCrab_Report_ThisMonth.pdf"
            : "BudgetCrab_Report_All.pdf"

        return PDFExportResult(data: data, filename: filename)
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
            withAttributes: [.font: font]
        )
        return y + 30
    }

    private static func drawSubTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
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
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: small, .foregroundColor: UIColor.secondaryLabel]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: font]
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

    private static func drawTableHeader(y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]

        String(localized: "pdf.header.date", bundle: LocalizedBundle.shared.bundle)
            .draw(in: CGRect(x: 36, y: y, width: 90, height: 16), withAttributes: attrs)
        String(localized: "pdf.header.title", bundle: LocalizedBundle.shared.bundle)
            .draw(in: CGRect(x: 130, y: y, width: 260, height: 16), withAttributes: attrs)
        String(localized: "pdf.header.category", bundle: LocalizedBundle.shared.bundle)
            .draw(in: CGRect(x: 395, y: y, width: 120, height: 16), withAttributes: attrs)
        String(localized: "pdf.header.amount", bundle: LocalizedBundle.shared.bundle)
            .draw(in: CGRect(x: 520, y: y, width: 56, height: 16), withAttributes: attrs)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 36, y: y + 18))
        path.addLine(to: CGPoint(x: 576, y: y + 18))
        UIColor.separator.setStroke()
        path.lineWidth = 1
        path.stroke()

        return y + 24
    }

    private static func drawTransactionRow(
        _ tx: Transaction,
        currencyCode: String,
        y: CGFloat
    ) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let date = shortDate(tx.date)

        let categoryName = tx.category.displayNameOrFallback()
        let title = (tx.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? tx.merchant!
            : categoryName

        let signed = Money.formatSigned(
            cents: tx.amountCents,
            isPositive: tx.isIncome,
            currencyCode: currencyCode
        )

        date.draw(in: CGRect(x: 36, y: y, width: 90, height: 16), withAttributes: attrs)
        title.draw(in: CGRect(x: 130, y: y, width: 260, height: 16), withAttributes: attrs)
        categoryName.draw(in: CGRect(x: 395, y: y, width: 120, height: 16), withAttributes: attrs)
        signed.draw(in: CGRect(x: 520, y: y, width: 56, height: 16), withAttributes: attrs)

        return y + rowHeight
    }

    private static func drawPageFooter(pageIndex: Int, totalPages: Int) {
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.tertiaryLabel
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
