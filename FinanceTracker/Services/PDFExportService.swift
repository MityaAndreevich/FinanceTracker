//
//  PDFExportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import Foundation
import SwiftData
import UIKit

struct PDFExportResult {
    let data: Data
    let filename: String
}

enum PDFExportService {

    static func makeMonthlyReportPDF(modelContext: ModelContext, scope: CSVExportScope) throws -> PDFExportResult {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)
        let summary = computeSummary(txs)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // Letter

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 36

            y = drawTitle("FinanceTracker Report", y: y)

            let rangeText = (scope == .month) ? "This month" : "All time"
            y = drawSubTitle(rangeText, y: y)

            y += 12
            y = drawSummary(summary, currencyCode: summary.currencyCode, y: y)
            y += 16

            y = drawTableHeader(y: y)

            for tx in txs.prefix(80) {
                if y > 720 {
                    ctx.beginPage()
                    y = 36
                    y = drawTableHeader(y: y)
                }
                y = drawTransactionRow(tx, y: y)
            }

            if txs.count > 80 {
                if y > 740 {
                    ctx.beginPage()
                    y = 36
                }
                drawFooter("Showing first 80 transactions. Export CSV for full data.", y: y + 16)
            }
        }

        let filename = (scope == .month)
            ? "FinanceTracker_Report_ThisMonth.pdf"
            : "FinanceTracker_Report_All.pdf"

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

    private static func computeSummary(_ txs: [Transaction]) -> (income: Decimal, expense: Decimal, net: Decimal, currencyCode: String) {
        var income: Decimal = 0
        var expense: Decimal = 0

        // Берем валюту из первой транзакции как “основную” для summary
        let currencyCode = txs.first?.currency ?? "USD"

        for tx in txs {
            let amount = Decimal(tx.amountCents) / 100
            if tx.typeRaw == "income" { income += amount }
            else { expense += amount }
        }

        let net = income - expense
        return (income, expense, net, currencyCode)
    }

    // MARK: - Drawing helpers

    private static func drawTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 22, weight: .bold)
        text.draw(in: CGRect(x: 36, y: y, width: 540, height: 28), withAttributes: [.font: font])
        return y + 30
    }

    private static func drawSubTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        text.draw(in: CGRect(x: 36, y: y, width: 540, height: 18), withAttributes: attrs)
        return y + 18
    }

    private static func drawSummary(_ s: (income: Decimal, expense: Decimal, net: Decimal, currencyCode: String),
                                    currencyCode: String,
                                    y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let small = UIFont.systemFont(ofSize: 13, weight: .regular)

        func line(_ label: String, _ value: String, y: CGFloat) -> CGFloat {
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: small, .foregroundColor: UIColor.secondaryLabel]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: font]
            label.draw(in: CGRect(x: 36, y: y, width: 160, height: 18), withAttributes: labelAttrs)
            value.draw(in: CGRect(x: 210, y: y, width: 366, height: 18), withAttributes: valueAttrs)
            return y + 18
        }

        var yy = y
        yy = line("Income", formatMoney(s.income, currencyCode: currencyCode), y: yy)
        yy = line("Expenses", formatMoney(s.expense, currencyCode: currencyCode), y: yy)
        yy = line("Net", formatMoney(s.net, currencyCode: currencyCode), y: yy)
        return yy
    }

    private static func drawTableHeader(y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]

        "Date".draw(in: CGRect(x: 36, y: y, width: 90, height: 16), withAttributes: attrs)
        "Title".draw(in: CGRect(x: 130, y: y, width: 260, height: 16), withAttributes: attrs)
        "Category".draw(in: CGRect(x: 395, y: y, width: 120, height: 16), withAttributes: attrs)
        "Amount".draw(in: CGRect(x: 520, y: y, width: 56, height: 16), withAttributes: attrs)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 36, y: y + 18))
        path.addLine(to: CGPoint(x: 576, y: y + 18))
        UIColor.separator.setStroke()
        path.lineWidth = 1
        path.stroke()

        return y + 24
    }

    private static func drawTransactionRow(_ tx: Transaction, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let date = shortDate(tx.date)

        // ✅ Везде используем displayName()
        let categoryName = tx.category.displayName()
        let title = (tx.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? tx.merchant!
            : categoryName

        let amount = formatMoney(Decimal(tx.amountCents) / 100, currencyCode: tx.currency)
        let signed = (tx.typeRaw == "income") ? amount : "-\(amount)"

        date.draw(in: CGRect(x: 36, y: y, width: 90, height: 16), withAttributes: attrs)
        title.draw(in: CGRect(x: 130, y: y, width: 260, height: 16), withAttributes: attrs)
        categoryName.draw(in: CGRect(x: 395, y: y, width: 120, height: 16), withAttributes: attrs)
        signed.draw(in: CGRect(x: 520, y: y, width: 56, height: 16), withAttributes: attrs)

        return y + 18
    }

    private static func drawFooter(_ text: String, y: CGFloat) {
        let font = UIFont.systemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        text.draw(in: CGRect(x: 36, y: y, width: 540, height: 16), withAttributes: attrs)
    }

    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: date)
    }

    private static func formatMoney(_ amount: Decimal, currencyCode: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
