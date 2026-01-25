//
//  TSVExportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import Foundation
import SwiftData

struct TSVExportResult {
    let data: Data
    let filename: String
}

enum TSVExportService {

    /// TSV = tab-separated values. Excel/Numbers open it perfectly.
    static func makeTSV(modelContext: ModelContext, scope: CSVExportScope) throws -> TSVExportResult {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)

        // Header row
        var lines: [String] = []
        lines.append([
            "Date",
            "Type",
            "Amount",
            "Currency",
            "Category",
            "Source",
            "Merchant",
            "Note"
        ].joined(separator: "\t"))

        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "yyyy-MM-dd"

        for tx in txs {
            let date = df.string(from: tx.date)
            let type = tx.typeRaw
            let amount = formatDecimal(cents: tx.amountCents) // 12.34
            let currency = tx.currency
            let category = safe(tx.category.name)
            let source = safe(tx.source?.name ?? "")
            let merchant = safe(tx.merchant ?? "")
            let note = safe(tx.note ?? "")

            lines.append([
                date,
                type,
                amount,
                currency,
                category,
                source,
                merchant,
                note
            ].joined(separator: "\t"))
        }

        let tsv = lines.joined(separator: "\n")
        guard let data = tsv.data(using: .utf8) else {
            throw NSError(domain: "TSVExportService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode TSV as UTF-8."
            ])
        }

        let filename = (scope == .month)
            ? "FinanceTracker_ThisMonth.tsv"
            : "FinanceTracker_All.tsv"

        return TSVExportResult(data: data, filename: filename)
    }

    // MARK: - Fetch

    private static func fetchTransactions(modelContext: ModelContext, scope: CSVExportScope) throws -> [Transaction] {
        let all = try modelContext.fetch(FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))

        guard scope == .month else { return all }

        let cal = Calendar.current
        let now = Date()
        return all.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    // MARK: - Helpers

    /// Excel loves "12.34" format
    private static func formatDecimal(cents: Int) -> String {
        let value = Decimal(cents) / 100
        // Force dot decimal separator to keep Excel happy
        let ns = NSDecimalNumber(decimal: value)
        return ns.stringValue
    }

    /// Clean fields for TSV: remove tabs/newlines, trim.
    private static func safe(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
