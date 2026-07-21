//
//  CSVExportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//
//  V2 (1.0.3): the formatting core is factored over a plain Row so the SAME
//  export serves two stores — the live V2 container (normal path) and the
//  UNMIGRATED V1 store opened read-only by the pre-migration screen and the
//  degraded floor (design doc §9.4/§10.4). One format, two fetch paths; the
//  data-safety surfaces reuse the export rather than growing a second one.
//

import Foundation
import SwiftData

enum CSVExportScope {
    case month
    case all
}

struct CSVExportService {

    /// One export line's worth of data, independent of which schema it came from.
    struct Row {
        let date: Date
        let typeRaw: String
        let amountCents: Int
        let currency: String
        let categoryName: String
        let sourceName: String
        let taxCents: Int?
        let note: String
        let merchant: String
        let id: String
        /// Raw split decomposition (cents + category display name), in order.
        /// Empty for unsplit rows and for the V1 (pre-split) export path.
        var splits: [(amountCents: Int, categoryName: String)] = []
    }

    /// The trailing `splits` cell: `cents:name;cents:name`, category names
    /// percent-encoded so `;` `:` in a custom name can't corrupt the field.
    /// Cents as plain integers — our own machine format, locale-proof.
    static func encodeSplits(_ splits: [(amountCents: Int, categoryName: String)]) -> String {
        splits.map { split in
            let name = split.categoryName.addingPercentEncoding(
                withAllowedCharacters: splitNameAllowed) ?? split.categoryName
            return "\(split.amountCents):\(name)"
        }.joined(separator: ";")
    }

    static func decodeSplits(_ cell: String) -> [(amountCents: Int, categoryName: String)] {
        let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed.split(separator: ";").compactMap { pair in
            guard let colon = pair.firstIndex(of: ":"),
                  let cents = Int(pair[..<colon]), cents > 0 else { return nil }
            let encoded = String(pair[pair.index(after: colon)...])
            let name = encoded.removingPercentEncoding ?? encoded
            return name.isEmpty ? nil : (cents, name)
        }
    }

    private static let splitNameAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: ";:%,\"")
        return set
    }()

    // MARK: - Public entry points

    static func makeCSV(modelContext: ModelContext, scope: CSVExportScope) throws -> (data: Data, filename: String) {
        let txs = try fetchTransactions(modelContext: modelContext, scope: scope)
        let rows = txs.map { tx in
            Row(
                date: tx.date,
                typeRaw: tx.typeRaw,
                amountCents: tx.amountCents,
                currency: tx.currency,
                // ✅ Экспортируем видимое имя категории по нашей логике локализации
                categoryName: tx.category.displayNameOrFallback(),
                sourceName: tx.source?.name ?? "",
                taxCents: tx.taxCents,
                note: tx.note ?? "",
                merchant: tx.merchant ?? "",
                id: tx.uuid.uuidString,
                splits: CategoryAttribution.orderedSplits(of: tx).map {
                    ($0.amountCents, ($0.category ?? tx.category).displayNameOrFallback())
                }
            )
        }
        return (makeCSV(rows: rows), filenameFor(scope: scope))
    }

    /// Export from the UNMIGRATED V1 store, read-only — the pre-migration
    /// screen's "Export a copy…" and the degraded floor's "Export my data".
    /// Always all-time: this is a data-safety copy, not a report. The premium
    /// all-time gate deliberately does not apply here — charging to back up
    /// your own data ahead of OUR migration would be indefensible.
    static func makeCSVFromV1Store() throws -> (data: Data, filename: String) {
        let container = try SharedModelContainer.openV1ReadOnly()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FinanceTrackerSchemaV1.Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let txs = try context.fetch(descriptor)

        let bundle = LocalizedBundle.shared.bundle
        let rows = txs.map { tx in
            Row(
                date: tx.date,
                typeRaw: tx.typeRaw,
                amountCents: tx.amountCents,
                currency: tx.currency,
                categoryName: v1CategoryDisplayName(tx.category, bundle: bundle),
                sourceName: tx.source?.name ?? "",
                taxCents: tx.taxCents,
                note: tx.note ?? "",
                merchant: tx.merchant ?? "",
                id: tx.uuid.uuidString
            )
        }
        return (makeCSV(rows: rows), filenameFor(scope: .all))
    }

    /// V1's Category has no display helpers (frozen storage shape) — resolve
    /// the same way `Category.displayName(bundle:)` does: custom → localized
    /// key → legacy name.
    private static func v1CategoryDisplayName(
        _ category: FinanceTrackerSchemaV1.Category, bundle: Bundle
    ) -> String {
        if let custom = category.nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        if let key = category.nameKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            let localized = bundle.localizedString(forKey: key, value: key, table: nil)
            if localized != key { return localized }
        }
        return category.name
    }

    // MARK: - Formatting core (schema-independent)

    static func makeCSV(rows: [Row]) -> Data {
        var lines: [String] = []
        // `id` is the LAST column so the leading `date,type,amount…` prefix stays
        // stable for header detection and for interop with foreign 9-column CSVs.
        // `splits` is the LAST column (after `id`): 9-column foreign CSVs and
        // 10-column legacy own exports keep parsing everywhere, and the 1.0.2
        // importer's `cols.count >= 9` guard simply ignores the extra cell.
        lines.append("date,type,amount,currency,category,source,tax,note,merchant,id,splits")

        // Exact ISO-8601 timestamp (with time), locale-invariant. Day-only export
        // lost intra-day ordering and made same-day transactions indistinguishable;
        // the stable `id` column now carries identity, and the full timestamp keeps
        // the visible date precise.
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

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

        for row in rows {
            let date = dateFormatter.string(from: row.date)
            let amount = centsToString(row.amountCents, formatter: moneyFormatter)
            let category = escape(row.categoryName)
            let source = escape(row.sourceName)
            let tax = row.taxCents.map { centsToString($0, formatter: moneyFormatter) } ?? ""
            let note = escape(row.note)
            let merchant = escape(row.merchant)

            let splits = escape(encodeSplits(row.splits))
            lines.append("\(date),\(row.typeRaw),\(amount),\(row.currency),\(category),\(source),\(tax),\(note),\(merchant),\(row.id),\(splits)")
        }

        return Data(lines.joined(separator: "\n").utf8)
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
