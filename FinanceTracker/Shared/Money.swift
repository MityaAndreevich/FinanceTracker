//
//  Money.swift
//  FinanceTracker
//
//  Single source of truth for parsing, sanitizing and formatting money
//  values throughout the app. All amounts are stored as Int cents.
//

import Foundation

enum Money {

    // MARK: - Formatting

    /// Format an Int cents value as currency (e.g., `1234` -> "$12.34").
    static func format(cents: Int, currencyCode: String) -> String {
        let amount = Decimal(cents) / 100
        return format(amount: amount, currencyCode: currencyCode)
    }

    /// Format a Decimal amount as currency.
    static func format(amount: Decimal, currencyCode: String) -> String {
        let f = MoneyFormatterCache.shared.formatter(for: currencyCode)
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    /// Format a signed cents value with explicit `+`/`-` prefix.
    /// Useful for transaction rows so we don't rely on color alone (accessibility).
    static func formatSigned(cents: Int, isPositive: Bool, currencyCode: String) -> String {
        let body = format(cents: cents, currencyCode: currencyCode)
        // If the formatter already produced a leading sign, return as-is.
        if body.hasPrefix("-") || body.hasPrefix("+") { return body }
        return (isPositive ? "+" : "−") + body
    }

    // MARK: - Parsing

    /// Strict parser: returns nil for any non-numeric input.
    /// Accepts both "." and "," as decimal separator.
    static func parseCents(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        guard let decimal = Decimal(string: normalized) else { return nil }

        let centsDecimal = decimal * 100
        return NSDecimalNumber(decimal: centsDecimal)
            .rounding(accordingToBehavior: nil)
            .intValue
    }

    /// Sanitize raw text input from a money TextField:
    /// - replaces "," with "."
    /// - removes anything that isn't a digit or "."
    /// - keeps only one decimal separator
    /// - caps decimals at 2 places
    static func sanitizeInput(_ input: String) -> String {
        var s = input.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }

        if let firstDot = s.firstIndex(of: ".") {
            let afterFirst = s.index(after: firstDot)
            let prefix = s[..<afterFirst]
            let suffix = s[afterFirst...].replacingOccurrences(of: ".", with: "")
            s = String(prefix) + suffix
        }

        if let dot = s.firstIndex(of: ".") {
            let afterDot = s.index(after: dot)
            let decimals = s[afterDot...]
            if decimals.count > 2 {
                let end = s.index(afterDot, offsetBy: 2)
                s = String(s[..<end])
            }
        }

        return s
    }

    /// Format an Int cents value as a plain decimal string ("12.34"),
    /// without any currency symbol. Used to prefill TextFields when editing.
    static func plainDecimalString(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

// MARK: - Formatter cache

/// NumberFormatter is expensive to instantiate and is thread-safe for *reading*
/// once configured. We cache one per currency code.
final class MoneyFormatterCache: @unchecked Sendable {
    static let shared = MoneyFormatterCache()

    private var cache: [String: NumberFormatter] = [:]
    private let lock = NSLock()

    private init() {}

    func formatter(for currencyCode: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[currencyCode] { return cached }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.locale = .autoupdatingCurrent
        cache[currencyCode] = f
        return f
    }
}
