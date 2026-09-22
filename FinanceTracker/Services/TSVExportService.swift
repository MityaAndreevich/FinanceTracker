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

    static func makeTSV(modelContext: ModelContext, scope: CSVExportScope) throws -> TSVExportResult {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)

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

        let df = dateFormatter

        for tx in txs {
            let date = df.string(from: tx.date)
            let type = tx.typeRaw
            let amount = Money.plainDecimalString(cents: tx.amountCents)
            let currency = tx.currency

            // ✅ displayName()
            let category = safe(tx.category.displayNameOrFallback())
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
            ? "BudgetCrab_ThisMonth.tsv"
            : "BudgetCrab_All.tsv"

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

    /// The calendar day in the user's time zone, as `yyyy-MM-dd`, and nothing
    /// else. Locale and calendar are pinned: with `.current` a device set to
    /// Thailand writes Buddhist-era years (2569) and one set to Egypt writes
    /// Arabic-Indic digits, and Excel reads neither as a date. Internal so
    /// `TSVExportServiceTests` can pin the two properties a unit test cannot
    /// otherwise observe.
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static func safe(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
