//
//  TipLibrary.swift
//  FinanceTracker
//
//  The active locale's tips merged over the base (`en`) tips.
//
//  Two rules are load-bearing, both because translations lag behind English:
//
//  1. `canonicalCount` is the *base* count, never the active locale's. If a
//     lagging locale cycled through its own shorter array, it would show a
//     different tip than every other locale on the same day — and the social
//     calendar, derived from the same index, would desynchronize.
//  2. Fallback is *per field*, so an untranslated `strategy` doesn't discard an
//     already-translated `term`.
//

import Foundation

struct TipLibrary: Sendable {
    private let base: [DailyTip]
    private let localized: [DailyTip]

    init(base: [DailyTip], localized: [DailyTip]) {
        self.base = base
        self.localized = localized
    }

    /// The number of tips the rotation cycles through. Always the base count.
    var canonicalCount: Int { base.count }

    var isEmpty: Bool { base.isEmpty }

    /// Every tip, localized. Backs the hub's browsable list.
    var allTips: [DailyTip] { base.indices.compactMap { tip(at: $0) } }

    /// Tips matching `query` across term, explanation, and strategy. An empty or
    /// whitespace-only query matches everything.
    ///
    /// Searches the *localized* text, not the base text: a Spanish user typing a
    /// Spanish word must find the tip even though the canonical content is English.
    func search(_ query: String) -> [DailyTip] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allTips }
        return allTips.filter { tip in
            tip.term.localizedCaseInsensitiveContains(trimmed)
                || tip.explanation.localizedCaseInsensitiveContains(trimmed)
                || tip.strategy.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// The tip at `index`, with per-field fallback to the base locale.
    func tip(at index: Int) -> DailyTip? {
        guard base.indices.contains(index) else { return nil }
        let baseTip = base[index]

        // The locale file is trusted at this index only when it has an entry there
        // AND that entry is the same tip. A mismatched id means the files drifted
        // out of sync, so the entry is a translation of some *other* tip and none
        // of its fields belong here.
        guard localized.indices.contains(index),
              localized[index].id == baseTip.id
        else { return baseTip }

        let translated = localized[index]
        return DailyTip(
            id: baseTip.id,
            term: preferred(translated.term, base: baseTip.term),
            explanation: preferred(translated.explanation, base: baseTip.explanation),
            strategy: preferred(translated.strategy, base: baseTip.strategy),
            category: baseTip.category
        )
    }

    private func preferred(_ translated: String, base: String) -> String {
        translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? base
            : translated
    }
}

// MARK: - Loading

extension TipLibrary {

    /// The library for the active in-app language.
    ///
    /// Reads through `LocalizedBundle.shared.bundle`, **not** `Bundle.main`: the
    /// in-app language override swizzles `Bundle.main` to intercept
    /// `localizedString(forKey:)` only. Resource-URL lookup is untouched, so
    /// `Bundle.main.url(forResource:)` would silently serve the *launch* language
    /// and ignore the user's pick.
    static func loadFromBundle() -> TipLibrary {
        TipLibrary(
            base: decodeTips(from: baseBundle),
            localized: decodeTips(from: LocalizedBundle.shared.bundle)
        )
    }

    /// The `en` bundle — the canonical content, and the fallback for every field a
    /// locale hasn't translated yet.
    private static var baseBundle: Bundle {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// A missing, empty, or malformed file yields an empty array: the hub shows its
    /// empty state, no tip card renders, and nothing crashes.
    static func decodeTips(from bundle: Bundle) -> [DailyTip] {
        guard let url = bundle.url(forResource: "tips", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return [] }
        return decodeTips(from: data)
    }

    static func decodeTips(from data: Data) -> [DailyTip] {
        (try? JSONDecoder().decode([DailyTip].self, from: data)) ?? []
    }
}

// MARK: - Cache

/// Decoded once per language.
///
/// SwiftUI re-initializes view structs constantly, so decoding inside a view's
/// `init` would put file I/O in the render path. A single static `let` would be
/// worse in a different way: it would freeze the *launch* language's tips even
/// after the user switches language in-app.
@MainActor
enum TipLibraryCache {
    private static var cache: [String: TipLibrary] = [:]

    static var current: TipLibrary {
        let key = LocalizedBundle.shared.languageCode ?? "system"
        if let cached = cache[key] { return cached }
        let library = TipLibrary.loadFromBundle()
        cache[key] = library
        return library
    }
}
