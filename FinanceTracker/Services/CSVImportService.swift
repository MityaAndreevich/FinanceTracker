//
//  CSVImportService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import Foundation
import SwiftData

struct CSVImportResult {
    var imported: Int = 0
    var skipped: Int = 0
    var createdCategories: Int = 0
    var createdSources: Int = 0
    var firstError: String? = nil
}

struct CSVImportService {

    // MARK: - Public API

    /// Synchronous variant kept for backwards compatibility / unit tests.
    static func importCSV(modelContext: ModelContext, data: Data) throws -> CSVImportResult {
        try importCSV(modelContext: modelContext, data: data, progress: nil)
    }

    /// Import with optional progress callback.
    /// - parameter progress: invoked with (rowsProcessed, totalRows). Called on the same
    ///   thread the function runs on — callers using it from a Task should hop to MainActor.
    static func importCSV(
        modelContext: ModelContext,
        data: Data,
        progress: ((Int, Int) -> Void)?
    ) throws -> CSVImportResult {
        var result = CSVImportResult()

        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "File is not valid UTF-8 text"
            ])
        }

        let rows = splitCSVRows(content)
        guard !rows.isEmpty else { return result }

        var startIndex = 0
        if rows[0].lowercased().contains("date,type,amount") {
            startIndex = 1
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // Cache by "csv name" (lowercased)
        var categoryCache: [String: Category] = [:]
        var sourceCache: [String: Source] = [:]

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
        } catch {
            // Not critical, we'll proceed without the cache.
        }

        let totalDataRows = max(0, rows.count - startIndex)
        var processed = 0

        for i in startIndex..<rows.count {
            // Trim ONLY at the row boundary to drop trailing CR / blank lines.
            // Field-level trimming is done after parsing.
            let rawLine = rows[i]
            if rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.skipped += 1
                processed += 1
                progress?(processed, totalDataRows)
                continue
            }

            do {
                let cols = parseCSVLine(rawLine)
                guard cols.count >= 9 else {
                    result.skipped += 1
                    processed += 1
                    progress?(processed, totalDataRows)
                    continue
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
                let cleanCurrency = currency.isEmpty ? "USD" : currency

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
                result.imported += 1

            } catch {
                result.skipped += 1
                if result.firstError == nil {
                    result.firstError = error.localizedDescription
                }
            }

            processed += 1
            progress?(processed, totalDataRows)
        }

        try modelContext.save()
        return result
    }

    // MARK: - Helpers

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
