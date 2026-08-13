# AUDIT — tests whose subject is unreachable from the shipping app

**Date:** 2026-08-13 · **Mode:** read-only. **Nothing is fixed here.** The brief asked for the list.

> **The missing dimension.** `requestReplay()` had a **passing** test that exercised a path the app
> never takes. The 2026-08-08 discrimination sweep asked *"does this test discriminate a wrong
> implementation?"* — a test can pass that bar perfectly and still be worthless, because it never
> asked *"does any live call site reach the code this test covers?"*
>
> A test that discriminates correctly on unreachable code is not a weak test. **It is a test of
> something that is not the product**, and it reports green forever regardless of what ships.

---

## 0. Result

**6 real findings · 5 deliberate-and-correct · 1 false positive from my own method.**

The two CSV import findings are the serious ones: **the shipping column-mapped import path has no
test that reaches it**, on a feature marketed for Mint/YNAB/Monarch migration.

| Subject | Tests on it | Reachable from the app? | Severity |
|---|---|---|---|
| `CSVImportService.importMappedCSV` | 13 | **No** — app runs `CSVImportActor.importMappedData` | **HIGH** |
| `CSVImportService.importCSV` | (many) | **DEBUG-only** — sole caller is a QA seam | **HIGH** |
| `DuplicateReviewService.flaggedCount` | 6 | **No** — banner is driven by an `@Query` | MEDIUM |
| `DemoSeeder.hasDemoData` | 4 | **No** — `DashboardView` has its own private copy | MEDIUM |
| `TipLibrary.search` | 10 | **No** — hub uses `matching(_:in:)` | LOW–MED |
| `QuickAddSaveService.previewCategory` | 6 | **No** — already known dead | LOW |

---

## 1. HIGH — both CSV import entry points are untested *as shipped*

### 1.1 `importMappedCSV` — 13 tests, zero production callers

`CSVImportService.importMappedCSV` (`CSVImportService.swift:210`) has **no caller anywhere in the app,
widget, or shared target.** The shipping path is:

```
DataSettingsView.swift:316   CSVImportActor(...).importMappedData(data:mapping:)
CSVImportActor.swift:79–96   prepare → resolveAutoConventions → processMappedRow (per row)
```

`CSVImportActor.importMappedData` is a **second, independent orchestration** of the same job, written
to run on a `@ModelActor`. `importMappedCSV` is the synchronous original, kept alive only by its tests.

**What this does and does not mean — stated carefully, because the honest version is narrower than
the alarming one.** Both paths call the *same* `processMappedRow` (`:263`), so per-row column mapping,
date/amount convention resolution and row-failure classification **are** genuinely covered.

What is **not** covered on the shipping path is everything around the row: the iteration order, the
dedup/`seenUUIDs` seeding, the error aggregation, the preamble handling, and the progress callback.
Those exist twice, and the tests only ever run the copy the app doesn't use. Any divergence between
the two orchestrations is invisible to the suite by construction.

**This is the `requestReplay` shape exactly**, but on a shipped Tier-2 feature rather than a removed
one.

### 1.2 `importCSV` — reachable, but only from DEBUG code

**My own sweep did not flag this, and that is the point.** `CSVImportService.importCSV` (`:82`) *has*
production references, so a "zero production callers" rule passes it. Its only callers are:

```
DuplicateReviewDebugSeed.swift:47,48   — a DEBUG-only QA seam
```

The shipping plain-CSV path is `CSVImportActor.importData` (`DataSettingsView.swift:282`).

So `importCSV` is reachable **only from code that never ships to a user**. For the purpose this
dimension exists to serve, that is the same defect as zero callers — and it is strictly harder to
find. **The reachability question is not "is it called?" but "is it called on a path a user's build
can execute?"** Any future automation of this sweep must treat `#if DEBUG` callers as non-callers.

---

## 2. MEDIUM

### 2.1 `DuplicateReviewService.flaggedCount` — 6 tests, and its doc comment is false

`DuplicateReviewService.swift:58` is documented *"Drives the review banner. 0 → no banner."*
**Nothing calls it.** The banner is driven by a SwiftData `@Query`:

```
TransactionsView.swift:261   @Query(filter: #Predicate<Transaction> { $0.isPossibleDuplicate })
```

Two consequences, in order of importance:

1. **The predicates are not equivalent.** `flagged(in:)` sets `descriptor.includePendingChanges =
   true` (`:53`); the `@Query` does not. Unsaved in-flight changes are visible to the tested function
   and not to the shipped banner. **The one behavioural difference between them is the one thing the
   tests cannot see.**
2. This repeats a pattern already established in this project: the real behaviour lives in a
   framework-owned `@Query` that no unit test can reach, while a service function that mirrors it
   collects all the test coverage.

### 2.2 `DemoSeeder.hasDemoData` — 4 tests, and a duplicate implementation ships instead

`DemoSeeder.swift:170` is documented *"drives the Dashboard 'Demo data' banner"*. It does not.
`DashboardView` declares its **own private** `hasDemoData` (`:677`) and uses that at `:239`.

The two are written differently — `fetch` with `fetchLimit = 1` then `isEmpty == false`, versus
`fetchCount(...) > 0`. They should agree, and probably do. But the tested one is not the shipped one,
and its doc comment asserts a connection that does not exist in the code.

---

## 3. LOW–MEDIUM

### 3.1 `TipLibrary.search` — 10 tests, self-declared as test-only

`TipLibrary.swift:77` is honest about itself: *"Retained for callers/tests that want the unscoped
behaviour; the hub uses `matching(_:in:)` over its revealed set."*

Listed anyway, for two reasons. First, **10 assertions** is a lot of green attached to something the
product does not run. Second, the scoping difference is not cosmetic — searching `allTips` instead of
the revealed set is precisely the bug the per-user `TipCollection` rework existed to prevent (a fresh
install seeing the whole back-catalogue). A well-tested unscoped search sitting next to the scoped one
is a loaded footgun for the next caller, and `matching(_:in:)` is the function that needs the coverage.

### 3.2 `QuickAddSaveService.previewCategory` — 6 tests, already known dead

Confirmed dead at HEAD. `QuickEntryView.swift:105` records that the "+" sheet *previously* used it.
Already recorded in prior notes; included so this list is complete rather than novel.

---

## 4. Correctly unreachable — NOT findings

Listed explicitly so a future sweep does not "fix" them.

**`LocalizationProbe.{stringLocalized, nsLocalizedString, stringLocalizedExplicitBundle,
bundleMainLookup}`** (`LocalizedBundle.swift:128–140`) — unreachable from the app **on purpose, and
correctly so.** These exist inside the app module precisely because `String(localized:)` resolves
`#bundle` to the *calling* module: a test calling it directly measures the test bundle, which ships no
`.lproj`, and would report the premise broken when it is not. This is the rare case where a
production-module symbol that only tests call is the right design. The doc comment already explains
it.

**`FeatureUsageSignals.resetAll`** (`:62`) — self-documented *"Test/debug seam only."* Correct: the
app must never clear "ever used" flags, which is the entire point of the instrument.

**`ProactiveAlertRefresher.drain`** (`:90`) — self-documented *"(tests)"*. A legitimate affordance for
awaiting a coalesced async pass; there is no way to test coalescing without one.

---

## 5. Method, and what it misses

**How the list was built.** Every `func` declared under `FinanceTracker/`, `BudgetCrabShared/`,
`BudgetCrabWidget/`; production references counted excluding the declaration itself; test references
counted across both test targets; candidates = zero production references **and** at least one test
reference. Every candidate was then hand-verified with a looser pattern.

**Known blind spots — stated so this document's coverage is not overclaimed:**

- **DEBUG-only callers count as callers.** §1.2 was found by hand, not by the sweep. This is the
  largest gap and it hides the second-worst finding in the list.
- **Trailing-closure calls were missed.** `SaveActionGate.submit` was a false positive: my pattern
  required `submit(`, and all five real call sites are `saveGate.submit { … }`
  (`DashboardView:555,578`, `AddTransactionView:544`, `EditTransactionView:571`,
  `QuickEntryView:1012`). Hand-verification caught it; an unverified run of this script would have
  reported a live double-submit guard as dead code.
- **Only `func` was swept.** Types, computed properties, enum cases and `static let` tables were not.
- **Protocol/dynamic dispatch is invisible** to a textual sweep, as are `@objc`, selectors, key paths
  and anything reached through SwiftUI's `body`.
- **The converse question was not asked** and is probably the more valuable sweep: *shipping paths
  with no test at all.* This audit finds tests pointing at nothing; it cannot find code nothing points
  at. `CSVImportActor` is the worked example — it is what actually runs, and it surfaced here only as
  the thing the tests were missing.
