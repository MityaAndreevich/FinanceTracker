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
    /// Rows skipped because their stable UUID already exists (idempotent re-import
    /// of our own export, under `.skipDuplicates`).
    var duplicatesSkipped: Int = 0
    /// Rows that carried NO UUID (foreign CSV) yet content-match existing data.
    /// They are still IMPORTED — finance rule: never silently drop a real
    /// transaction — but surfaced so the user can review possible duplicates.
    var possibleDuplicates: Int = 0
    var createdCategories: Int = 0
    var createdSources: Int = 0
    /// Tier-2 mapped import only: rows whose currency was absent in the source
    /// file and assumed to be `defaultCurrencyCode`. Surfaced so the user can
    /// verify the assumption for foreign files.
    var currencyAssumed: Int = 0
    /// Tier-2 mapped import only: rows that could not be normalized (bad amount,
    /// unparseable date, ambiguous debit/credit…). Reported, never dropped
    /// silently — `firstError` carries the first reason.
    var failedRows: Int = 0
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
    /// Stable UUIDs already in the store. Primary dedup key: a re-imported row of
    /// our own export whose UUID is here is an exact re-import → skipped.
    var existingUUIDs: Set<UUID>
    /// Day-granular content heuristics already in the store. Used ONLY to FLAG
    /// foreign rows (no UUID) as possible duplicates — never to drop them.
    var existingHeuristics: Set<String>
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
        var seenUUIDs = preamble.existingUUIDs
        var seenHeuristics = preamble.existingHeuristics
        var processed = 0

        for i in preamble.startIndex..<preamble.rows.count {
            processRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                mode: mode,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                seenUUIDs: &seenUUIDs,
                seenHeuristics: &seenHeuristics,
                result: &result
            )
            processed += 1
            progress?(processed, preamble.totalDataRows)
        }

        try modelContext.save()
        return result
    }

    // MARK: - Tier 2: flexible mapped import

    /// Synchronous mapped import (tests + any off-main caller). Drives the pure
    /// `ImportRowMapper` into SwiftData, reusing the SAME foreign-row dedup as the
    /// generic importer: rows carry no stable UUID, so a content match is FLAGGED
    /// (`possibleDuplicates`) and never dropped. Production goes through
    /// `CSVImportActor.importMappedData`, which reuses `processMappedRow`.
    ///
    /// - parameter hasHeader: whether the first row is a header to skip (the
    ///   mapping's column indices are 0-based into the data rows).
    static func importMappedCSV(
        modelContext: ModelContext,
        data: Data,
        mapping: ColumnMapping,
        hasHeader: Bool = true,
        mode: CSVImportMode = .skipDuplicates,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> CSVImportResult {
        let preamble = try prepare(modelContext: modelContext, data: data)
        var result = CSVImportResult()
        guard !preamble.rows.isEmpty else { return result }

        var categoryCache = preamble.categoryCache
        var sourceCache = preamble.sourceCache
        var seenUUIDs = preamble.existingUUIDs
        var seenHeuristics = preamble.existingHeuristics
        let defaultCurrency = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "USD"

        let start = hasHeader ? 1 : 0
        let total = max(0, preamble.rows.count - start)
        var processed = 0

        var i = start
        while i < preamble.rows.count {
            processMappedRow(
                preamble.rows[i],
                lineIndex: i,
                modelContext: modelContext,
                mapping: mapping,
                defaultCurrency: defaultCurrency,
                mode: mode,
                categoryCache: &categoryCache,
                sourceCache: &sourceCache,
                seenUUIDs: &seenUUIDs,
                seenHeuristics: &seenHeuristics,
                result: &result
            )
            processed += 1
            progress?(processed, total)
            i += 1
        }

        try modelContext.save()
        return result
    }

    /// Parse + normalize + insert a single mapped row. Never throws — per-row
    /// failures are recorded (`failedRows` + `firstError`) so the loop continues.
    /// Foreign rows have no UUID, so they are imported under a fresh UUID and only
    /// flagged as possible duplicates on a content match.
    static func processMappedRow(
        _ rawLine: String,
        lineIndex i: Int,
        modelContext: ModelContext,
        mapping: ColumnMapping,
        defaultCurrency: String,
        mode: CSVImportMode,
        categoryCache: inout [String: Category],
        sourceCache: inout [String: Source],
        seenUUIDs: inout Set<UUID>,
        seenHeuristics: inout Set<String>,
        result: inout CSVImportResult
    ) {
        if rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.skipped += 1
            return
        }

        let cols = parseCSVLine(rawLine)
        if cols.contains(where: { $0.count > MAX_FIELD_LENGTH }) {
            result.failedRows += 1
            if result.firstError == nil {
                result.firstError = String(format: NSLocalizedString("csv.import.error.field_too_long.format", comment: ""), i + 1)
            }
            return
        }

        let normalized: NormalizedTransaction
        switch ImportRowMapper.map(row: cols, mapping: mapping, defaultCurrency: defaultCurrency) {
        case .success(let n):
            normalized = n
        case .failure(let f):
            result.failedRows += 1
            if result.firstError == nil {
                result.firstError = describeRowFailure(f, line: i)
            }
            return
        }

        do {
            let category = try resolveCategory(
                modelContext: modelContext,
                cache: &categoryCache,
                nameFromCSV: normalized.categoryName,
                kindRaw: normalized.typeRaw,
                createdCount: &result.createdCategories
            )
            let source = try getOrCreateSourceIfNeeded(
                modelContext: modelContext,
                cache: &sourceCache,
                name: normalized.account ?? "",
                createdCount: &result.createdSources
            )

            // Foreign-row dedup: flag on content match, never drop.
            let heuristic = transactionIdentity(
                typeRaw: normalized.typeRaw,
                amountCents: normalized.amountCents,
                currency: normalized.currency,
                dayKey: makeISO8601Formatter().string(from: normalized.date),
                categoryName: category.displayName(),
                merchant: normalized.merchant ?? ""
            )
            if mode == .skipDuplicates, seenHeuristics.contains(heuristic) {
                result.possibleDuplicates += 1
            }

            let uuid = UUID()
            let tx = Transaction(
                uuid: uuid,
                typeRaw: normalized.typeRaw,
                amountCents: normalized.amountCents,
                currency: normalized.currency,
                date: normalized.date,
                category: category,
                source: source,
                taxCents: nil,
                note: normalized.note,
                merchant: normalized.merchant
            )
            modelContext.insert(tx)
            seenUUIDs.insert(uuid)
            seenHeuristics.insert(heuristic)
            if normalized.currencyAssumed { result.currencyAssumed += 1 }
            result.imported += 1
        } catch {
            result.failedRows += 1
            if result.firstError == nil {
                result.firstError = error.localizedDescription
            }
        }
    }

    /// Resolve the category for a mapped row: an explicit name goes through
    /// `getOrCreateCategory`; a nil/empty name lands in the seeded uncategorized
    /// bucket of the matching kind — NEVER a failure (re-categorization is the #1
    /// post-import complaint; we don't force it).
    private static func resolveCategory(
        modelContext: ModelContext,
        cache: inout [String: Category],
        nameFromCSV: String?,
        kindRaw: String,
        createdCount: inout Int
    ) throws -> Category {
        if let name = nameFromCSV, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try getOrCreateCategory(
                modelContext: modelContext,
                cache: &cache,
                nameFromCSV: name,
                kindRaw: kindRaw,
                createdCount: &createdCount
            )
        }
        return try resolveUncategorized(
            modelContext: modelContext,
            cache: &cache,
            kindRaw: kindRaw,
            createdCount: &createdCount
        )
    }

    /// The uncategorized bucket for a kind: reuse the seeded "Other" (expense) /
    /// "Income" (income) category by its stable `nameKey`, or create a seeded-style
    /// one if the store was never seeded. Localizes via `nameKey` ("Без категории").
    private static func resolveUncategorized(
        modelContext: ModelContext,
        cache: inout [String: Category],
        kindRaw: String,
        createdCount: inout Int
    ) throws -> Category {
        let isIncome = kindRaw == "income"
        let nameKey = isIncome ? "category.income" : "category.other"
        let cacheKey = "__uncategorized_\(kindRaw)"
        if let existing = cache[cacheKey] { return existing }

        let all = try modelContext.fetch(FetchDescriptor<Category>())
        if let seeded = all.first(where: { $0.nameKey == nameKey && $0.kindRaw == kindRaw }) {
            cache[cacheKey] = seeded
            return seeded
        }

        let nextOrder = (all.filter { $0.kindRaw == kindRaw }.map(\.order).max() ?? 0) + 1
        let new = Category(
            name: isIncome ? "Income" : "Other",
            kindRaw: kindRaw,
            icon: SeedService.uncategorizedIcon,
            order: nextOrder,
            nameKey: nameKey,
            nameCustom: nil
        )
        modelContext.insert(new)
        cache[cacheKey] = new
        createdCount += 1
        return new
    }

    /// Human-readable, localized reason for a mapped-row failure.
    private static func describeRowFailure(_ failure: RowMapFailure, line i: Int) -> String {
        let detail: String
        switch failure {
        case .missingDate:
            detail = NSLocalizedString("csv.import.error.missing_date", comment: "")
        case .invalidDate(let value):
            detail = String(format: NSLocalizedString("csv.import.error.invalid_date.format", comment: ""), value)
        case .amount(let a):
            switch a {
            case .unparsableAmount:
                detail = NSLocalizedString("csv.import.error.invalid_amount", comment: "")
            case .bothColumnsEmpty:
                detail = NSLocalizedString("csv.import.error.debit_credit_empty", comment: "")
            case .bothColumnsFilled:
                detail = NSLocalizedString("csv.import.error.debit_credit_both", comment: "")
            case .unrecognizedType(let t):
                detail = String(format: NSLocalizedString("csv.import.error.unknown_type.format", comment: ""), t)
            }
        }
        return String(format: NSLocalizedString("csv.import.error.row.format", comment: ""), i + 1, detail)
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
            return CSVImportPreamble(rows: [], startIndex: 0, categoryCache: [:], sourceCache: [:], totalDataRows: 0, existingUUIDs: [], existingHeuristics: [])
        }

        var startIndex = 0
        if rows[0].lowercased().contains("date,type,amount") {
            startIndex = 1
        }

        // Cache by "csv name" (lowercased)
        var categoryCache: [String: Category] = [:]
        var sourceCache: [String: Source] = [:]
        var existingUUIDs: Set<UUID> = []
        var existingHeuristics: Set<String> = []

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

            // Precompute both dedup keys for everything already in the store:
            //   • the stable UUID (primary key for idempotent re-import), and
            //   • a day-granular content heuristic (used only to flag foreign rows).
            let dayFormatter = makeISO8601Formatter()
            let existingTxs = try modelContext.fetch(FetchDescriptor<Transaction>())
            for t in existingTxs {
                existingUUIDs.insert(t.uuid)
                existingHeuristics.insert(transactionIdentity(
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
            existingUUIDs: existingUUIDs,
            existingHeuristics: existingHeuristics
        )
    }

    /// Day-granular content heuristic for a transaction.
    ///
    /// Composed of `type | amountCents | currency | day | category | name(merchant)`.
    /// This is NO LONGER the primary dedup key — the stable `uuid` is (see
    /// `processRow`). The heuristic is used ONLY to FLAG foreign rows (CSVs with no
    /// `id` column) as possible duplicates; a false match merely surfaces a review
    /// hint and never drops a row. Day granularity (rather than the exact export
    /// timestamp) is deliberate: foreign CSVs typically carry day-only dates, so a
    /// day key is what actually lets the flag catch same-day content matches.
    /// Category and name are matched case-insensitively to survive locale/casing.
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

    /// Day-only ISO-8601 formatter. Backs the day-granular content heuristic
    /// (`dayKey`) used to flag possible foreign duplicates.
    static func makeISO8601Formatter() -> ISO8601DateFormatter {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        return dateFormatter
    }

    /// Full timestamp ISO-8601 formatter (locale-invariant). This is the format
    /// our export now writes for the `date` column.
    static func makeTimestampFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    /// Parse a CSV `date` cell that may be either a full ISO-8601 timestamp (our
    /// current export) or a day-only date (legacy export / foreign CSVs). Tries
    /// the richer format first, then falls back — so no historical file is rejected.
    static func parseCSVDate(_ raw: String) -> Date? {
        makeTimestampFormatter().date(from: raw) ?? makeISO8601Formatter().date(from: raw)
    }

    /// Parse and insert a single CSV row, mutating caches + result. The caller is
    /// responsible for progress reporting and for saving (batched or final).
    /// Never throws — per-row errors are recorded in `result` so the loop keeps going.
    static func processRow(
        _ rawLine: String,
        lineIndex i: Int,
        modelContext: ModelContext,
        mode: CSVImportMode,
        categoryCache: inout [String: Category],
        sourceCache: inout [String: Source],
        seenUUIDs: inout Set<UUID>,
        seenHeuristics: inout Set<String>,
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
            // `id` column (our export) is optional: absent in legacy/foreign CSVs.
            let idStr = cols.count >= 10 ? cols[9].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let fileUUID: UUID? = idStr.isEmpty ? nil : UUID(uuidString: idStr)

            guard let date = parseCSVDate(dateStr) else {
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

            // Day-granular content heuristic — used ONLY to flag possible foreign
            // duplicates, never to drop a row.
            let heuristic = transactionIdentity(
                typeRaw: typeRaw,
                amountCents: amountCents,
                currency: cleanCurrency,
                dayKey: makeISO8601Formatter().string(from: date),
                categoryName: categoryName,
                merchant: merchant
            )

            // Resolve the identity of the row BEFORE creating any category/source,
            // so a skipped duplicate leaves no side effects.
            let resolvedUUID: UUID
            if let id = fileUUID {
                // Our own export row → dedup on the STABLE UUID.
                //   • skipDuplicates: an existing/seen UUID is an exact re-import → skip.
                //   • importAll: keep both copies, but the inserted row needs a FRESH
                //     UUID because `uuid` is @Attribute(.unique) — reusing it would
                //     upsert (replace) the existing row instead of duplicating it.
                if mode == .skipDuplicates, seenUUIDs.contains(id) {
                    result.duplicatesSkipped += 1
                    return
                }
                resolvedUUID = (mode == .importAll) ? UUID() : id
            } else {
                // Foreign row (no UUID): NEVER drop — we cannot tell a re-import
                // apart from a genuinely-distinct identical transaction. Import it
                // under a fresh UUID and, when it content-matches, flag it.
                resolvedUUID = UUID()
                if mode == .skipDuplicates, seenHeuristics.contains(heuristic) {
                    result.possibleDuplicates += 1
                }
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
                uuid: resolvedUUID,
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
            seenUUIDs.insert(resolvedUUID)
            seenHeuristics.insert(heuristic)
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
