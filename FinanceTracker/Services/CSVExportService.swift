//
//  CSVExportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import Foundation
import SwiftData

enum CSVExportScope {
    case month
    case all
}

struct CSVExportService {
    static func makeCSV(modelContext: ModelContext, scope: CSVExportScope) throws -> (data: Data, filename: String) {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)

        var lines: [String] = []
        lines.append("date,type,amount,currency,category,source,tax,note,merchant")

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // Locale-INVARIANT money formatting. A CSV is a comma-delimited file, so
        // the amount cell must never itself contain a comma. Using the user's
        // locale (e.g. ru_RU) writes "1,52" and grouping writes "1,234.56" — both
        // spill the amount into the next column and corrupt every field after it.
        // Fix: force "." as the decimal separator (en_US_POSIX) and disable
        // grouping. The reader (Money.parseCents) reads "." back exactly.
        let moneyFormatter = NumberFormatter()
        moneyFormatter.numberStyle = .decimal
        moneyFormatter.locale = Locale(identifier: "en_US_POSIX")
        moneyFormatter.usesGroupingSeparator = false
        moneyFormatter.decimalSeparator = "."
        moneyFormatter.maximumFractionDigits = 2
        moneyFormatter.minimumFractionDigits = 2

        for tx in txs {
            let date = dateFormatter.string(from: tx.date)
            let type = tx.typeRaw
            let amount = centsToString(tx.amountCents, formatter: moneyFormatter)
            let currency = tx.currency

            // ✅ Экспортируем видимое имя категории по нашей логике локализации
            let category = escape(tx.category.displayName())
            let source = escape(tx.source?.name ?? "")
            let tax = tx.taxCents.map { centsToString($0, formatter: moneyFormatter) } ?? ""
            let note = escape(tx.note ?? "")
            let merchant = escape(tx.merchant ?? "")

            let row = "\(date),\(type),\(amount),\(currency),\(category),\(source),\(tax),\(note),\(merchant)"
            lines.append(row)
        }

        let csvString = lines.joined(separator: "\n")
        let data = Data(csvString.utf8)

        let filename = filenameFor(scope: scope)
        return (data, filename)
    }

    // MARK: - Fetch

    private static func fetchTransactions(modelContext: ModelContext, scope: CSVExportScope) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)

        switch scope {
        case .all:
            return all
        case .month:
            let calendar = Calendar.current
            let now = Date()
            return all.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        }
    }

    // MARK: - Formatting helpers

    private static func centsToString(_ cents: Int, formatter: NumberFormatter) -> String {
        let amount = Decimal(cents) / 100
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }

    private static func filenameFor(scope: CSVExportScope) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        switch scope {
        case .all:
            return "FinanceTracker_All_\(today).csv"
        case .month:
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "yyyy-MM"
            let month = monthFormatter.string(from: Date())
            return "FinanceTracker_Month_\(month)_\(today).csv"
        }
    }
}
