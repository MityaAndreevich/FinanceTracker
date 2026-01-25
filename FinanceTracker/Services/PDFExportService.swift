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
        // 1) Достаём транзакции
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)

        // 2) Считаем суммы
        let summary = computeSummary(txs)

        // 3) Рендерим PDF через UIGraphicsPDFRenderer
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // Letter

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            var y: CGFloat = 36

            // Title
            y = drawTitle("FinanceTracker Report", y: y)

            // Date
            let rangeText = (scope == .month) ? "This month" : "All time"
            y = drawSubTitle(rangeText, y: y)

            y += 12

            // Summary cards (text)
            y = drawSummary(summary, y: y)
            y += 16

            // Table header
            y = drawTableHeader(y: y)

            // Rows
            for tx in txs.prefix(80) { // чтобы не упереться в 1 страницу
                if y > 720 {
                    ctx.beginPage()
                    y = 36
                    y = drawTableHeader(y: y)
                }
                y = drawTransactionRow(tx, y: y)
            }

            // Footer note
            if txs.count > 80 {
                if y > 740 {
                    ctx.beginPage()
                    y = 36
                }
                let more = "Showing first 80 transactions. Export CSV for full data."
                drawFooter(more, y: y + 16)
            }
        }

        let filename = (scope == .month)
            ? "FinanceTracker_Report_ThisMonth.pdf"
            : "FinanceTracker_Report_All.pdf"

        return PDFExportResult(data: data, filename: filename)
    }

    // MARK: - Data

    private static func fetchTransactions(modelContext: ModelContext, scope: CSVExportScope) throws -> [Transaction] {
        let all = try modelContext.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)]))

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
            if tx.typeRaw == "income" { income += amount }
            else { expense += amount }
        }

        let net = income - expense
        return (income, expense, net)
    }

    // MARK: - Drawing helpers

    private static func drawTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 22, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let rect = CGRect(x: 36, y: y, width: 540, height: 28)
        text.draw(in: rect, withAttributes: attrs)
        return y + 30
    }

    private static func drawSubTitle(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let rect = CGRect(x: 36, y: y, width: 540, height: 18)
        text.draw(in: rect, withAttributes: attrs)
        return y + 18
    }

    private static func drawSummary(_ s: (income: Decimal, expense: Decimal, net: Decimal), y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let small = UIFont.systemFont(ofSize: 13, weight: .regular)

        func line(_ label: String, _ value: String, y: CGFloat) -> CGFloat {
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: small, .foregroundColor: UIColor.secondaryLabel]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: font]

            label.draw(in: CGRect(x: 36, y: y, width: 160, height: 18), withAttributes: labelAttrs)
            value.draw(in: CGRect(x: 210, y: y, width: 366, height: 18), withAttributes: valueAttrs)
            return y + 18
        }

        let income = formatMoney(s.income)
        let expense = formatMoney(s.expense)
        let net = formatMoney(s.net)

        var yy = y
        yy = line("Income", income, y: yy)
        yy = line("Expenses", expense, y: yy)
        yy = line("Net", net, y: yy)

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

        // separator
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
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        let date = shortDate(tx.date)
        let title = (tx.merchant?.isEmpty == false) ? tx.merchant! : tx.category.name
        let category = tx.category.name
        let amount = formatMoney(Decimal(tx.amountCents) / 100)
        let signed = (tx.typeRaw == "income") ? amount : "-\(amount)"

        date.draw(in: CGRect(x: 36, y: y, width: 90, height: 16), withAttributes: attrs)
        title.draw(in: CGRect(x: 130, y: y, width: 260, height: 16), withAttributes: attrs)
        category.draw(in: CGRect(x: 395, y: y, width: 120, height: 16), withAttributes: attrs)
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

    private static func formatMoney(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
