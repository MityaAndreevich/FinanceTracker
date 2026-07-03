//
//  Category+Theme.swift
//  FinanceTracker
//
//  Single source of truth mapping each category to a distinct color + SF Symbol
//  for the redesigned data-viz UI (donut slices, transaction tiles). Palette from
//  outputs/DESIGN_DIRECTION_v2.md §1.
//
//  Keyed off the canonical category key (derived from `nameKey`, e.g.
//  "category.food_drink" -> "food_drink") so it survives localization. Seeded
//  categories get a curated color + filled symbol; user-defined categories get a
//  deterministic color (stable hash into the palette) and keep their chosen icon.
//
//  No data migration: this is a computed presentation layer over the existing
//  Category model.
//

import SwiftUI

extension Category {

    /// Canonical, locale-independent key for palette lookup. Strips the
    /// "category." prefix from `nameKey`; falls back to the folded legacy name.
    var themeKey: String {
        if let key = nameKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            if key.hasPrefix("category.") { return String(key.dropFirst("category.".count)) }
            return key
        }
        return name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "")
    }

    /// Distinct brand-legible color for this category (both light & dark themes).
    var themeColor: Color {
        if let mapped = CategoryTheme.map[themeKey] { return mapped.color }
        // User-defined / unknown: deterministic pick so a category keeps its
        // color across launches without needing a stored field.
        return CategoryTheme.fallbackPalette[CategoryTheme.stableIndex(themeKey, count: CategoryTheme.fallbackPalette.count)]
    }

    /// SF Symbol for this category. Seeded categories use the curated (filled)
    /// symbol; user-defined categories keep the icon they picked.
    var symbolName: String {
        if let mapped = CategoryTheme.map[themeKey] { return mapped.symbol }
        if let icon = icon?.trimmingCharacters(in: .whitespacesAndNewlines), !icon.isEmpty {
            return icon
        }
        return "tag.fill"
    }
}

/// Palette + symbol tables. Colors are fixed (not asset-backed) because they are
/// chosen to stay legible on both the #0F1420 dark page and #F6F7F5 light page.
enum CategoryTheme {

    struct Entry {
        let color: Color
        let symbol: String
    }

    static let map: [String: Entry] = [
        "food_drink":    Entry(color: rgb(0x1D, 0x9E, 0x75), symbol: "fork.knife"),
        "transport":     Entry(color: rgb(0x37, 0x8A, 0xDD), symbol: "car.fill"),
        "housing":       Entry(color: rgb(0x7F, 0x77, 0xDD), symbol: "house.fill"),
        "shopping":      Entry(color: rgb(0xD4, 0x53, 0x7E), symbol: "bag.fill"),
        "entertainment": Entry(color: rgb(0x3A, 0xA0, 0xC9), symbol: "film.fill"),
        "other":         Entry(color: rgb(0x7C, 0x86, 0x98), symbol: "questionmark"),
        "income":        Entry(color: rgb(0x3D, 0xDC, 0x97), symbol: "dollarsign.circle.fill"),
        "health":        Entry(color: rgb(0x63, 0x99, 0x22), symbol: "heart.fill"),
        "subscriptions": Entry(color: rgb(0x9B, 0x8C, 0xFF), symbol: "repeat"),
        "coffee":        Entry(color: rgb(0xEF, 0x9F, 0x27), symbol: "cup.and.saucer.fill"),
        "travel":        Entry(color: rgb(0x0E, 0xA5, 0xC4), symbol: "airplane"),
        "personal_care": Entry(color: rgb(0xD6, 0x7B, 0xA5), symbol: "scissors"),
        "utilities":     Entry(color: rgb(0xD8, 0x5A, 0x30), symbol: "bolt.fill"),
    ]

    /// Distinct hues for user-defined categories (subset of the curated palette).
    static let fallbackPalette: [Color] = [
        rgb(0x37, 0x8A, 0xDD), rgb(0x7F, 0x77, 0xDD), rgb(0xD4, 0x53, 0x7E),
        rgb(0x1D, 0x9E, 0x75), rgb(0xEF, 0x9F, 0x27), rgb(0x0E, 0xA5, 0xC4),
        rgb(0xD6, 0x7B, 0xA5), rgb(0x63, 0x99, 0x22), rgb(0x9B, 0x8C, 0xFF),
        rgb(0xD8, 0x5A, 0x30),
    ]

    /// Stable, launch-independent index from a string (FNV-1a → modulo).
    static func stableIndex(_ s: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 1469598103934665603
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return Int(hash % UInt64(count))
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
