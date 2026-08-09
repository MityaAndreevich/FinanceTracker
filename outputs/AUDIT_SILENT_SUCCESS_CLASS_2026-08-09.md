# AUDIT — "reports success while doing nothing" as a CLASS

**Date:** 2026-08-09 · **Scope:** app + shared + widget targets, 109 unit-test files, 16 UI-test files.
**Method:** sweep first, report before fixing. Findings are stated with the evidence that produced them; where a mechanism is asserted, it was executed rather than read.

---

## 0. Result

Three known instances were named going in:

- `PlainTextEntryCoverageTests` resolving its source root from `#filePath`
- `--seed-large-dataset` throwing on every call, reported only to `print`
- `-only-testing` naming a file rather than its suites, returning two false GREENs

They are one class, and the class has **more members than the three**. The sweep found **2 more in (a)**, **11 in (b)** (3 of them wholly silent in Release), and **1 systemic instance in (c)** that is not a bug in any file but in how every test in this project is run.

**One correction to the prior audit:** `AUDIT_TEST_DISCRIMINATION_2026-08-08` §4 says `AccessManagerTests.swift` contains nine `@Suite`s. It contains **eight**. The point it was making — that none of them is named `AccessManagerTests` — is unaffected and correct.

**One finding produced by the sweep's own tooling, mid-sweep.** A grep for `print(` in production returned `0`, which would have been reported as "no print-only error paths anywhere." The working directory had drifted; the paths did not exist; `ugrep` wrote its warning to stderr and `wc -l` printed `0` to stdout. That is the class, live, inside the instrument written to find it — the same way `AUDIT_TEST_DISCRIMINATION` reproduced its own defect in §4. **A tool that reports "nothing found" must be able to distinguish that from "nothing looked at."** Every count in this document was re-run against absolute paths.

---

## 1. The class, defined

> A mechanism reports success on a path where it performed no work, and the successful-and-did-nothing outcome is **byte-identical** to the successful-and-did-everything outcome.

Three preconditions make an instance dangerous. All three hold in every finding below:

1. the no-op path is **reachable by ordinary means** (a rename, a moved file, a typo in a filter);
2. the report is **indistinguishable** from real success — not merely similar, identical;
3. something downstream **treats the report as evidence** — a release gate, an audit, a measurement.

Item 3 is what separates this from ordinary dead code. A vacuous test is not just untested code; it is a **claim of coverage** that a human then relies on.

---

## 2. (a) Tests whose precondition can silently no-op

Six test files derive a source root from `#filePath` and scan the tree. The dividing line is whether they assert the corpus is non-empty before asserting anything about its contents.

### 2.1 UNGUARDED — vacuous pass if the corpus is empty

**A1 · `PlainTextEntryCoverageTests` — 3 tests, and the skip that was supposed to catch this cannot fire.**

```swift
guard let walker = fm.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil) else {
    throw XCTSkip("app source tree not reachable from \(appSourceRoot.path)")
}
```

This was written as the guard. It is not one. Executed, not assumed:

```
enumerator(at: badPath) is nil?  ->  false
objects yielded               ->  0
```

`FileManager.enumerator(at:)` returns a **non-nil** enumerator for a path that does not exist, and it yields nothing. So the `XCTSkip` is unreachable, `swiftSources()` returns `[]`, all three tests loop zero times, and `XCTAssertTrue(offenders.isEmpty)` passes. It does not even skip — it **passes**. What it claims to guard: that every `TextField` in the app declares `.plainTextEntry()` (the autofill-suppression fix).

**A2 · `ReleaseDebugAffordanceTests.launchArgumentReadsAreDebugOnly` — 1 test.**

Loops over `annotatedSources()` and `#expect`s inside the loop, with no non-empty assertion. Empty corpus ⇒ vacuous pass. What it claims to guard is stated in its own name: *"Release ignores every launch argument — several of them wipe data."* This is the highest-consequence member of (a).

Its **sibling in the same file is guarded** — `debugSymbolReferencesAreWrapped` closes with `#expect(found.contains(symbol))` over every expected symbol, which fails loudly on an empty scan. So the fix is an asymmetry to remove, not a pattern to invent.

### 2.2 GUARDED — the patterns already in the repo

| File | The guard |
|---|---|
| `LocalizedCallSiteGuardTests` | `#expect(scannedFiles > 100, "only \(scannedFiles) .swift files scanned — the walk is broken")`, plus a directory-exists check |
| `ChartGuardsCoverageTests` | `#require(!patterns.isEmpty)` and `#require(!sources.isEmpty)`, each messaged "the scan itself broke" |
| `LocaleCompletenessTests` | `XCTAssertFalse(referenced.isEmpty, "Scanner found no keys — path wrong?")` ×2 |
| `ReleaseDebugAffordanceTests.debugSymbolReferencesAreWrapped` | `#expect(found.contains(symbol))` per expected symbol |
| `ImportDuplicateFlagTests` | reads its fixture with `try Data(contentsOf:)` — a missing file throws and fails the test |

`LocalizedCallSiteGuardTests` is the strongest of these and its header already names the failure mode in prose: *"a scanner that finds no files must fail."* **The knowledge exists in this repo. It just was not applied uniformly.**

### 2.3 Not findings

- `DeletedModelIdentifierTests` `.disabled(...)` — an explicit, reasoned disable with the reason recorded. Visible, not silent.
- `PaywallClarityRenderTests` `XCTSkipUnless` — a real skip that reports as a skip.
- UI tests: **zero** `if element.exists { … }` silent no-ops. The four `waitForExistence` results that are bound to a variable are all asserted after capturing diagnostics. This area is clean.

---

## 3. (b) Error paths whose only report is `print` or an uncaptured channel

36 `print(` sites in production. Most are **not** findings: they sit alongside a user-visible toast *and* `logSaveFailure` (which reaches the unified log and survives into Release). `DashboardView:556` and `:592` are the correct shape.

The findings are the sites where the print is the *only* report.

### 3.1 Wholly silent in Release — no user signal, no log

| # | Site | What vanishes |
|---|---|---|
| **B1** | `AddTransactionView.swift:736` | Account creation fails. No error shown, nothing logged. The user taps "create", and the UI does nothing at all. |
| **B2** | `PremiumSettingsView.swift:97` | Offer-code redemption fails. No feedback, no log. **This is a monetization path.** |
| **B3** | `SharedModelContainer.swift:333` | The legacy-store → App-Group **migration** fails. Invisible in Release. The retry-next-launch comment is correct, but a migration that fails every launch is also invisible every launch. |

### 3.2 User is told, but the cause is unrecoverable off-device

These show an alert or toast, so the user is not misled — but the `NSError` is `#if DEBUG` only, so a TestFlight or App Store report cannot be root-caused. This is exactly the gap `PersistenceLog` was created to close; it is used at 24 sites and missing at these.

`AddTransactionView:562` · `TransactionsView:213` · `DuplicateReviewView:184` · `AddCategorySheet:287` · `GeneralSettingView:499` (here the diagnostic *is* the `remaining` count, and it is DEBUG-only)

### 3.3 Debug seams — the same shape as the bug that already bit, in the siblings that were never fixed

`LargeDatasetDebugSeed` **was** fixed, and its comment states the principle exactly:

> `print` alone is not a channel: app stdout is not captured in xcodebuild logs, so a throw here was invisible to the very UI test that depends on this seam. It passed while measuring an empty ledger.

It now also emits `MainThreadStallMonitor.note(...)`, which a UI test can read. **Its siblings did not get the same treatment**, and they back real UI tests:

| Seam | Failure report | UI tests that depend on it |
|---|---|---|
| **B4** `AccountResetDebugSeam:59` | `print` only | `MonetizationGateFlowTests` |
| **B5** `DuplicateReviewDebugSeed:48` | `print` only | `DuplicateReviewFlowTests`, `BulkDeleteStallMeasurementTests` |
| **B6** `DemoSeeder:93`, `:243`, `:381`, `:414` | `print` only | — (also silently skips entries and splits) |
| **B7** `SeedService:29`, `:92`, `:214` | `print` only | — (`:214` is the category migration) |

B4 and B5 are the live risk: a seam that throws leaves the test running against an un-reset or unseeded store, and the test reports on whatever it found. That is precisely how `BulkDeleteStallMeasurementTests` "measured" for months without measuring.

**Not swept:** 81 `try?` sites in production. Each is a potential swallow, but `try?` is often correct and separating the two needs per-site judgement, not a grep. Called out so the coverage of this document is not overclaimed.

---

## 4. (c) Filters, predicates and guards that can match nothing

Inside test *code*, (c) collapses into (a) — the corpus scanners of §2 — and that is covered. The UI-test surface is clean.

The real instance of (c) is **not in a file. It is in how every test in this project is run.**

`xcodebuild -only-testing:X` prints `** TEST SUCCEEDED **` when `X` matches zero tests. There is no warning, no non-zero exit, and the result bundle simply contains no test nodes. A green run that ran nothing is byte-identical to a green run that ran everything.

Three things make this systemic rather than incidental here:

1. **Targeted runs are mandated.** `FABLE_TASK_BUILD_1_0_3.md`: *"Targeted `-only-testing:` runs, never suite-wide."* `DESIGN_1_0_3_MODELS_FABLE.md` restates it as policy from CLAUDE.md. So the hazardous path is the *default* path.
2. **Suite names do not follow file names.** `AccessManagerTests.swift` holds **8** `@Suite`s, none of them named `AccessManagerTests`. `-only-testing:FinanceTrackerTests/AccessManagerTests` therefore runs **zero** tests and reports success. This already produced two false GREENs (G5, G7).
3. **There is no wrapper.** No `Makefile`, no `scripts/*.sh`, no CI config runs tests. Every invocation is hand-typed, so every invocation re-rolls the dice.

`ARCHITECTURE.md:141-149` already documents the hazard, in the right words, and prescribes the manual check (`xcresulttool get test-results tests`). **It is documented and it still happened twice.** A documented manual step is a comment, and — per this project's own repeated finding — a comment guards nothing.

---

## 5. The durable guard against (c)

`scripts/run-tests.sh` — a wrapper that makes the check unskippable, with distinct exit codes so the two failure modes that have already been misread cannot be misread again:

| Exit | Meaning |
|---|---|
| `0` | tests ran **and** passed |
| `1` | tests ran and at least one failed — a real RED, with the failing test **named** |
| **`2`** | **zero tests executed** — never reported as a pass |
| **`3`** | the **build** failed — explicitly *not* a test result |

Exit 3 exists because of G8: a malformed `switch` printed `** TEST FAILED **`, and a driver that classified any `TEST FAILED` as RED scored a compile error as "the tests caught the mutation." Exits 2 and 3 make "the filter was empty" and "it didn't compile" unable to masquerade as either colour.

**Proven, not proposed** — negative control first, against a suite name that does not exist:

```
▶ xcodebuild test -only-testing:FinanceTrackerTests/ThisSuiteDoesNotExistAnywhere
── executed=0  passed=0  failed=0  skipped=0
✗✗ FILTER MATCHED ZERO TESTS — this is NOT a pass.
   exit 2
```

`xcodebuild` reported success on that run. The wrapper did not. The error text names the three causes seen in this repo (missing `()` on a Swift Testing case, a filter naming a file rather than its suites, a renamed suite) and prints the command that derives the correct suite list from the file.

**Adoption is what makes it durable, and it is one line:** replace hand-typed `xcodebuild … test` with `scripts/run-tests.sh …` in `ARCHITECTURE.md`'s test section, so the documented path and the safe path are the same path. Until that edit lands, the guard exists but is opt-in — which is the state `ARCHITECTURE.md`'s manual `xcresulttool` step was already in, and it did not hold.

---

## 6. What was NOT swept

Stated so this document's coverage is not overclaimed:

- **81 `try?` sites** in production (§3.3) — needs per-site judgement.
- **22 `#Predicate` sites.** A `#Predicate` that matches nothing returns `[]`, and several callers treat `[]` as "nothing to do." Not audited; each needs to be read against its caller's intent.
- **Widget and app-group code paths** beyond the `print` sweep.
- **Whether the guarded scanners' guards are themselves correct** — e.g. `scannedFiles > 100` is a magic number that a large deletion could silently satisfy while still under-scanning.
