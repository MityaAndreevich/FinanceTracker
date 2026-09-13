# COVERAGE MATRIX — which money-touching surfaces have zero tests

**Derived 2026-09-12 at HEAD `537e220`.** Status lives in `outputs/STATE.md`; defects live in
`outputs/DEFECT_REGISTER.md`. This file answers one question and stops.

---

## 0. THE HEADLINE OUTPUT

**This file's output is not "here is our coverage." It is: WHICH MONEY-TOUCHING SURFACES HAVE ZERO
TESTS.**

That list is §2. It is short, it is ranked, and it is the thing that would have caught PDF export in
July. **Partial coverage is deliberately not graded** — §4 lists the partials in one line each and
that is all the effort they get until the zeros are closed.

### The three to fix first

| | surface | why it is first |
|---|---|---|
| **1** | **`TSVExportService`** — the premium "Excel export" | **Zero tests, zero references, in either target.** A whole-ledger export, shipped, **paid**, with its own number-formatting path that differs from the CSV one. **This is the same shape as the July PDF escape, and it is still open.** |
| **2** | **The Horizon aggregation chain** | A **year** of income and expense, and the one test that touches it asserts only that two fixtures agree with each other. No absolute value is ever checked. |
| **3** | **`CSVExportService.makeCSVFromV1Store`** | The **only** way out for a user stranded on the migration floor — a live field bug (`DEFECT_REGISTER.md` D3). Its UI test asserts that an error label did *not* appear, and never reads the file. |

---

## 1. THE METHOD, AND ITS BLIND SPOT — read this before trusting a row

### What was done

Production surfaces under `FinanceTracker/`, `BudgetCrabShared/` and `BudgetCrabWidget/` were
enumerated by reading, and each money-touching one was traced to a test **by opening the test and
confirming it calls the production symbol.**

### The rule that governed it

> **A test named `FooTests` is not evidence that `Foo` is covered.**

Four categories of false coverage were found by applying it. They are in §3, and they are the most
useful part of this document.

### THE BLIND SPOT, stated here rather than discovered later

**A matrix built by reading is an ENUMERATION, and enumeration is the method with the worst record in
this project.** It was wrong **four times in one day** on 2026-09-02 —
`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:150–163` — twice by grep, once by inspection, once by
mis-classification, and *"the fourth item found was on the screen we thought we had finished
enumerating."* Errors 3 and 4 were made by two people independently. **A fifth attempt at enumeration
was not going to be the right one.**

This document is a fifth attempt at enumeration.

**A live instance, produced while building this file.** Checking whether `TSVExportService` has tests,
`grep -rn -i "tsv" FinanceTrackerTests/` returned **two hits**. Both are false positives — the letters
fall inside ordinary test names:

```
testAccep TSV alid…      →  func testAcceptsValidGroupAndRoundsDecimal()
testImpor TSV alid…      →  func testImportCSV_ImportsValidRowAndCreates…()
```

A reader who trusted the count would have recorded TSV export as *covered by two tests*. It has
**none**. **The grep was wrong in the one direction that makes a gap invisible, on the highest-ranked
row in this file.**

### So what is this document worth, and what closes the gap

It is worth its **zeros** and its **false-coverage findings**, because both were established by
opening files rather than by matching names. It is *not* worth its silences: **a surface absent from
this file has not been cleared — it has not been looked at.**

The instrument that does not have this blind spot is a **journey test**: seed the store a real user
has, walk the path, assert the positive. `PoisonedAmountLaunchTests` found two sites no enumeration
had listed, *"and then found `ScopedTransactionList.dayHeader` on the way to the list — a site nobody
had listed, on the destination rather than the launch path"*
(`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:172`). **Closing a §2 zero with a unit test is worth less than
closing it with a journey.**

---

## 2. THE ZEROS — ranked by how much money the surface touches

`money` = what it does with an amount. Rank 1 touches the most.

| # | surface | production | what it does with money | tests | verdict |
|---|---|---|---|---|---|
| **1** | **`TSVExportService.makeTSV`** — the premium Excel export | `Services/TSVExportService.swift:18`; formatting at `:88`; wired at `Views/Settings/DataSettingsView.swift:144` (month, free) and `:150` `gate(.exportExcelAll)` (all-time, **paid**) | Fetches **every transaction**, converts `amountCents` to a decimal string, writes the user's whole ledger to a file | **ZERO.** No reference in `FinanceTrackerTests/` or `FinanceTrackerUITests/`. Re-verified today; the two grep hits are the false positives in §1 | **UNCOVERED** |
| **2** | **Horizon aggregation chain** (12-month income/expense/net) | `Services/LedgerAggregator.swift:111` `horizonSeries(now:calendar:)` → `Shared/AnalyticsSeries.swift:77` `horizon(…)` → `AnalyticsView.swift:253–258` | Accumulates a **year** of `amountCents` into per-month income and expense buckets | **ZERO on the values.** `grep -rn horizonSeries FinanceTrackerTests/ FinanceTrackerUITests/` → **0 hits** (verified today). `AnalyticsSeries.horizon` is called once, at `SplitCanaryTests.swift:406–410`, asserting only `#expect(horizonA == horizonB)` | **UNCOVERED** — see §3.3 |
| **3** | **`CSVExportService.makeCSVFromV1Store`** — the migration floor's escape hatch | `Services/CSVExportService.swift:100`; called from `Views/Launch/LaunchGateView.swift:220, 417, 434` | The **only** data-out route for a user stranded by `DEFECT_REGISTER.md` D3. Reads `amountCents`/`taxCents` from the frozen V1 schema | **ZERO.** `grep -rn makeCSVFromV1Store FinanceTrackerTests/ FinanceTrackerUITests/` → **0 hits** (verified today). The nearest test asserts an error label is absent — see §3.5 | **UNCOVERED** |
| **4** | **`CSVImportActor` orchestration** — batched saves, `PartialImportFailure`, `@ModelActor` affinity | `Services/CSVImportActor.swift:34, 41–46, 80`; run by `DataSettingsView.swift:281, 340` | Decides **how many rows actually landed** and what the user is told when an import stops mid-file | **ZERO.** Only mention in either target is a comment at `SaveFailureReachabilityProbe.swift:151`. `PartialImportFailure` is thrown only at `CSVImportActor.swift:45` and constructed in **no test** | **UNCOVERED** (orchestration). **Row-level parsing IS covered** — see §3.1, which corrects a claim this project has been carrying |
| **5** | **`AnalyticsSeries` — `Int` overflow** | `Shared/AnalyticsSeries.swift:31, 49, 51–53, 92, 94` — plain `+` on `Int`, so it **traps** | Sums the ledger; traps the process on an unrepresentable amount | **ZERO.** `ImportOverflowChainTests` walks the reachable poisoned-store chain and asserts `MonthTotals` (`:170`), `categorySpendBuckets` (`:182`) and `SafeToSpend` (`:211`) all return nil — **and never touches `AnalyticsSeries`**, though the Analytics tab is reachable from the same store | **UNCOVERED.** Same item as `DEFECT_REGISTER.md` D5. **Every peer aggregator was hardened and this one was not** — `MonthTotals.swift:56, 67`, `CategoryLimitPolicy.swift:88`, `SafeToSpend.swift:113, 119`, `DailyAllowance.swift:77`, `AmountParsing.swift:113, 115` all use `addingReportingOverflow` |
| **6** | **`DailyAllowance.compute`** — the Dashboard Velocity hero | `Shared/DailyAllowance.swift:43`; division `:62`; forecast `:77–79`; `percentUsed` `:69` | `perDayCents`, `forecastCents`, `percentUsed`, `onPaceToStayUnder` | **Effectively zero.** The entire coverage is one `XCTAssertNil` at `DonutSectorInsetTests.swift:302`, against the early-return guard at `:49`. **No test ever computes a non-nil `Snapshot`** — and `:71–76` documents a crash this code already caused | **UNCOVERED** — see §3.6 |
| **7** | **Widget snapshot persistence** | `Services/NetSnapshotBuilder.swift:30` `updateSnapshot(…)` (what `DashboardView.swift:406` calls) → `BudgetCrabShared/NetSnapshot.swift:116, 122` `load()`/`save()` via App Group `UserDefaults` | Carries the money the Home Screen shows across the process boundary | **ZERO** on `updateSnapshot`, `save()` and `load()`. `NetSnapshotBuilder.build` **is** well covered (`NetSnapshotBuilderTests.swift:267–399`) | **UNCOVERED (the persistence hop).** A Codable or App-Group failure shows stale money on the Home Screen with nothing to catch it |
| **8** | **`CategoryDetailView.totalCents`** — the category-detail header | `Views/Analytics/CategoryDetailView.swift:63`; rendered `:74` via `Money.format` | The header total its own rows must sum to | **ZERO.** `CategoryScopedRowShareTests` exists **for this invariant** — its header states *"its rows add up to its header"* — and pins the rows (`:97–154`) and `CategoryAttribution.shares` (`:174`), but **never computes the header**. It is a `private var` on a `View`, so it is unreachable as written | **UNCOVERED** — see §3.4 |
| **9** | **`DaySpendingSheet.netCents`** | `Views/Analytics/DaySpendingSheet.swift:43` — `filtered.reduce(0) { $0 + $1.signedAmountCents }` | Sums one day's net, plus per-category slices | **ZERO on values.** Appears in `ChartDegenerateFrameTests` and `CyrillicQuickAddChartCrashTests` — both crash/geometry tests, neither asserts a number | **UNCOVERED** |
| **10** | **`DashboardView.donutSlices` "Other" fold** | `Views/DashboardView.swift:218–241`; tail sum `:229` | Folds the category tail into one "Other" amount | **ZERO.** The **equivalent** Analytics-side fold is thoroughly tested (`AnalyticsBreakdownBucketTests.swift:52, 73, 80` pin `Other == Σ(tail)`). The Dashboard copy has a different cap (6 vs 5) and a different sentinel (`"__other"`) and has none | **UNCOVERED.** Two folds, one tested |
| **11** | **`MonthDetailSheet`** | `Views/Analytics/MonthDetailSheet.swift:42–46`; renders `month.netCents` (`AnalyticsHorizonView.swift:44`) | Displays a month's net | **ZERO** references in either target. Its input is row 2's untested chain, so it compounds | **UNCOVERED** |

---

## 3. FALSE COVERAGE — tests that look like coverage and are not

**This is the most reusable part of the document.** Each was found by opening the test; each would
have read as covered off a grep or a name.

### 3.1 "CSV import has nine test files" — half false, and the half matters for triage

`CSVImportActor` is what `DataSettingsView.swift:281, 340` runs. `CSVImportService.importMappedCSV` /
`.importCSV` is the duplicate the app does **not** run, and nine test files sit on it.

**Correction to how this has been stated in this project, and it changes the fix.** The actor does
**not** duplicate the parse logic — it calls `CSVImportService.prepare` (`CSVImportActor.swift:52`),
`processRow` (`:67`) and `processMappedRow` (`:126`). **So row-level amount parsing genuinely IS
covered by those nine files.** What has zero coverage is only what the actor adds and nothing else
runs: the `batchSize = 100` batched saves (`:34`, `:80`), the `committed` snapshot and
`PartialImportFailure` throw (`:41–46`), and the `@ModelActor` thread-affinity contract (`:10–15`).

**Consequence:** do not rewrite the nine files. **Write tests for the actor's orchestration.** That
is a smaller job than "import is untested" implies, and a different one.

### 3.2 "`AnalyticsHorizonView` has four test files" — false for the money

`ChartDegenerateDomainTests.swift:98`, `ChartDegenerateFrameTests.swift:101`,
`ChartVisualSmokeTests.swift:102` and `ChartRenderRegressionTests.swift:231` all construct
`AnalyticsHorizonView.MonthlyTotal(…)` **as a literal, inside the test.** Production never does —
it builds it at `AnalyticsView.swift:257–259` from `LedgerAggregator.horizonSeries`.

**Four test files reference the type while bypassing every line that computes the numbers.** They
test that the chart does not crash and are correctly named for that. The risk is reading
*"AnalyticsHorizonView: 4 test files"* off a grep.

### 3.3 `SplitCanaryTests` covers `AnalyticsSeries.horizon` — false

`SplitCanaryTests.swift:406–411` calls it twice and asserts only `#expect(horizonA == horizonB)`.
**Two fixtures computed by the same function agree even when the function is wrong.** A bug that
swaps income and expense, drops a boundary month, or mis-buckets by timezone passes both.

What makes this easy to miss: **eleven lines earlier the same test does it right** —
`:399–401` asserts `#expect(pulseB.spentCents == b.expectedMonthExpenseCents)`, an absolute value.
Pulse got the value check; Horizon got the equality check.

### 3.4 `CategoryScopedRowShareTests` covers the category total — half false

The file's own header states the invariant: *"its rows add up to its header."* It pins the rows
(`:97, 106, 113, 133, 154`) and the attribution primitive (`:62, 174`). **It never computes the
header** (`CategoryDetailView.swift:63`). **The invariant the file is named for is half-asserted.**

### 3.5 `PreV1UpgradeFlowTests` covers the floor export — false

`PreV1UpgradeFlowTests.swift:79–84`, in
`test_floorScreen_warnsAboutDeletionAndExportsAnyway`, asserts
`XCTAssertFalse(failureLine.waitForExistence(timeout: 12))` — that an **error banner did not
appear**. It never opens the file, never counts rows, never checks an amount.

**Under this project's own "reports success while doing nothing" rule, an absent-error assertion on
an untested path is not coverage of that path.** It is the vacuous-pass shape
(`DEFECT_REGISTER.md` D29, D30) wearing a UI test's clothes — and it guards the escape hatch for the
one field bug users are hitting right now.

### 3.6 `DonutSectorInsetTests` covers `DailyAllowance` — false

One `XCTAssertNil` at `:302`, against the `monthlyBudgetCents > 0` guard. The file is about donut
sector geometry; the `DailyAllowance` line is incidental to it.

---

## 4. PARTIAL — listed, not graded

**Deliberately not worked.** Per the brief: rank the zeros and stop. These are recorded so nobody
re-derives them, in one line each.

| surface | what is covered | what is not |
|---|---|---|
| `CapGate.attempt` (`Purchases/CapGate.swift:27`) | The decision function `AccessLogic.canAdd` (`AccessManagerTests.swift:322–344`) and the flow (`MonetizationGateFlowTests`) | The `refreshFromStoreKit()` retry at `:35–40` — the stale-cache recovery the premium-gate trial blocker was about |
| Zero-decimal currencies (JPY, KRW) | `SupportedCurrency.swift:16, 18` ships both | `Money.format` (`Money.swift:16`) unconditionally divides by 100. `PDFExportLayoutTests.swift:149–150` documents the consequence **in a comment**; `MoneyTests`/`MoneyCompactTests` contain no JPY or KRW case. **UNSURE**, not uncovered — no test pins the round-trip |

---

## 5. VERIFIED COVERED — opened the tests, confirmed real calls

Recorded so the next pass does not re-check them. **PDF export leads the list deliberately**: it is
the July escape, and it is now the best-covered surface in the app.

| surface | production | test evidence |
|---|---|---|
| **PDF export** | `Services/PDFExportService.swift:242` | **Genuinely closed.** `PDFExportRenderTests.swift:183, 632` call the real `makeMonthlyReportPDF`; `:661–672` **rasterizes the PDF and reads ink-box extents** against `tableLeft`/`tableRight`; `:893–925` drives the widest storable amount. `PDFExportLayoutTests.swift:102` asks `tableLayout` rather than transcribing widths. `FrozenArtifactLanguageTests.swift:206` covers the localized render |
| CSV export | `Services/CSVExportService.swift:72` | `CSVExportServiceTests.swift:32, 59, 92`; round-trip `CSVRoundTripTests.swift:59, 93`; splits `SplitCanaryTests.swift:507` |
| CSV import, **row level** | `CSVImportService.swift:323, 668` | Nine files — `CSVImportServiceTests.swift:37`, `CSVMappedImportTests.swift:52`, `CSVImportDedupTests.swift:44`, … (see §3.1) |
| `Money` | `Shared/Money.swift:16–103` | Every public function: `format` ×12, `parseCents` ×9, `formatCompact` ×8, `formatSigned` ×3, `sanitizeInput` ×2, `plainDecimalString` ×1 |
| `AmountParsing` | `Shared/AmountParsing.swift:44, 144` | `parseCents` ×19, `hasConsistentSeparators` ×10; `AmountParsingTests.swift` |
| `SafeToSpend` | `Shared/SafeToSpend.swift:57, 61, 96, 132` | All four entry points — `SafeToSpendTests.swift:34, 64, 93, 107, 122, 131, 139` |
| `CategoryLimitPolicy` | `Shared/CategoryLimitPolicy.swift:30, 57, 72` | All three — `CategoryLimitPolicyTests.swift:34–40`, plus `spentByCategory` ×4 |
| `MonthTotals` | `Shared/MonthTotals.swift:32, 38, 50` | `ImportOverflowChainTests.swift:170, 174, 182, 228–230`; `SplitCanaryTests.swift:287–292` |
| `CategoryAttribution` (splits) | `Shared/CategoryAttribution.swift:54, 119, 145, 157, 164` | `SplitCanaryTests`, `CategoryScopedRowShareTests.swift:62, 174`, `SearchAttributionCanaryTests` |
| `PaceMetric` | `Shared/PaceMetric.swift` | `PaceMetricTests.swift:19, 26, 33`; `SplitCanaryTests.swift:372, 378` |
| Analytics category buckets | `Views/Analytics/AnalyticsBreakdownView.swift:86, 134, 409` | `AnalyticsBreakdownBucketTests.swift:35, 58–65, 79–80, 111` |
| `AnalyticsSeries.pulse` (values) | `Shared/AnalyticsSeries.swift:37` | `SplitCanaryTests.swift:398–403` — absolute `spentCents`/`earnedCents` |
| `NetSnapshotBuilder.build` | `Services/NetSnapshotBuilder.swift` | `NetSnapshotBuilderTests.swift:267, 289, 308, 328, 348, 365, 385, 399` |
| Recurrence / auto-post | `Services/RecurrenceService.swift` | `dueRecurring` ×19, `confirm` ×5, `applyRecurrenceSideEffects` ×4, `template` ×2, `skip`, `stopRecurrence` |
| Quick-add amount tokenizer | `Services/QuickAddParser.swift`, `NumberWordsParser.swift` | 8 files; `QuickAddAmountTokenizerTests`, `NumberWordsParserTests` (16 tests) |
| Migration / store-open, **amounts** | `Data/StorePreflightRepair.swift`, `StoreBackup.swift` | `MigrationRepairTests.swift:146–163, 207–240`; and specifically `PreV1StoreMigrationTests.swift:91` `test_preV1Store_preservesAmountsAndLinks` |
| Entitlement / paywall pricing | `PurchaseManager.evaluatePremium`, `AccessLogic.canAdd`, `PaywallPriceCopy` | `PurchaseEntitlementTests.swift:38–84`; `AccessManagerTests.swift:322–344`; `PaywallPriceCopyTests` (13); `PaywallComparisonTests` |
| Category budget limits | `Services/CategoryLimitService.swift:37, 59` | `SettingsSheetGuardedWriteTests.swift:121, 182, 197–198` |

**Checked and cleared as NOT money-touching** (so their thin coverage is not a gap): `ShowSpendingIntent`
(`:23–34`, sets navigation flags only), `VoiceInputService` (produces a transcript; **zero**
`amount`/`cents` references — money enters at `QuickAddParser`), `AddTransactionSaveService` (zero
`amountCents` references; the cap guard lives at `AddTransactionView.swift:498–505`),
`UsageSummaryBuilder`, `SourceCreateService`, `TransactionDeleteService`, `CategorySuggestionService`,
`MerchantLearningService`.

---

## 6. NOTE FOR WHOEVER RUNS THE FULL SUITE NEXT

**The next full run is expected to exit 5 and print the observed count. That is not a failure.**

`scripts/run-tests.sh:192` sets `EXPECTED_TOTAL_RUN=1113`, **deliberately one low.** 1114 is the
arithmetic answer, and the constant exists to refuse an arithmetic answer — per
`project_full_suite_oom_on_this_mac`, it is never to be set by arithmetic; the next full run prints
the observed number and that number is what goes in. **Exit 5 is the guard working.** Read the count,
set the constant to it, move on.

Two separate things that can also make a run look wrong, neither of them a real failure:

- **Exit 4 = a truncated run.** The `VoiceInputService` abort (`DEFECT_REGISTER.md` D1) can take the
  whole swift-testing phase with it — 44 suites, 415 `@Test` functions — and report a plausible
  number. `run-tests.sh` now exits 4 rather than letting that pass
  (`DEFECT_VOICE_INPUT_DEINIT_ABORT.md:196`).
- **Never pipe `run-tests.sh`.** A pipe replaces its exit code with the tail's, which discards every
  guard above.

**Scope note:** `FinanceTrackerTests/` holds **125** `.swift` files, not 120 — several are fixtures
and helpers rather than test classes (`RecurrenceTwinFixture.swift`, `RenderPixels.swift`,
`SaveFailureReachabilityProbe.swift`). `FinanceTrackerUITests/` holds 18. **A file count is not a
test count and neither is evidence of coverage** — which is the whole argument of this document.
