# Learn & Tips hub — design

**Version:** v1.0.2
**Date:** 2026-07-14
**Status:** approved, ready for implementation planning

## Goal

Ship the *mechanism* for daily financial education: a deterministic tip-of-the-day
card on the Dashboard, and a "Learn & Tips" hub in Settings holding the full tip
library plus the existing help articles.

The feature is **free** — no `AccessManager` or `isPremium` check anywhere. Daily
education is a retention driver, not a willingness-to-pay driver.

The 365-item content library is **not** part of this work. It is authored
separately and lands as a data file with no code change. This spec ships
placeholder tips so the mechanism, rotation, search, and tests are all real and
verifiable on device.

## Non-goals

- Authoring financial content. Placeholders only.
- Notifications. That is the separate proactive-alerts feature.
- Any change to monetization, sync, or data migration.
- Seasonal / calendar-aligned tip targeting. See "Known limits".

## Sequencing

Build the mechanism now. The real content — and final confirmation of the surface
(card vs. hub-only vs. adding a notification) — are pending a NotebookLM
validation pass (Finance Domain / UX / Psychology / ASO) running before the
content is written.

The card + Settings hub is a safe default that forecloses nothing: if the research
argues for a notification surface, that is purely additive, and notifications are
being built in the alerts feature regardless.

## Corrections to the originating brief

Three assumptions in the brief do not match the codebase. They are load-bearing.

1. **There is no TipKit in this project.** The brief says "TipKit stays the
   primary contextual layer." The contextual layer is in fact a custom one:
   `CoachmarkOverlay`, `InlineHintBubble`, and `OnboardingCoordinator` under
   `Views/Onboarding/`. Nothing to preserve, and no reason to add the framework.

2. **The annotated help screens already exist.** `Views/Settings/HelpView.swift`
   is a complete help hub: eight articles (Quick Add, voice entry, categories,
   analytics, widget, Siri, privacy, language change) across three sections, plus
   support-contact rows, all localized. Item 3 of the brief is therefore a
   *re-parenting* job, not new construction.

3. **`Bundle.main` does not respect the in-app language.** The app switches
   language by swizzling `Bundle.main`'s class (`Shared/LocalizedBundle.swift`).
   That override intercepts `localizedString(forKey:)` **only** — it does not
   intercept resource-URL lookup. A `tips.json` loaded via
   `Bundle.main.url(forResource:)` would silently resolve to the *launch*
   language and ignore the user's in-app pick. Tip loading must go through
   `LocalizedBundle.shared.bundle`.

## Architecture

### Content storage: one `tips.json` per `.lproj`

Content lives in `FinanceTracker/<locale>.lproj/tips.json` for all five shipping
locales (`en`, `ru`, `es`, `pt-BR`, `uk`). UI chrome stays in `Localizable.strings`.

Rejected alternative: putting tips in `Localizable.strings`. 365 items × 3 fields
is ~1,095 new keys per locale on top of the current 652, which would swamp the
`LocaleCompletenessTests` baseline with content churn and force a code-adjacent
change for every content edit. It also destroys the "write once, use twice" goal —
`.strings` is not clean data that ContentStudio can consume for the social
calendar, but a JSON array is.

Keeping chrome and content in separate files puts them on separate clocks: the
content team ships a new tip file without a code change or a strings-parity failure.

**The locale files must be parallel.** Identical count, identical order; `item[N]`
in every locale is the translation of the same tip, and carries the same `id`.

### Canonical count

**Rotation uses the base (`en`) file's count — never the active locale's.**

If rotation used `tips.count` of the active locale, a locale whose translation lags
(fewer items) would show a *different tip on the same day* than other locales, and
the promise that the social calendar is derivable from one file would break.

### Per-field base-locale fallback

Translations will lag: `en` complete, others partial. `tip(at:)` returns the
active-locale item, falling back to the base item **per field** when:

- the active-locale array is shorter than the index,
- the `id` at that index disagrees with the base file's `id` (files out of sync),
- or a field is empty/blank.

A partial translation therefore degrades to English one field at a time rather
than failing or showing a blank card.

### Components

**`Models/DailyTip.swift`**

```swift
struct DailyTip: Codable, Identifiable, Sendable {
    let id: String
    let term: String
    let explanation: String   // plain language
    let strategy: String      // one actionable line
    let category: String?     // optional
}
```

**`Services/TipLibrary.swift`** — loading and fallback.

- Decodes the active locale's `tips.json` (via `LocalizedBundle.shared.bundle`)
  and the base `en` array.
- Exposes `canonicalCount` (the base array's count).
- `tip(at index: Int) -> DailyTip?` applies the per-field fallback above.
- Missing file, empty array, or malformed JSON → empty library. No crash.
- Loaded once and cached.

**`Services/TipRotation.swift`** — pure math, no I/O, so it is trivially testable.

- `dayIndex(for date: Date, in timeZone: TimeZone) -> Int` — whole days from the
  epoch to `startOfDay(date)` in the given zone.
- `tipIndex(dayIndex: Int, canonicalCount: Int) -> Int?` —
  `((day % count) + count) % count`, guarding negatives; `nil` when count is zero.

**The epoch is `2026-01-01`.** It is an arbitrary but *fixed* constant, and it is
part of the contract with ContentStudio: changing it reshuffles every user's
sequence and desynchronizes the social calendar. Dates before it produce a
negative day index, which is why `tipIndex` guards negatives rather than assuming
non-negative input.

The app passes `.current` (local-midnight rollover). The social-calendar
derivation passes the pinned reference zone (UTC).

**`Views/Components/TipOfTheDayCard.swift`** — term, explanation, strategy, a
dismiss control, and a "Learn more →" affordance that pushes the hub. Uses the
existing `DesignSystem` / `Color.bc*` tokens. Respects Reduce Motion. Never blocks
the core flow.

**`Views/Settings/LearnAndTipsView.swift`** — replaces the Settings "Help" row.
Contains, in order: the tip-of-the-day header, the searchable tip library, then the
existing eight help articles and the contact rows.

`HelpArticle` and `HelpArticleView` are reused **untouched**, so every existing
`help.*` string key survives and nothing needs re-translating. Only `HelpView`'s
`List` sections are extracted so the hub can host them.

`.searchable` is scoped to the tip library; the help sections hide while a query is
active.

### Dashboard placement — one teaching card at a time

`DashboardView` already renders a `Day0EducationalCard` for users with fewer than
10 transactions **and** under 14 days since first launch (`hasUnlockedInsights`).
Adding the tip card naively would stack two teaching cards on a new user's first
screen.

`insightSection` is already exclusive (empty-state **or** Day-0). The tip card
becomes its **third exclusive branch**: it renders only once the user has
transactions and `hasUnlockedInsights` is true.

This is correct progressive disclosure, and it matches the audiences: the Day-0
card is onboarding for the brand-new user; the daily tip is habit reinforcement for
the established user — exactly the audience the retention rationale targets.

### Dismissal

`@AppStorage("tipDismissedDayIndex")` stores the day index the user dismissed. The
card renders unless `dismissedDayIndex == todayIndex`.

"Persists for the day" is therefore automatic, and tomorrow resets itself — no
cleanup job, no timer.

## Known limits

**No seasonal alignment.** `daysSinceEpoch % count` has no fixed relationship to
the calendar: a year is not `count` days, epoch-days do not reset on 1 January, and
leap years drift the mapping annually. "Tax tips every April" will **not** hold, and
must not be advertised. This is acceptable for v1 because the content is evergreen
(definitions + strategies).

*Future option, not a current property:* if true seasonal targeting is ever wanted,
map by day-of-year (1–365) instead of epoch-modulo.

**Pinned reference timezone does not eliminate dateline skew.** Pinning UTC makes
ContentStudio's derivation deterministic and documented, which is worth doing. It
does **not** eliminate ±1-day skew for dateline-edge users, because the app
deliberately rolls over at *local* midnight. Both cannot hold at once. Pinning
removes ambiguity from the derivation; the residual skew for a user in UTC+14 is
the accepted cost of local rollover. Documented as a known limit, not solved.

**Mid-cycle library growth remaps the sequence.** Growing the library (5
placeholders → 365 real tips) changes the modulo and jumps the sequence. Fine
pre-launch; must not be done post-launch.

## Testing

- **Rotation determinism** — same date + same count → same index, always.
- **No repeat until exhausted** — a full cycle of `count` days visits every index
  exactly once.
- **Guards** — negative day index safe; `canonicalCount == 0` → `nil`.
- **Locale parity** — all five `tips.json` files have identical count, identical
  ids, identical order.
- **Per-field fallback** — a partial locale falls back to base per field.
- **Empty / malformed** — missing file, `[]`, and corrupt JSON each yield an empty
  library, the hub's empty state, no tip card, and no crash.
- **Dismissal** — persists for the day; clears the next day (drive by injecting the
  day index).
- **Search** — the hub's tip search filters correctly.
- **Chrome parity** — five locales; bump the `LocaleCompletenessTests` English
  baseline (currently **652**).
- **Truncation** — longest locale does not truncate.

## Files

**New**

- `FinanceTracker/Models/DailyTip.swift`
- `FinanceTracker/Services/TipLibrary.swift`
- `FinanceTracker/Services/TipRotation.swift`
- `FinanceTracker/Views/Components/TipOfTheDayCard.swift`
- `FinanceTracker/Views/Settings/LearnAndTipsView.swift`
- `FinanceTracker/{en,ru,es,pt-BR,uk}.lproj/tips.json` (placeholders)
- `FinanceTrackerTests/TipLibraryTests.swift`
- `FinanceTrackerTests/TipRotationTests.swift`

**Modified**

- `FinanceTracker/Views/Settings/SettingsView.swift` — Help row → Learn & Tips
- `FinanceTracker/Views/DashboardView.swift` — tip card as third exclusive branch
- `FinanceTracker/Views/Settings/HelpView.swift` — sections extracted for reuse
- `FinanceTracker/{en,ru,es,pt-BR,uk}.lproj/Localizable.strings` — chrome keys
- `FinanceTrackerTests/LocaleCompletenessTests.swift` — baseline bump

## Device verification

Tip of the day shows and rotates; Learn hub lists tips and help articles; search
works; everything free; Dark + Light.
