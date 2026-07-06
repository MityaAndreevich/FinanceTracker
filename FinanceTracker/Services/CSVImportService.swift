//
//  CSVImportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import Foundation
import SwiftData

/// How the importer treats rows whose identity already exists in the store
/// (or earlier in the same file). Mirrors OS file-copy semantics.
enum CSVImportMode {
    /// Non-destructive default: rows that already exist are counted and skipped.
    case skipDuplicates
    /// "Keep both": insert every row even if an identical one already exists.
    case importAll
}

struct CSVImportResult {
    var imported: Int = 0
    var skipped: Int = 0
    var duplicatesSkipped: Int = 0
    var createdCategories: Int = 0
    var createdSources: Int = 0
    var firstError: String? = nil
}

/// Parsed preamble shared by the synchronous import (tests) and the async
/// `CSVImportActor` (production). Holds everything computed before the row loop
/// so the heavy parse logic lives in exactly one place (`processRow`).
struct CSVImportPreamble {
    var rows: [String]
    var startIndex: Int
    var categoryCache: [String: Category]
    var sourceCache: [String: Source]
    var totalDataRows: Int
    /// Dedup identities of transactions already in the store (see `transactionIdentity`).
    var existingIdentities: Set<String>
}

struct CSVImportService {

    // MARK: - Limits (T-10)
    static let MAX_ROWS = 10_000
    static let MAX_FIELD_LENGTH = 1_024

    // MARK: - Public API

    /// Synchronous import used by unit tests and any caller already off the main
    /// thread. The production UI goes through `CSVImportActor` (see
    /// DataSettingsView), which reuses the very same `prepare` / `processRow`
    /// helpers on a background ModelActor executor.
    ///
    /// - parameter mode: how to treat rows whose identity already exists
    ///   (`.skipDuplicates` is the non-destructive default).
    /// - parameter progress: invoked with (rowsProcessed, totalRows) on the same
    ///   thread the function runs on — callers using it from a Task should hop to MainActor.
    static func importCSV(
        modelContext: ModelContext,
        data: Data,
        mode: CSVImportMode = .skipDuplicates,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> CSVImportResult {
        let preamble = try prepare(modelContext: modelContext, data: data)
        var result = CSVImportResult()
        guard !preamble.rows.isEmpty else { return result }

        var categoryCache = preamble.categoryCache
        var sourceCache = preamble.sourceCache
        var seenIdentities = preamble.existingIdentities
        let dateFormatter = makeISO8601Formatter()
        var processed = 0

        for i in preamble.startIndex..<preamble.rows.count {
            processRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                dateFormatter: dateFormatter,
                mode: mode,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                seenIdentities: &seenIdentities,
                result: &result
            )
            processed += 1
            progress?(processed, preamble.totalDataRows)
        }

        try modelContext.save()
        return result
    }

    // MARK: - Shared parse internals (used by both sync API and CSVImportActor)

    /// Decode, split, detect header, preload caches and enforce the row limit.
    /// Touches `modelContext` (fetch only) — runs on the caller's executor.
    static func prepare(modelContext: ModelContext, data: Data) throws -> CSVImportPreamble {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "File is not valid UTF-8 text"
            ])
        }

        let rows = splitCSVRows(content)
        guard !rows.isEmpty else {
            return CSVImportPreamble(rows: [], startIndex: 0, categoryCache: [:], sourceCache: [:], totalDataRows: 0, existingIdentities: [])
        }

        var startIndex = 0
        if rows[0].lowercased().contains("date,type,amount") {
            startIndex = 1
        }

        // Cache by "csv name" (lowercased)
        var categoryCache: [String: Category] = [:]
        var sourceCache: [String: Source] = [:]
        var existingIdentities: Set<String> = []

        // Preload existing categories/sources. Match against BOTH:
        //   • the user-visible (custom or localized) name, and
        //   • the nameKey itself if it's a seeded category (e.g. "category.food"),
        // so importing "Food" into an English locale doesn't create a duplicate of the seeded Food.
        do {
            let existingCategories = try modelContext.fetch(FetchDescriptor<Category>())
            for c in existingCategories {
                if let custom = c.nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
                    categoryCache[custom.lowercased()] = c
                }
                // Always seed under the legacy English name for stable interop
                categoryCache[c.name.lowercased()] = c
                // And under the localized name if we have a key
                if let key = c.nameKey, !key.isEmpty {
                    let localized = NSLocalizedString(key, comment: "")
                    if !localized.isEmpty && localized != key {
                        categoryCache[localized.lowercased()] = c
                    }
                }
            }

            let existingSources = try modelContext.fetch(FetchDescriptor<Source>())
            for s in existingSources {
                sourceCache[s.name.lowercased()] = s
            }

            // Precompute dedup identities of everything already in the store, so
            // re-importing a Crab export doesn't silently duplicate rows.
            let dayFormatter = makeISO8601Formatter()
            let existingTxs = try modelContext.fetch(FetchDescriptor<Transaction>())
            for t in existingTxs {
                existingIdentities.insert(transactionIdentity(
                    typeRaw: t.typeRaw,
                    amountCents: t.amountCents,
                    currency: t.currency,
                    dayKey: dayFormatter.string(from: t.date),
                    categoryName: t.category.displayName(),
                    merchant: t.merchant ?? ""
                ))
            }
        } catch {
            // Not critical, we'll proceed without the cache.
        }

        let totalDataRows = max(0, rows.count - startIndex)

        if totalDataRows > MAX_ROWS {
            let msg = String(format: NSLocalizedString("csv.import.error.too_many_rows.format", comment: ""), totalDataRows)
            throw NSError(domain: "CSVImport", code: 4, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return CSVImportPreamble(
            rows: rows,
            startIndex: startIndex,
            categoryCache: categoryCache,
            sourceCache: sourceCache,
            totalDataRows: totalDataRows,
            existingIdentities: existingIdentities
        )
    }

    /// Stable, order-independent dedup identity for a transaction.
    ///
    /// Composed of `type | amountCents | currency | day | category | name(merchant)`.
    /// Day granularity (not the full timestamp) because CSV export truncates the
    /// date to the calendar day — so a stored transaction and its exported/
    /// re-imported copy hash to the same identity. Category and name are matched
    /// case-insensitively to survive locale/casing round-trips.
    static func transactionIdentity(
        typeRaw: String,
        amountCents: Int,
        currency: String,
        dayKey: String,
        categoryName: String,
        merchant: String
    ) -> String {
        [
            typeRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            String(amountCents),
            currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            dayKey,
            categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }

    static func makeISO8601Formatter() -> ISO8601DateFormatter {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        return dateFormatter
    }

    /// Parse and insert a single CSV row, mutating caches + result. The caller is
    /// responsible for progress reporting and for saving (batched or final).
    /// Never throws — per-row errors are recorded in `result` so the loop keeps going.
    static func processRow(
        _ rawLine: String,
        lineIndex i: Int,
        modelContext: ModelContext,
        dateFormatter: ISO8601DateFormatter,
        mode: CSVImportMode,
        categoryCache: inout [String: Category],
        sourceCache: inout [String: Source],
        seenIdentities: inout Set<String>,
        result: inout CSVImportResult
    ) {
        // Trim ONLY at the row boundary to drop trailing CR / blank lines.
        // Field-level trimming is done after parsing.
        if rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.skipped += 1
            return
        }

        do {
            let cols = parseCSVLine(rawLine)
            if cols.contains(where: { $0.count > MAX_FIELD_LENGTH }) {
                let msg = String(format: NSLocalizedString("csv.import.error.field_too_long.format", comment: ""), i + 1)
                throw NSError(domain: "CSVImport", code: 5, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            guard cols.count >= 9 else {
                result.skipped += 1
                return
            }

            // Trim non-text fields. Free-text fields (categoryName, sourceName,
            // note, merchant) keep their internal whitespace.
            let dateStr = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let typeRaw = cols[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let amountStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let currency = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryName = cols[4]
            let sourceName = cols[5]
            let taxStr = cols[6].trimmingCharacters(in: .whitespacesAndNewlines)
            let note = cols[7]
            let merchant = cols[8]

            guard let date = dateFormatter.date(from: dateStr) else {
                throw makeLineError(i, "Invalid date: \(dateStr)")
            }

            guard typeRaw == "income" || typeRaw == "expense" else {
                throw makeLineError(i, "Invalid type: \(typeRaw)")
            }

            guard let amountCents = Money.parseCents(from: amountStr) else {
                throw makeLineError(i, "Invalid amount: \(amountStr)")
            }

            let taxCents = Money.parseCents(from: taxStr)
            let rawCode = currency.uppercased()
            let cleanCurrency = (!rawCode.isEmpty && isValidISO4217(rawCode))
                ? rawCode
                : (UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "USD")

            // Dedup by stable identity BEFORE creating any category/source, so a
            // skipped duplicate leaves no side effects. Under `.importAll` we skip
            // the check entirely and keep both copies.
            let identity = transactionIdentity(
                typeRaw: typeRaw,
                amountCents: amountCents,
                currency: cleanCurrency,
                dayKey: dateFormatter.string(from: date),
                categoryName: categoryName,
                merchant: merchant
            )
            if mode == .skipDuplicates, seenIdentities.contains(identity) {
                result.duplicatesSkipped += 1
                return
            }

            let category = try getOrCreateCategory(
                modelContext: modelContext,
                cache: &categoryCache,
                nameFromCSV: categoryName,
                kindRaw: typeRaw,
                createdCount: &result.createdCategories
            )

            let source: Source? = try getOrCreateSourceIfNeeded(
                modelContext: modelContext,
                cache: &sourceCache,
                name: sourceName,
                createdCount: &result.createdSources
            )

            let tx = Transaction(
                typeRaw: typeRaw,
                amountCents: amountCents,
                currency: cleanCurrency,
                date: date,
                category: category,
                source: source,
                taxCents: taxCents,
                note: note.isEmpty ? nil : note,
                merchant: merchant.isEmpty ? nil : merchant
            )

            modelContext.insert(tx)
            seenIdentities.insert(identity)
            result.imported += 1

        } catch {
            result.skipped += 1
            if result.firstError == nil {
                result.firstError = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    static func isValidISO4217(_ code: String) -> Bool {
        Locale.commonISOCurrencyCodes.contains(code.uppercased())
    }

    private static func getOrCreateCategory(
        modelContext: ModelContext,
        cache: inout [String: Category],
        nameFromCSV: String,
        kindRaw: String,
        createdCount: inout Int
    ) throws -> Category {
        let trimmed = nameFromCSV.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "CSVImport", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Missing category name"
            ])
        }

        let key = trimmed.lowercased()
        if let existing = cache[key] { return existing }

        let all = try modelContext.fetch(FetchDescriptor<Category>())
        let nextOrder = (all.filter { $0.kindRaw == kindRaw }.map(\.order).max() ?? 0) + 1

        let new = Category(
            name: trimmed,
            kindRaw: kindRaw,
            icon: nil,
            order: nextOrder,
            nameKey: nil,
            nameCustom: trimmed
        )

        modelContext.insert(new)
        cache[key] = new
        createdCount += 1
        return new
    }

    private static func getOrCreateSourceIfNeeded(
        modelContext: ModelContext,
        cache: inout [String: Source],
        name: String,
        createdCount: inout Int
    ) throws -> Source? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let key = trimmed.lowercased()
        if let existing = cache[key] { return existing }

        let new = Source(name: trimmed, note: nil)
        modelContext.insert(new)
        cache[key] = new
        createdCount += 1
        return new
    }

    private static func splitCSVRows(_ content: String) -> [String] {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    /// RFC 4180-ish CSV row parser.
    /// IMPORTANT: This does NOT trim whitespace inside fields — callers must
    /// trim explicitly for fields that should be whitespace-stripped (e.g. date, type, amount).
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)

        var i = 0
        while i < chars.count {
            let c = chars[i]

            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                } else {
                    inQuotes.toggle()
                    i += 1
                    continue
                }
            }

            if c == "," && !inQuotes {
                result.append(current)
                current = ""
                i += 1
                continue
            }

            current.append(c)
            i += 1
        }

        result.append(current)
        return result
    }

    private static func makeLineError(_ lineIndex: Int, _ message: String) -> NSError {
        NSError(domain: "CSVImport", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Line \(lineIndex + 1): \(message)"
        ])
    }
}
