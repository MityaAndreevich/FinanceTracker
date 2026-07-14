# Learn & Tips Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the mechanism for daily financial education — a deterministic tip-of-the-day card on the Dashboard and a "Learn & Tips" hub in Settings — with placeholder content that the real 365-item library replaces with zero code changes.

**Architecture:** Content is data, not code: one `tips.json` per `.lproj`, all five parallel. Pure-math rotation (`TipRotation`) and pure-merge loading (`TipLibrary`) are separated from all I/O and SwiftUI, so both are unit-testable without a bundle or a simulator. The Dashboard card is the third exclusive branch of the existing `insightSection`, so a user never sees two teaching cards at once.

**Tech Stack:** SwiftUI, SwiftData (untouched here), Swift Testing (`import Testing`) for new pure-logic tests, XCTest for the existing `LocaleCompletenessTests`.

**Spec:** `docs/superpowers/specs/2026-07-14-learn-and-tips-hub-design.md` (commit `9027ef5`). Read it first.

## Global Constraints

- **Free feature.** No `AccessManager`, no `isPremium`, no paywall check anywhere in this work.
- **Five locales:** `en`, `ru`, `es`, `pt-BR`, `uk`. All UI chrome localized; no hardcoded English in views.
- **No new dependencies.** No third-party HTTP/DB/formatter libraries.
- **The epoch is `2026-01-01`.** A contract constant shared with ContentStudio. Do not change it.
- **Canonical count is the base (`en`) file's count.** Never the active locale's count.
- **Load tips via `LocalizedBundle.shared.bundle`, never `Bundle.main`.** The in-app language override swizzles `Bundle.main` to intercept `localizedString(forKey:)` *only*; resource-URL lookup is untouched, so `Bundle.main.url(forResource:)` silently serves the **launch** language.
- **No `pbxproj` edits.** The `FinanceTracker` target is a `PBXFileSystemSynchronizedRootGroup` — new files under `FinanceTracker/` (including `.lproj/tips.json`) are picked up automatically. The variant group `AAAA010000000000000000A1` belongs to **BudgetCrabWidget**; do not touch it.
- **Do not author financial content.** Placeholders only.
- Commit after each task with a conventional prefix. Build before every commit.

**Build command** (used at the end of every task):

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

**Test command:**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

`-parallel-testing-enabled NO` is required in this repo — parallel test workers corrupt the shared SwiftData store.

---

### Task 1: TipRotation (pure math)

The rotation is deliberately free of I/O so it can be tested exhaustively. Nothing here touches SwiftUI, `Bundle`, or `Calendar.current`'s ambient timezone.

**Files:**
- Create: `FinanceTracker/Services/TipRotation.swift`
- Test: `FinanceTrackerTests/TipRotationTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `TipRotation.epoch: DateComponents` (2026-01-01)
  - `TipRotation.referenceTimeZone: TimeZone` (UTC)
  - `TipRotation.dayIndex(for: Date, in: TimeZone) -> Int`
  - `TipRotation.tipIndex(dayIndex: Int, canonicalCount: Int) -> Int?`

- [ ] **Step 1: Write the failing tests**

Create `FinanceTrackerTests/TipRotationTests.swift`:

```swift
//
//  TipRotationTests.swift
//  FinanceTrackerTests
//
//  The rotation is a contract with ContentStudio (it derives the social calendar
//  from the same index), so determinism is a correctness property, not a nicety.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipRotationTests {

    private func utc(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        ))!
    }

    private let utcZone = TimeZone(identifier: "UTC")!

    // MARK: - dayIndex

    @Test func epochIsDayZero() {
        #expect(TipRotation.dayIndex(for: utc(2026, 1, 1), in: utcZone) == 0)
    }

    @Test func dayIndexCountsWholeDaysFromEpoch() {
        #expect(TipRotation.dayIndex(for: utc(2026, 1, 2), in: utcZone) == 1)
        #expect(TipRotation.dayIndex(for: utc(2026, 2, 1), in: utcZone) == 31)
    }

    @Test func datesBeforeEpochAreNegative() {
        #expect(TipRotation.dayIndex(for: utc(2025, 12, 31), in: utcZone) == -1)
    }

    @Test func dayIndexIgnoresTimeOfDay() {
        // Any instant within the same local day maps to the same index — the tip
        // must not change at noon.
        let earlyDay = TipRotation.dayIndex(for: utc(2026, 3, 5, hour: 0), in: utcZone)
        let lateDay = TipRotation.dayIndex(for: utc(2026, 3, 5, hour: 23), in: utcZone)
        #expect(earlyDay == lateDay)
    }

    @Test func rollsOverAtLocalMidnightNotUTC() {
        // 2026-03-05 23:30 UTC is already 2026-03-06 in UTC+2, so a user there is
        // one day ahead. This is the deliberate local-midnight rollover.
        let instant = utc(2026, 3, 5, hour: 23)
        let inUTC = TipRotation.dayIndex(for: instant, in: utcZone)
        let inPlusTwo = TipRotation.dayIndex(for: instant, in: TimeZone(secondsFromGMT: 2 * 3600)!)
        #expect(inPlusTwo == inUTC + 1)
    }

    // MARK: - tipIndex

    @Test func tipIndexIsDeterministic() {
        // Same day + same count → same index, always.
        #expect(TipRotation.tipIndex(dayIndex: 42, canonicalCount: 5)
                == TipRotation.tipIndex(dayIndex: 42, canonicalCount: 5))
    }

    @Test func fullCycleVisitsEveryTipExactlyOnceBeforeRepeating() {
        let count = 7
        let cycle = (0..<count).compactMap {
            TipRotation.tipIndex(dayIndex: $0, canonicalCount: count)
        }
        #expect(Set(cycle).count == count)          // no repeats within a cycle
        #expect(Set(cycle) == Set(0..<count))       // every tip is used
        // The day after a full cycle wraps back to the start.
        #expect(TipRotation.tipIndex(dayIndex: count, canonicalCount: count) == 0)
    }

    @Test func negativeDayIndexStaysInRange() {
        // Swift's % yields negative results for negative operands; a raw modulo
        // would index out of bounds for a user whose clock predates the epoch.
        for day in -10 ... -1 {
            let index = TipRotation.tipIndex(dayIndex: day, canonicalCount: 5)
            #expect(index != nil)
            #expect((0..<5).contains(index!))
        }
        #expect(TipRotation.tipIndex(dayIndex: -1, canonicalCount: 5) == 4)
    }

    @Test func emptyLibraryYieldsNoIndex() {
        #expect(TipRotation.tipIndex(dayIndex: 0, canonicalCount: 0) == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

Expected: compile failure — `cannot find 'TipRotation' in scope`.

- [ ] **Step 3: Write the implementation**

Create `FinanceTracker/Services/TipRotation.swift`:

```swift
//
//  TipRotation.swift
//  FinanceTracker
//
//  Which tip shows today. Pure math — no I/O, no Bundle, no ambient calendar —
//  so the whole contract is unit-testable.
//

import Foundation

enum TipRotation {

    /// Day 0 of the rotation. Arbitrary, but **fixed by contract**: ContentStudio
    /// derives the social calendar from this same index, so changing the epoch
    /// reshuffles every user's sequence and desynchronizes the calendar.
    static let epoch = DateComponents(year: 2026, month: 1, day: 1)

    /// The zone ContentStudio uses to derive "day N".
    ///
    /// The app itself passes `.current`, so the tip rolls over at the user's local
    /// midnight. That means a user near the dateline can sit ±1 day off the derived
    /// post — pinning this zone removes ambiguity from the derivation, it does not
    /// (and cannot) eliminate that skew. Accepted cost of local rollover.
    static let referenceTimeZone = TimeZone(identifier: "UTC")!

    /// Whole days from the epoch to `date`'s start-of-day in `timeZone`.
    /// Negative for dates before the epoch.
    static func dayIndex(for date: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let epochDate = calendar.date(from: epoch) else { return 0 }
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: epochDate, to: startOfDay).day ?? 0
    }

    /// Index into the canonical tip array, or nil when the library is empty.
    ///
    /// The double-modulo is not superstition: Swift's `%` returns a negative result
    /// for a negative dividend, so a device clock set before the epoch would index
    /// out of bounds.
    static func tipIndex(dayIndex: Int, canonicalCount: Int) -> Int? {
        guard canonicalCount > 0 else { return nil }
        return ((dayIndex % canonicalCount) + canonicalCount) % canonicalCount
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Same command as Step 2. Expected: all `TipRotationTests` pass.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/Services/TipRotation.swift FinanceTrackerTests/TipRotationTests.swift
git commit -m "feat(learn): deterministic tip-of-the-day rotation

Pure math, no I/O, so the ContentStudio contract (fixed 2026-01-01 epoch,
same index everywhere) is exhaustively testable. Guards the negative day
index a pre-epoch device clock would produce."
```

---

### Task 2: DailyTip + TipLibrary (pure merge)

The merge rules — canonical base count, per-field fallback — are where a lagging translation either degrades gracefully or corrupts the rotation. Keep them free of `Bundle` so they can be tested directly.

**Files:**
- Create: `FinanceTracker/Models/DailyTip.swift`
- Create: `FinanceTracker/Services/TipLibrary.swift`
- Test: `FinanceTrackerTests/TipLibraryTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces:
  - `struct DailyTip: Codable, Identifiable, Sendable, Equatable` with `id, term, explanation, strategy: String` and `category: String?`
  - `struct TipLibrary`: `init(base: [DailyTip], localized: [DailyTip])`, `var canonicalCount: Int`, `var isEmpty: Bool`, `var allTips: [DailyTip]`, `func tip(at: Int) -> DailyTip?`, `func search(_ query: String) -> [DailyTip]`

- [ ] **Step 1: Write the failing tests**

Create `FinanceTrackerTests/TipLibraryTests.swift`:

```swift
//
//  TipLibraryTests.swift
//  FinanceTrackerTests
//
//  Translations lag: `en` is complete, other locales are partial. These tests pin
//  the two rules that keep a lagging locale from corrupting the rotation — the
//  canonical count comes from the base file, and fallback happens per field.
//

import Testing
@testable import FinanceTracker

struct TipLibraryTests {

    private func tip(
        _ id: String,
        term: String = "term",
        explanation: String = "explanation",
        strategy: String = "strategy"
    ) -> DailyTip {
        DailyTip(id: id, term: term, explanation: explanation,
                 strategy: strategy, category: "sample")
    }

    // MARK: - Canonical count

    @Test func canonicalCountComesFromBaseNotLocale() {
        // A locale with 1 of 3 tips translated must still cycle through 3, or it
        // would show a different tip than every other locale on the same day.
        let library = TipLibrary(
            base: [tip("a"), tip("b"), tip("c")],
            localized: [tip("a", term: "término")]
        )
        #expect(library.canonicalCount == 3)
    }

    @Test func aLocaleWithExtraTipsStillUsesTheBaseCount() {
        let library = TipLibrary(
            base: [tip("a")],
            localized: [tip("a"), tip("b"), tip("c")]
        )
        #expect(library.canonicalCount == 1)
        #expect(library.allTips.count == 1)
    }

    // MARK: - Per-field fallback

    @Test func translatedTipIsUsedWhenPresent() {
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund")],
            localized: [tip("a", term: "Fondo de reserva")]
        )
        #expect(library.tip(at: 0)?.term == "Fondo de reserva")
    }

    @Test func missingLocaleEntryFallsBackToBase() {
        let library = TipLibrary(
            base: [tip("a"), tip("b", term: "Base B")],
            localized: [tip("a")]           // index 1 not translated yet
        )
        #expect(library.tip(at: 1)?.term == "Base B")
    }

    @Test func blankFieldFallsBackPerFieldNotWholeTip() {
        // The point of per-field fallback: an untranslated `strategy` must not
        // discard a perfectly good translated `term`.
        let library = TipLibrary(
            base: [tip("a", term: "Base term", strategy: "Base strategy")],
            localized: [tip("a", term: "Translated term", strategy: "   ")]
        )
        let result = library.tip(at: 0)
        #expect(result?.term == "Translated term")
        #expect(result?.strategy == "Base strategy")
    }

    @Test func idMismatchDistrustsTheWholeLocaleEntry() {
        // Files drifted out of sync: the entry at this index is a translation of
        // some *other* tip, so none of its fields can be trusted here.
        let library = TipLibrary(
            base: [tip("a", term: "Base A")],
            localized: [tip("z", term: "Translation of Z")]
        )
        #expect(library.tip(at: 0)?.term == "Base A")
        #expect(library.tip(at: 0)?.id == "a")
    }

    // MARK: - Empty and out-of-range

    @Test func emptyBaseIsAnEmptyLibrary() {
        let library = TipLibrary(base: [], localized: [])
        #expect(library.isEmpty)
        #expect(library.canonicalCount == 0)
        #expect(library.tip(at: 0) == nil)
        #expect(library.allTips.isEmpty)
    }

    @Test func outOfRangeIndexIsNil() {
        let library = TipLibrary(base: [tip("a")], localized: [tip("a")])
        #expect(library.tip(at: 5) == nil)
        #expect(library.tip(at: -1) == nil)
    }

    // MARK: - Search

    @Test func searchMatchesTheTerm() {
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund"), tip("b", term: "Lifestyle creep")],
            localized: []
        )
        #expect(library.search("sinking").map(\.id) == ["a"])
    }

    @Test func searchIsCaseAndDiacriticInsensitive() {
        let library = TipLibrary(base: [tip("a", term: "Presupuesto")], localized: [])
        #expect(library.search("PRESUPUESTO").count == 1)
        #expect(library.search("presupuesto").count == 1)
    }

    @Test func searchAlsoMatchesExplanationAndStrategy() {
        let library = TipLibrary(
            base: [tip("a", term: "Term", explanation: "about compounding", strategy: "move £20")],
            localized: []
        )
        #expect(library.search("compounding").count == 1)
        #expect(library.search("£20").count == 1)
    }

    @Test func searchSearchesTheLocalizedTextNotTheBaseText() {
        // A Spanish user searching a Spanish word must find the tip, even though the
        // base text is English.
        let library = TipLibrary(
            base: [tip("a", term: "Sinking fund")],
            localized: [tip("a", term: "Fondo de reserva")]
        )
        #expect(library.search("fondo").count == 1)
        #expect(library.search("sinking").isEmpty)
    }

    @Test func emptyQueryReturnsEverything() {
        let library = TipLibrary(base: [tip("a"), tip("b")], localized: [])
        #expect(library.search("").count == 2)
        #expect(library.search("   ").count == 2)
    }

    @Test func aQueryMatchingNothingReturnsNothing() {
        let library = TipLibrary(base: [tip("a", term: "Sinking fund")], localized: [])
        #expect(library.search("zzzz").isEmpty)
    }

    // MARK: - Decoding

    @Test func malformedJSONDecodesToEmptyRatherThanThrowing() {
        let data = Data("{ this is not valid json".utf8)
        #expect(TipLibrary.decodeTips(from: data).isEmpty)
    }

    @Test func validJSONDecodes() {
        let json = """
        [{"id":"a","term":"T","explanation":"E","strategy":"S","category":"sample"}]
        """
        let tips = TipLibrary.decodeTips(from: Data(json.utf8))
        #expect(tips.count == 1)
        #expect(tips.first?.id == "a")
    }

    @Test func categoryIsOptional() {
        let json = """
        [{"id":"a","term":"T","explanation":"E","strategy":"S"}]
        """
        let tips = TipLibrary.decodeTips(from: Data(json.utf8))
        #expect(tips.first?.category == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Test command from Global Constraints. Expected: compile failure — `cannot find 'TipLibrary' in scope`.

- [ ] **Step 3: Write DailyTip**

Create `FinanceTracker/Models/DailyTip.swift`:

```swift
//
//  DailyTip.swift
//  FinanceTracker
//
//  One educational tip: a term, a plain-language explanation, and one actionable
//  strategy. Content is authored outside the app and ships as `tips.json` per
//  locale, so the 365-item library lands without a code change.
//

import Foundation

struct DailyTip: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let term: String
    let explanation: String
    let strategy: String
    let category: String?
}
```

- [ ] **Step 4: Write TipLibrary**

Create `FinanceTracker/Services/TipLibrary.swift`:

```swift
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Test command from Global Constraints. Expected: all `TipLibraryTests` pass. (`TipLibrary` currently loads nothing from the bundle — the JSON files arrive in Task 3 — so the bundle-loading path is exercised there, not here.)

- [ ] **Step 6: Commit**

```bash
git add FinanceTracker/Models/DailyTip.swift FinanceTracker/Services/TipLibrary.swift \
        FinanceTrackerTests/TipLibraryTests.swift
git commit -m "feat(learn): tip content model with per-field base-locale fallback

Translations will lag English, so the rotation takes its count from the base
file and falls back field-by-field — an untranslated strategy must not discard
an already-translated term, and a short locale file must not shift which tip a
locale shows on a given day.

Loads through LocalizedBundle, not Bundle.main: the language override only
intercepts string lookup, so Bundle.main resource URLs serve the launch
language regardless of what the user picked."
```

---

### Task 3: Placeholder tips.json × 5 locales

Placeholder content only — the real 365-item library replaces these files with no code change. Each locale's text is prefixed with its code (`[RU]`, `[ES]`…) so that switching language on device *visibly* proves the correct file is being read; that is the whole point of shipping placeholders rather than an empty array.

**Files:**
- Create: `FinanceTracker/en.lproj/tips.json`
- Create: `FinanceTracker/ru.lproj/tips.json`
- Create: `FinanceTracker/es.lproj/tips.json`
- Create: `FinanceTracker/pt-BR.lproj/tips.json`
- Create: `FinanceTracker/uk.lproj/tips.json`
- Test: `FinanceTrackerTests/TipLibraryTests.swift` (append a parity suite)

**Interfaces:**
- Consumes: `DailyTip`, `TipLibrary.decodeTips(from:)` from Task 2.
- Produces: five parallel `tips.json` files; `TipLibrary.loadFromBundle()` now returns 5 tips.

No `pbxproj` edit — the synchronized root group picks these up.

- [ ] **Step 1: Write the failing parity test**

Append to `FinanceTrackerTests/TipLibraryTests.swift`:

```swift
// MARK: - Locale file parity

/// The locale files must stay *parallel*: same count, same ids, same order, so
/// that `item[N]` is the same tip in every language. If they drift, a locale
/// shows a different tip than everyone else on the same day and the per-index
/// fallback starts matching translations to the wrong tips.
struct TipContentParityTests {

    private let locales = ["en", "ru", "es", "pt-BR", "uk"]

    private func tips(for locale: String) -> [DailyTip] {
        guard let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return [] }
        return TipLibrary.decodeTips(from: bundle)
    }

    @Test func everyLocaleShipsATipsFile() {
        for locale in locales {
            #expect(!tips(for: locale).isEmpty, "\(locale).lproj/tips.json is missing or empty")
        }
    }

    @Test func everyLocaleHasTheSameIdsInTheSameOrder() {
        let baseIDs = tips(for: "en").map(\.id)
        #expect(!baseIDs.isEmpty)

        for locale in locales {
            #expect(tips(for: locale).map(\.id) == baseIDs,
                    "\(locale).lproj/tips.json is not parallel with en")
        }
    }

    @Test func noTipHasAnEmptyField() {
        for locale in locales {
            for tip in tips(for: locale) {
                #expect(!tip.term.trimmingCharacters(in: .whitespaces).isEmpty)
                #expect(!tip.explanation.trimmingCharacters(in: .whitespaces).isEmpty)
                #expect(!tip.strategy.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @Test func idsAreUnique() {
        let ids = tips(for: "en").map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func loadedLibraryCyclesThroughEveryTip() {
        let library = TipLibrary.loadFromBundle()
        #expect(library.canonicalCount == tips(for: "en").count)

        let visited = (0..<library.canonicalCount).compactMap {
            TipRotation.tipIndex(dayIndex: $0, canonicalCount: library.canonicalCount)
        }
        #expect(Set(visited).count == library.canonicalCount)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Test command from Global Constraints. Expected: FAIL — `en.lproj/tips.json is missing or empty`.

- [ ] **Step 3: Create `FinanceTracker/en.lproj/tips.json`**

```json
[
  {
    "id": "placeholder-001",
    "term": "[EN] Sample term one",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-002",
    "term": "[EN] Sample term two",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-003",
    "term": "[EN] Sample term three",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-004",
    "term": "[EN] Sample term four",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-005",
    "term": "[EN] Sample term five",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  }
]
```

- [ ] **Step 4: Create the four other locale files**

Identical structure, identical `id`s, identical order. Only the language tag in `term` changes. Create `FinanceTracker/ru.lproj/tips.json`, `FinanceTracker/es.lproj/tips.json`, `FinanceTracker/pt-BR.lproj/tips.json`, `FinanceTracker/uk.lproj/tips.json`, replacing `[EN]` with `[RU]`, `[ES]`, `[PT-BR]`, `[UK]` respectively.

For example, `FinanceTracker/ru.lproj/tips.json`:

```json
[
  {
    "id": "placeholder-001",
    "term": "[RU] Sample term one",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-002",
    "term": "[RU] Sample term two",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-003",
    "term": "[RU] Sample term three",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-004",
    "term": "[RU] Sample term four",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  },
  {
    "id": "placeholder-005",
    "term": "[RU] Sample term five",
    "explanation": "Placeholder explanation — real content pending.",
    "strategy": "Placeholder strategy — real content pending.",
    "category": "sample"
  }
]
```

- [ ] **Step 5: Run the tests to verify they pass**

Test command from Global Constraints. Expected: `TipContentParityTests` all pass.

If `everyLocaleShipsATipsFile` still fails for a locale, the file did not make it into the app bundle. Confirm it is inside the `.lproj` folder next to that locale's `Localizable.strings` — a `tips.json` placed one level up will not be found.

- [ ] **Step 6: Commit**

```bash
git add FinanceTracker/*.lproj/tips.json FinanceTrackerTests/TipLibraryTests.swift
git commit -m "feat(learn): placeholder tip content for all five locales

Placeholders, not real tips — the 365-item library is authored separately and
drops into these files with no code change. Each locale's text carries its own
language tag so switching language on device visibly proves the right file is
being read.

The parity test is the guard that matters: the files must stay parallel (same
ids, same order), because fallback and rotation both address tips by index."
```

---

### Task 4: Localized UI chrome

Add the chrome keys before the views that consume them, so `LocaleCompletenessTests` never goes red mid-plan.

**Files:**
- Modify: `FinanceTracker/en.lproj/Localizable.strings`
- Modify: `FinanceTracker/ru.lproj/Localizable.strings`
- Modify: `FinanceTracker/es.lproj/Localizable.strings`
- Modify: `FinanceTracker/pt-BR.lproj/Localizable.strings`
- Modify: `FinanceTracker/uk.lproj/Localizable.strings`
- Modify: `FinanceTrackerTests/LocaleCompletenessTests.swift:159`

**Interfaces:**
- Produces these keys, consumed by Tasks 5 and 6:
  `settings.learn_tips`, `learn.tip_of_day`, `learn.all_tips`, `learn.search`,
  `learn.dismiss`, `learn.learn_more`, `learn.try_this`, `learn.empty.title`,
  `learn.empty.message`, `learn.no_results`

- [ ] **Step 1: Add the keys to `en.lproj/Localizable.strings`**

Append:

```
/* MARK: - Learn & Tips */
"settings.learn_tips" = "Learn & Tips";
"learn.tip_of_day" = "Tip of the day";
"learn.all_tips" = "All tips";
"learn.search" = "Search tips";
"learn.dismiss" = "Dismiss tip";
"learn.learn_more" = "Learn more";
"learn.try_this" = "Try this";
"learn.empty.title" = "No tips yet";
"learn.empty.message" = "Daily tips will appear here soon.";
"learn.no_results" = "No tips match your search.";
```

- [ ] **Step 2: Remove the now-orphaned `settings.help` key**

`settings.help` was the label of the Settings row that Task 6 replaces, and the title of the `HelpView` that Task 6 dissolves. Leaving it would be a dangling key. Delete the `"settings.help" = ...;` line from **all five** `Localizable.strings` files.

- [ ] **Step 3: Add the translated keys to the other four locales**

`ru.lproj/Localizable.strings`:

```
/* MARK: - Learn & Tips */
"settings.learn_tips" = "Обучение и советы";
"learn.tip_of_day" = "Совет дня";
"learn.all_tips" = "Все советы";
"learn.search" = "Поиск советов";
"learn.dismiss" = "Скрыть совет";
"learn.learn_more" = "Подробнее";
"learn.try_this" = "Попробуйте";
"learn.empty.title" = "Пока нет советов";
"learn.empty.message" = "Ежедневные советы скоро появятся здесь.";
"learn.no_results" = "Ничего не найдено.";
```

`es.lproj/Localizable.strings`:

```
/* MARK: - Learn & Tips */
"settings.learn_tips" = "Aprende y consejos";
"learn.tip_of_day" = "Consejo del día";
"learn.all_tips" = "Todos los consejos";
"learn.search" = "Buscar consejos";
"learn.dismiss" = "Descartar consejo";
"learn.learn_more" = "Saber más";
"learn.try_this" = "Prueba esto";
"learn.empty.title" = "Aún no hay consejos";
"learn.empty.message" = "Los consejos diarios aparecerán aquí pronto.";
"learn.no_results" = "Ningún consejo coincide con tu búsqueda.";
```

`pt-BR.lproj/Localizable.strings`:

```
/* MARK: - Learn & Tips */
"settings.learn_tips" = "Aprenda e dicas";
"learn.tip_of_day" = "Dica do dia";
"learn.all_tips" = "Todas as dicas";
"learn.search" = "Buscar dicas";
"learn.dismiss" = "Dispensar dica";
"learn.learn_more" = "Saiba mais";
"learn.try_this" = "Experimente";
"learn.empty.title" = "Ainda não há dicas";
"learn.empty.message" = "As dicas diárias aparecerão aqui em breve.";
"learn.no_results" = "Nenhuma dica corresponde à sua busca.";
```

`uk.lproj/Localizable.strings`:

```
/* MARK: - Learn & Tips */
"settings.learn_tips" = "Навчання та поради";
"learn.tip_of_day" = "Порада дня";
"learn.all_tips" = "Усі поради";
"learn.search" = "Пошук порад";
"learn.dismiss" = "Сховати пораду";
"learn.learn_more" = "Докладніше";
"learn.try_this" = "Спробуйте";
"learn.empty.title" = "Порад ще немає";
"learn.empty.message" = "Щоденні поради скоро з'являться тут.";
"learn.no_results" = "Нічого не знайдено.";
```

- [ ] **Step 4: Update the baseline in `LocaleCompletenessTests.swift:159`**

The English baseline was 652. This task adds 10 keys and removes 1, so it becomes **661**:

```swift
XCTAssertEqual(enKeys.count, 661, "English baseline changed; update the expected count.")
```

- [ ] **Step 5: Run the locale tests**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -parallel-testing-enabled NO test 2>&1 | grep -i "LocaleCompleteness\|failed\|passed" | head
```

Expected: `LocaleCompletenessTests` passes — every locale carries the same key set, count is 661.

If the assertion reports an actual count other than 661, do **not** just paste the actual number in. It means a key edit drifted — a key was added to one locale and missed in another, or `settings.help` was removed from only some files. Reconcile the five files first.

- [ ] **Step 6: Commit**

```bash
git add FinanceTracker/*.lproj/Localizable.strings FinanceTrackerTests/LocaleCompletenessTests.swift
git commit -m "i18n(learn): chrome strings for the Learn & Tips hub

Adds the hub's UI chrome in all five locales and retires settings.help, whose
row and view both dissolve into the hub. Content strings deliberately stay out
of here — tips live in tips.json so the content library can grow without
touching the strings files or this baseline."
```

---

### Task 5: TipOfTheDayCard + Dashboard integration

The card becomes the **third exclusive branch** of the existing `insightSection`. That is not an aesthetic choice: `DashboardView` already shows a `Day0EducationalCard` to users under 10 transactions and under 14 days old, and stacking two teaching cards on a new user's first screen is exactly the noise this feature must not add. One teaching card at a time.

**Files:**
- Create: `FinanceTracker/Views/Components/TipOfTheDayCard.swift`
- Modify: `FinanceTracker/Views/DashboardView.swift` (the `insightSection` at ~line 786, plus new state)
- Test: `FinanceTrackerTests/TipDismissalTests.swift`

**Interfaces:**
- Consumes: `DailyTip`, `TipLibraryCache.current`, `TipRotation.dayIndex(for:in:)`, `TipRotation.tipIndex(dayIndex:canonicalCount:)`.
- Produces: `TipOfTheDayCard(tip: DailyTip, onDismiss: () -> Void)`; the `@AppStorage("tipDismissedDayIndex")` convention.

- [ ] **Step 1: Write the failing dismissal test**

Dismissal is pure logic — "is today's index the one the user dismissed" — so it is tested without SwiftUI.

Create `FinanceTrackerTests/TipDismissalTests.swift`:

```swift
//
//  TipDismissalTests.swift
//  FinanceTrackerTests
//
//  Dismissal rides the day index rather than a timestamp + cleanup job: "dismissed
//  for today" is just `dismissedDayIndex == todayIndex`, so tomorrow resets itself.
//

import Testing
@testable import FinanceTracker

struct TipDismissalTests {

    @Test func aFreshInstallHasNothingDismissed() {
        // -1 is the sentinel: no real day index is negative for any post-epoch date.
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: -1, todayIndex: 0))
    }

    @Test func dismissingHidesTheCardForThatDay() {
        #expect(TipDismissal.isDismissed(dismissedDayIndex: 12, todayIndex: 12))
    }

    @Test func dismissalExpiresOnTheNextDay() {
        // The whole point: no timer, no cleanup — the index simply stops matching.
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: 12, todayIndex: 13))
    }

    @Test func aStaleDismissalFromLongAgoDoesNotHideToday() {
        #expect(!TipDismissal.isDismissed(dismissedDayIndex: 3, todayIndex: 400))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Test command from Global Constraints. Expected: `cannot find 'TipDismissal' in scope`.

- [ ] **Step 3: Add the TipDismissal helper**

Append to `FinanceTracker/Services/TipRotation.swift`:

```swift
/// Whether today's tip has been dismissed.
///
/// Stored as the *day index* that was dismissed, not a flag or a timestamp: the
/// card is hidden only while the stored index equals today's, so the dismissal
/// expires by itself at the next local midnight. No timer, no cleanup job.
enum TipDismissal {
    /// `@AppStorage` key. -1 means "nothing dismissed" — no post-epoch day is negative.
    static let storageKey = "tipDismissedDayIndex"
    static let none = -1

    static func isDismissed(dismissedDayIndex: Int, todayIndex: Int) -> Bool {
        dismissedDayIndex == todayIndex
    }
}
```

- [ ] **Step 4: Run to verify the tests pass**

Test command from Global Constraints. Expected: `TipDismissalTests` pass.

- [ ] **Step 5: Write TipOfTheDayCard**

Create `FinanceTracker/Views/Components/TipOfTheDayCard.swift`:

```swift
//
//  TipOfTheDayCard.swift
//  FinanceTracker
//
//  The daily educational tip on the Dashboard. Calm, dismissible, never blocking.
//  Free — no premium gate: education drives retention, not willingness to pay.
//

import SwiftUI

struct TipOfTheDayCard: View {
    let tip: DailyTip
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header

            Text(tip.term)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)

            Text(tip.explanation)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            strategy
        }
        .padding(Spacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(Color.bcSurface1)
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("learn.tip_of_day", systemImage: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bcAccent)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bcTextMuted)
                    // Padding, not a frame: keeps the glyph small while giving the
                    // button a comfortable tap target.
                    .padding(Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("learn.dismiss")
        }
    }

    private var strategy: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)

            Text(tip.strategy)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(Text("learn.try_this") + Text(verbatim: ": \(tip.strategy)"))
    }

    private func dismiss() {
        guard !reduceMotion else { return onDismiss() }
        withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
    }
}

#Preview {
    TipOfTheDayCard(
        tip: DailyTip(
            id: "preview",
            term: "Sinking fund",
            explanation: "Money set aside each month for a known future cost.",
            strategy: "Name one for your next car service.",
            category: "sample"
        ),
        onDismiss: {}
    )
    .padding()
    .background(Color.bcPage)
}
```

- [ ] **Step 6: Wire the card into DashboardView**

In `FinanceTracker/Views/DashboardView.swift`, add the state alongside the other `@AppStorage` properties near the top of the struct:

```swift
    @AppStorage(TipDismissal.storageKey) private var tipDismissedDayIndex: Int = TipDismissal.none
```

Then replace the existing `insightSection` (at ~line 786) with:

```swift
    // MARK: - Insight / Day-0 / Tip of the day

    /// Today's tip, or nil when the library is empty (no content shipped yet).
    private var todaysTip: DailyTip? {
        let library = TipLibraryCache.current
        guard let index = TipRotation.tipIndex(
            dayIndex: todayTipDayIndex,
            canonicalCount: library.canonicalCount
        ) else { return nil }
        return library.tip(at: index)
    }

    /// Local timezone, so the tip rolls over at the user's own midnight.
    private var todayTipDayIndex: Int {
        TipRotation.dayIndex(for: .now, in: .current)
    }

    /// Exactly one teaching card at a time. The Day-0 card is onboarding for a
    /// brand-new user; the daily tip is habit reinforcement for an established one.
    /// Stacking both on a first run would be pure noise, so they are exclusive
    /// branches of the same slot.
    @ViewBuilder
    private var insightSection: some View {
        if transactions.isEmpty {
            DashboardEmptyState(animateArrow: animateArrow)
                .padding(.horizontal, 16)
        } else if !hasUnlockedInsights {
            Day0EducationalCard(showAddTransaction: $showAddTransaction)
                .padding(.horizontal, 16)
        } else if let tip = todaysTip,
                  !TipDismissal.isDismissed(
                      dismissedDayIndex: tipDismissedDayIndex,
                      todayIndex: todayTipDayIndex
                  ) {
            TipOfTheDayCard(tip: tip) {
                tipDismissedDayIndex = todayTipDayIndex
            }
            .padding(.horizontal, 16)
        }
    }
```

- [ ] **Step 7: Build and run the full test suite**

Build command, then test command, both from Global Constraints. Expected: build succeeds, all tests pass.

- [ ] **Step 8: Commit**

```bash
git add FinanceTracker/Views/Components/TipOfTheDayCard.swift \
        FinanceTracker/Views/DashboardView.swift \
        FinanceTracker/Services/TipRotation.swift \
        FinanceTrackerTests/TipDismissalTests.swift
git commit -m "feat(learn): tip-of-the-day card on the Dashboard

Slots in as the third exclusive branch of insightSection, so it never stacks on
the Day-0 card: Day-0 teaches the brand-new user, the daily tip reinforces the
habit for an established one, and showing both at once would be noise on the
one screen that has to stay calm.

Dismissal stores the dismissed day index rather than a flag, so it expires at
the next local midnight without a timer or a cleanup pass."
```

---

### Task 6: LearnAndTipsView + Settings re-parenting

`HelpView` already contains the eight annotated help articles the brief asks for, fully translated. Dissolve the `HelpView` *container* into the new hub and reuse `HelpArticle` and `HelpArticleView` untouched — every existing `help.*` string key survives and nothing needs re-translating.

**Files:**
- Create: `FinanceTracker/Views/Settings/LearnAndTipsView.swift`
- Modify: `FinanceTracker/Views/Settings/HelpView.swift` (remove the `HelpView` struct; keep `HelpArticle` + `HelpArticleView`)
- Modify: `FinanceTracker/Views/Settings/SettingsView.swift:55-59` (the Help row)

**Interfaces:**
- Consumes: `TipLibraryCache.current`, `TipRotation`, `TipDismissal`, `DailyTip`, `HelpArticle`, `HelpArticleView`, and the chrome keys from Task 4.
- Produces: `LearnAndTipsView()`.

- [ ] **Step 1: Create LearnAndTipsView**

Create `FinanceTracker/Views/Settings/LearnAndTipsView.swift`:

```swift
//
//  LearnAndTipsView.swift
//  FinanceTracker
//
//  The Learn & Tips hub: today's tip, the browsable tip library, and the annotated
//  help articles — one destination, so there is no second place users go to "learn
//  things". Free; no premium gate.
//
//  The help sections and their articles are the ones that used to live in HelpView;
//  HelpArticle and HelpArticleView are reused as-is so every `help.*` translation
//  survives the move.
//

import SwiftUI
import UIKit

struct LearnAndTipsView: View {
    private let supportEmailAddress = "support@budgetcrab.app"
    private let supportEmail = URL(string: "mailto:support@budgetcrab.app?subject=Budget%20Crab%20Support")!
    private let onlineFAQ = URL(string: "https://budgetcrab.app/support.html")!

    @State private var searchText = ""
    @State private var showCopiedToast = false

    private var library: TipLibrary { TipLibraryCache.current }

    private var todaysTip: DailyTip? {
        guard let index = TipRotation.tipIndex(
            dayIndex: TipRotation.dayIndex(for: .now, in: .current),
            canonicalCount: library.canonicalCount
        ) else { return nil }
        return library.tip(at: index)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Filtering lives on `TipLibrary` so it is unit-tested rather than trapped in
    /// a view. An empty query returns everything.
    private var filteredTips: [DailyTip] { library.search(searchText) }

    var body: some View {
        List {
            if library.isEmpty {
                // No content shipped yet: say so plainly rather than showing an
                // empty section with a search bar over nothing.
                Section {
                    EmptyStateView(
                        systemImage: "lightbulb",
                        title: "learn.empty.title",
                        message: "learn.empty.message"
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                if !isSearching, let tip = todaysTip {
                    Section("learn.tip_of_day") {
                        NavigationLink {
                            TipDetailView(tip: tip)
                        } label: {
                            tipRow(tip)
                        }
                    }
                }

                Section("learn.all_tips") {
                    if filteredTips.isEmpty {
                        Text("learn.no_results")
                            .font(.bcCaption)
                            .foregroundStyle(Color.bcTextSecondary)
                    } else {
                        ForEach(filteredTips) { tip in
                            NavigationLink {
                                TipDetailView(tip: tip)
                            } label: {
                                tipRow(tip)
                            }
                        }
                    }
                }
            }

            // Search is scoped to the tip library, so the help sections would be
            // noise while a query is active.
            if !isSearching {
                helpSections
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: Text("learn.search"))
        .navigationTitle("settings.learn_tips")
        .navigationBarTitleDisplayMode(.inline)
        .alert("help.email_copied", isPresented: $showCopiedToast) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private func tipRow(_ tip: DailyTip) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(tip.term)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)
            Text(tip.explanation)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Help (moved from HelpView)

    @ViewBuilder
    private var helpSections: some View {
        Section("help.getting_started.title") {
            articleLink(.quickAdd, icon: "sparkles")
            articleLink(.voiceEntry, icon: "mic")
            articleLink(.categories, icon: "tag")
        }

        Section("help.advanced.title") {
            articleLink(.analytics, icon: "chart.pie")
            articleLink(.widget, icon: "rectangle.on.rectangle")
            articleLink(.siri, icon: "waveform")
        }

        Section("help.privacy.title") {
            articleLink(.privacy, icon: "lock.iphone")
            articleLink(.languageChange, icon: "globe")
        }

        Section("help.contact.title") {
            // Copy-to-clipboard works on any iPhone, even one with no Mail account
            // configured (Round 9 R3: mailto failed with "не удалось отправить" on
            // such devices). The mailto link is offered too for users who do have
            // Mail set up.
            Button {
                UIPasteboard.general.string = supportEmailAddress
                showCopiedToast = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                HStack {
                    Label("help.copy_email", systemImage: "doc.on.doc")
                    Spacer()
                    Text(verbatim: supportEmailAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Link(destination: supportEmail) {
                Label("help.open_in_mail", systemImage: "envelope.open")
            }

            Link(destination: onlineFAQ) {
                Label("help.online_faq", systemImage: "safari")
            }
        }
    }

    private func articleLink(_ article: HelpArticle, icon: String) -> some View {
        NavigationLink {
            HelpArticleView(article: article)
        } label: {
            Label(article.rowLabelKey, systemImage: icon)
        }
    }
}

// MARK: - Tip detail

struct TipDetailView: View {
    let tip: DailyTip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.compact) {
                Text(tip.term)
                    .font(.title2.bold())
                    .foregroundStyle(Color.bcTextPrimary)

                Text(tip.explanation)
                    .font(.bcBody)
                    .lineSpacing(4)
                    .foregroundStyle(Color.bcTextSecondary)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("learn.try_this")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bcAccent)
                    Text(tip.strategy)
                        .font(.bcBody)
                        .lineSpacing(4)
                        .foregroundStyle(Color.bcTextPrimary)
                }
                .padding(Spacing.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(Color.bcSurface1)
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Short articles must not rubber-band above the nav bar and "freeze"
        // overscrolled past the top (Round 9 R2).
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.bcPage.ignoresSafeArea())
        .navigationTitle(Text(verbatim: tip.term))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LearnAndTipsView() }
}
```

- [ ] **Step 2: Dissolve the HelpView container**

In `FinanceTracker/Views/Settings/HelpView.swift`, delete the entire `struct HelpView: View { ... }` (lines 12–82) and its `#Preview` at the bottom, along with the now-unused `supportEmailAddress` / `supportEmail` / `onlineFAQ` / `showCopiedToast` members that lived on it.

**Keep** `enum HelpArticle` and `struct HelpArticleView` exactly as they are — `LearnAndTipsView` uses both, and every `help.*` translation depends on them.

Update the file header comment to say the articles are now presented by `LearnAndTipsView`.

- [ ] **Step 3: Re-point the Settings row**

In `FinanceTracker/Views/Settings/SettingsView.swift`, replace lines 55–59:

```swift
                NavigationLink {
                    HelpView()
                } label: {
                    Label("settings.help", systemImage: "questionmark.circle")
                }
```

with:

```swift
                NavigationLink {
                    LearnAndTipsView()
                } label: {
                    Label("settings.learn_tips", systemImage: "lightbulb")
                }
```

- [ ] **Step 4: Build and run the full test suite**

Build command, then test command, both from Global Constraints. Expected: build succeeds (no references to `HelpView` remain), all tests pass.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/Views/Settings/LearnAndTipsView.swift \
        FinanceTracker/Views/Settings/HelpView.swift \
        FinanceTracker/Views/Settings/SettingsView.swift
git commit -m "feat(learn): Learn & Tips hub replaces the Settings Help row

The eight annotated help articles already existed; this dissolves their HelpView
container into the hub and reuses HelpArticle/HelpArticleView untouched, so every
help.* translation survives the move and users get one destination for learning
rather than two rows that both look like it.

Search is scoped to the tip library, so the help sections hide while a query is
active instead of sitting there unfiltered."
```

---

### Task 7: Device verification

Nothing here is a code change — it is the check that the feature is real on a device, which the test suite cannot do.

**Files:** none.

- [ ] **Step 1: Run the app and verify the tip card**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
```

Install and launch, then confirm:

- With **fewer than 10 transactions and under 14 days since first launch**: the Day-0 card shows and the tip card does **not**. Two teaching cards must never appear together.
- With **10+ transactions**: the tip card appears in that same slot.
- Dismissing the card hides it; force-quitting and relaunching keeps it hidden **for the same day**.
- The card is legible in **both Dark and Light** appearance.

- [ ] **Step 2: Verify the hub**

- Settings shows **Learn & Tips** (not "Help"), with a lightbulb icon.
- The hub lists today's tip, all five placeholder tips, and the eight help articles.
- Search filters the tips; the help sections hide while searching; a nonsense query shows the "no results" line.
- Tapping a tip opens its detail; tapping a help article still opens the article.
- Nothing anywhere is gated — no paywall, no lock icons.

- [ ] **Step 3: Verify locale-correct content loading**

Switch the in-app language (Settings → language) to Russian, Spanish, pt-BR, and Ukrainian in turn. Each time, the tip text must show that locale's tag — `[RU]`, `[ES]`, `[PT-BR]`, `[UK]`.

**This is the check that matters most.** If the tag stays `[EN]` after switching, the tips are being read from `Bundle.main` instead of `LocalizedBundle.shared.bundle`, and the content is silently serving the launch language. Chrome (section titles, the search prompt) must switch language too.

- [ ] **Step 4: Check the longest locale for truncation**

In Russian and Ukrainian — the longest chrome — confirm the card's term, explanation, and strategy wrap rather than truncate, and that the "Learn & Tips" row label fits.

- [ ] **Step 5: Push**

```bash
git push origin main
```

---

## Handoff note

The placeholder `tips.json` files are the seam. When the 365-item library lands:

1. Replace all five `FinanceTracker/*.lproj/tips.json` files. Keep them parallel — same ids, same order.
2. Run the test suite. `TipContentParityTests` fails loudly if the files drifted.
3. No code changes. No `pbxproj` changes.

`TipRotation.epoch` (2026-01-01) and `TipRotation.referenceTimeZone` (UTC) are the constants ContentStudio needs to derive the social calendar: the tip shown on day *N* is `tips[((N % count) + count) % count]`, where *N* is whole days from the epoch.

The final surface (card vs. hub-only vs. adding a notification) is still pending the NotebookLM validation pass. The card + hub built here forecloses nothing — a notification surface would be additive, and notifications are being built in the alerts feature anyway.
