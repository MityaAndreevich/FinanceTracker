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
        let filename = (scope == .month)
            ? "BudgetCrab_ThisMonth.tsv"
            : "BudgetCrab_All.tsv"
        return try makeTSV(transactions: txs, filename: filename)
    }

    /// A report's period (1.0.6). Same columns, same rules; the file is named by
    /// the period's ASCII identity.
    static func makeTSV(modelContext: ModelContext, period: ReportPeriod, calendar: Calendar = .current) throws -> TSVExportResult {
        let range = period.range(calendar: calendar)
        let lo = range.lowerBound, hi = range.upperBound
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= lo && $0.date < hi },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        let txs = try modelContext.fetch(descriptor)
        return try makeTSV(transactions: txs, filename: "BudgetCrab_\(period.identity(calendar: calendar).replacingOccurrences(of: ":", with: "_")).tsv")
    }

    /// COLUMNS. The first eight are the 1.0.0 format and are unchanged. Two were
    /// added in 1.0.6 for D47:
    ///
    ///   Split           "1 of 2" on each part of a split transaction; empty otherwise
    ///   Transaction ID  the parent's UUID — the same on every part, so parts can
    ///                   be grouped back into one purchase in a spreadsheet
    ///
    /// A split transaction is ONE ROW PER PART, with the part's amount and the
    /// part's category (the remainder part carries the parent's category), so
    /// that Σ Amount by Category computed in Excel equals what Analytics shows —
    /// `CategoryAttribution.shares` is the single source of both. Before 1.0.6 a
    /// split exported as one row under the parent's category, and the two
    /// disagreed for anyone who split (`TSVSplitEqualityTests`). Σ Amount over
    /// the whole file is unchanged by this: the parts sum to the parent.
    private static func makeTSV(transactions txs: [Transaction], filename: String) throws -> TSVExportResult {
        var lines: [String] = []
        lines.append([
            "Date",
            "Type",
            "Amount",
            "Currency",
            "Category",
            "Source",
            "Merchant",
            "Note",
            "Split",
            "Transaction ID"
        ].joined(separator: "\t"))

        let df = dateFormatter

        for tx in txs {
            let date = df.string(from: tx.date)
            let type = tx.typeRaw
            let currency = tx.currency
            let source = safe(tx.source?.name ?? "")
            let merchant = safe(tx.merchant ?? "")
            let note = safe(tx.note ?? "")
            let id = tx.uuid.uuidString

            let shares = CategoryAttribution.shares(for: tx)
            let isSplit = shares.count > 1
            for (index, share) in shares.enumerated() {
                let amount = Money.plainDecimalString(cents: share.amountCents)
                let category = safe(share.category.displayNameOrFallback())
                let split = isSplit ? "\(index + 1) of \(shares.count)" : ""
                lines.append([
                    date,
                    type,
                    amount,
                    currency,
                    category,
                    source,
                    merchant,
                    note,
                    split,
                    id
                ].joined(separator: "\t"))
            }
        }

        let tsv = lines.joined(separator: "\n")
        guard let data = tsv.data(using: .utf8) else {
            throw NSError(domain: "TSVExportService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode TSV as UTF-8."
            ])
        }

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
