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

    /// Импортирует CSV в формате нашего экспорта.
    /// Ожидаемые колонки:
    /// date,type,amount,currency,category,source,tax,note,merchant
    static func importCSV(modelContext: ModelContext, data: Data) throws -> CSVImportResult {
        var result = CSVImportResult()

        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not valid UTF-8 text"])
        }

        let rows = splitCSVRows(content)
        guard !rows.isEmpty else { return result }

        // Пропускаем header, если он похож на наш
        var startIndex = 0
        if rows[0].lowercased().contains("date,type,amount") {
            startIndex = 1
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // Кэш, чтобы не делать лишних fetch'ей
        var categoryCache: [String: Category] = [:]
        var sourceCache: [String: Source] = [:]

        // Подтягиваем существующие категории/источники в кеш (по имени)
        do {
            let existingCategories = try modelContext.fetch(FetchDescriptor<Category>())
            for c in existingCategories {
                categoryCache[c.name.lowercased()] = c
            }
            let existingSources = try modelContext.fetch(FetchDescriptor<Source>())
            for s in existingSources {
                sourceCache[s.name.lowercased()] = s
            }
        } catch {
            // Не критично, импорт всё равно попробуем
        }

        for i in startIndex..<rows.count {
            let rawLine = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if rawLine.isEmpty {
                result.skipped += 1
                continue
            }

            do {
                let cols = parseCSVLine(rawLine)

                // Должно быть минимум 9 колонок
                guard cols.count >= 9 else {
                    result.skipped += 1
                    continue
                }

                let dateStr = cols[0]
                let typeRaw = cols[1].lowercased()
                let amountStr = cols[2]
                let currency = cols[3].isEmpty ? "USD" : cols[3]
                let categoryName = cols[4]
                let sourceName = cols[5]
                let taxStr = cols[6]
                let note = cols[7]
                let merchant = cols[8]

                guard let date = dateFormatter.date(from: dateStr) else {
                    throw makeLineError(i, "Invalid date: \(dateStr)")
                }

                guard typeRaw == "income" || typeRaw == "expense" else {
                    throw makeLineError(i, "Invalid type: \(typeRaw)")
                }

                guard let amountCents = parseMoneyToCents(amountStr) else {
                    throw makeLineError(i, "Invalid amount: \(amountStr)")
                }

                let taxCents = parseMoneyToCents(taxStr)

                // Category: обязателен
                let category = try getOrCreateCategory(
                    modelContext: modelContext,
                    cache: &categoryCache,
                    name: categoryName,
                    kindRaw: typeRaw == "income" ? "income" : "expense",
                    createdCount: &result.createdCategories
                )

                // Source: optional
                let source: Source? = try getOrCreateSourceIfNeeded(
                    modelContext: modelContext,
                    cache: &sourceCache,
                    name: sourceName,
                    createdCount: &result.createdSources
                )

                // Создаём транзакцию
                let tx = Transaction(
                    typeRaw: typeRaw,
                    amountCents: amountCents,
                    currency: currency,
                    date: date,
                    category: category,
                    source: (typeRaw == "income") ? source : nil,
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
        }

        // Один save на всё — быстрее и надёжнее
        try modelContext.save()
        return result
    }

    // MARK: - Helpers

    private static func getOrCreateCategory(
        modelContext: ModelContext,
        cache: inout [String: Category],
        name: String,
        kindRaw: String,
        createdCount: inout Int
    ) throws -> Category {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "CSVImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing category name"])
        }

        let key = trimmed.lowercased()
        if let existing = cache[key] { return existing }

        // order: ставим в конец
        let all = try modelContext.fetch(FetchDescriptor<Category>())
        let nextOrder = (all.map(\.order).max() ?? 0) + 1

        let new = Category(name: trimmed, kindRaw: kindRaw, icon: nil, order: nextOrder)
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

    /// Простейший split на строки (подходит для нашего экспортируемого CSV)
    private static func splitCSVRows(_ content: String) -> [String] {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    /// Парсер одной CSV строки: поддерживает кавычки и удвоенные кавычки.
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)

        var i = 0
        while i < chars.count {
            let c = chars[i]

            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    // "" внутри кавычек -> "
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
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// "12.34" -> 1234 cents. Поддерживаем запятую как разделитель.
    private static func parseMoneyToCents(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let dec = Decimal(string: normalized) else { return nil }

        let cents = dec * 100
        return NSDecimalNumber(decimal: cents).rounding(accordingToBehavior: nil).intValue
    }

    private static func makeLineError(_ lineIndex: Int, _ message: String) -> NSError {
        NSError(domain: "CSVImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Line \(lineIndex + 1): \(message)"])
    }
}
