# Overnight 2026-08-05

Every finding is labelled **VERIFIED** (demonstrated by a test run or read directly out of the
code at HEAD) or **INFERRED** (reasoned from documentation or taxonomy, not executed).

---

## Item 1 — push f40cf88

Pushed: `12e642c..f40cf88 main -> main`.

**Evidence residual, closed as "not established".** The claim I made was "40 suite summaries,
all 0 failures, no `error:`, no `✘`". That is VERIFIED. The follow-on claim "no suite line is
missing" was NOT established: I never compared 40 against a known expected set, and a suite
that crashes before reporting leaves no line — absent in exactly the same way a non-existent
suite is absent. I also did not have xcodebuild's aggregate `TEST SUCCEEDED` banner, because
my filter dropped it. Both are corrected in the runs below: from here on the filter keeps the
terminal banner, so the claim available is the aggregate verdict rather than a per-suite tally.

---

## Item 2 — classification of the 12 save sites

### Verdict: 12 of 12 are class A. No class B. → **no 1.0.3.1.**

The strongest single fact, and it is structural rather than a judgement call:

> **Not one of the 12 sites touches the only model in the schema that carries a constraint.**

`@Attribute(.unique)` appears exactly once in the whole schema —
`MerchantCategoryLearning.merchantNormalized`, in the local store. All 12 sites insert, delete
or mutate only `Transaction`, `TransactionSplit`, `Category`, `Source`. So the one mechanism
that could have produced a model-level throw is not merely demonstrated-harmless, it is not in
the reachable set.

The shared-context objection is closed too: a `save()` flushes every pending change in the
context, not just the caller's, so an MCL change left pending by someone else could in
principle ride along. It cannot — `MerchantLearningService.record` is the only writer, it
saves on success and `rollback()`s on failure, and it never mutates the unique field (it
fetches by it and overwrites `categoryName`). **VERIFIED** by code read.

| # | Site | What its save() flushes | Class | Why not B |
|---|------|------------------------|-------|-----------|
| 1 | `RecurrenceService:200` `confirm` *(FIXED f40cf88)* | insert Transaction + child TransactionSplits | **A** | no constraint, no `.deny`, every attribute defaulted |
| 2 | `RecurrenceService:220` `stopRecurrence` *(FIXED f40cf88)* | mutate `Transaction.recurrenceRaw` (optional String) | **A** | attribute is optional; nothing to validate |
| 3 | `DashboardView:616` `undoLastAutoSave` | delete Transaction (cascades splits) | **A** | cascade deletes children; no rule can deny |
| 4 | `TransactionsView:198` `delete` | delete Transaction (cascades splits) | **A** | as #3 |
| 5 | `DemoDataController:39` `clearDemoData` | delete N Transactions | **A** | as #3 |
| 6 | `DemoDataController:117` seed | insert N Transactions (+ Category/Source refs) | **A** | all relationships optional |
| 7 | `DemoSeeder:161` `clearDemoData` | delete N Transactions | **A** | as #3 |
| 8 | `SeedService:118` add-missing-categories | insert Categories | **A** | `Category.uuid` lost `.unique` in V2 |
| 9 | `CategoriesSourcesView:398` `saveContext` | Category/Source deletes + order mutations | **A** | `.nullify` on both inverses, and both far sides are `Optional` — nullifying is legal, so 1600 is unreachable |
| 10 | `CategoriesSourcesView:488` limit clear | mutate `Category.limitCents` (optional Int) | **A** | optional attribute |
| 11 | `CategoriesSourcesView:505` limit set | mutate `Category.limitCents` | **A** | as #10 |
| 12 | `CategoriesSourcesView:587` `AddSourceSheet.add` | insert Source | **A** | `Source.uuid` lost `.unique` in V2; `name` defaulted |

Supporting facts, each already established rather than newly argued:

- **`.deny` does not exist anywhere.** Every delete rule is `.nullify` or `.cascade`. VERIFIED (grep of `Models/` + `FinanceTrackerSchemaV1.swift`).
- **Mandatory-property validation (1570) is impossible.** V2's CloudKit shape defaults every synced attribute and makes every relationship `Optional`. VERIFIED by reading all five models.
- **`.unique` upserts, it does not throw.** VERIFIED — `SaveFailureReachabilityProbe` cases 1 and 2. (Not in the reachable set anyway, per above.)
- **Cross-context deletes merge silently.** VERIFIED — probe case 4, driven in the real `CSVImportActor`-vs-`mainContext` shape.
- **Read-only (513) cannot reach these sites.** `allowsSave: false` is used twice: `openV1ReadOnly` (export, its own container) and the migration floor — and the floor is a *terminal screen*, `MigrationFloorView` replaces the app UI at `LaunchGateView:72`. No ordinary surface ever runs on a read-only container. VERIFIED by code read.
- **File protection is deliberately closed.** `.completeUntilFirstUserAuthentication`, chosen because `AddTransactionIntent` runs headless and can fire while locked (`SharedModelContainer:340`). The residual pre-first-unlock-after-reboot window fails at container *open*, upstream of every one of these sites. VERIFIED.

### The refinement the release decision actually turns on

All-A is the answer to the question as posed, and it does point at "ride 1.0.4". But class A as
defined — "throws only under store-level failure (513, 134030)" — contains a member that is
not a dead disk:

**Out-of-space.** `SQLITE_FULL` surfaces as `NSFileWriteOutOfSpaceError` (640) out of exactly
these calls. A phone at 100% full is an ordinary population state, not a tail one. This is
**INFERRED** — from the Cocoa error taxonomy and the code path, not demonstrated; the previous
session could not induce disk-full in the simulator. So the honest form is: *class A is not
the same as "requires a broken device", and the difference is one unmeasured mechanism.*

That does not flip the recommendation, because the consequence of a full-disk save failure at
these sites is now (post-f40cf88) recoverable at the two recurrence sites and merely
mis-reported at the rest. It does mean the 1.0.4 fixes are worth making now rather than
deferring, which is Item 3.

### 1.0.3.1 recommendation

**No 1.0.3.1.** No class-B site exists, so "a silently missing recurring charge reachable in
ordinary use" is not the situation — the two sites that could produce one are fixed, and their
failure now requires a store-level failure and is recoverable when it happens (the prompt
returns). The remaining ten ride 1.0.4.

One thing that would change this: turning on `cloudKitDatabase` in 1.0.4 adds a mirroring
layer to the save path, and this entire classification is contingent on `.none`. It must be
redone for 1.0.4, not inherited.

---

## Item 3 — repairing the remaining sites

Item 2 produced no class-B sites, so the order falls back to **consequence**, as stated there.

### 3.1 — the two destructive paths

`DashboardView:616` (shake-to-undo) and `TransactionsView:198` (swipe-delete) had the same
defect and now share one choke-point, `TransactionDeleteService.delete(_:in:)` — delete,
save, and on a throw `rollback()` + `logSaveFailure` + rethrow. Reference implementation:
`DuplicateReviewService`.

Side-effect audit for these two, per the brief's second shape:

| Site | Side effect | Inside or outside the store? | Before or after the save? |
|---|---|---|---|
| `DashboardView:616` | undo window disarmed (`quickAddSavedTx`/`quickAddSavedAt`), expiry `Task` cancelled, success haptic, `"quickadd.undo.confirmed"` toast, widget snapshot | **outside** — view state, a `Task`, a haptic, an App-Group snapshot | mostly **after** the save but **unconditional**, which is the same defect. The expiry-task cancel was also **before**: on failure the window was left armed with nothing left to expire it |
| `TransactionsView:198` | none — a DEBUG print | n/a | n/a. Its defect was purely the missing rollback |

Both now run their side effects only on success. On failure the Dashboard disarms the window
deliberately (a rolled-back object is not safe to hand to the toast's tap-to-edit — same
reasoning as the existing save-error path at `:586`) and leaves the expiry task running so the
state clears on its own.

Tests: `TransactionDeleteServiceTests` — 4 tests, failure induced with a real read-only store
(513), plus the ride-along property demonstrated on a **writable** store (the inverse of
`SaveFailureReachabilityProbe.pendingDeletesRideAlongOnTheNextSave`), plus cascade coverage in
both directions (a successful delete takes its splits; a failed one leaves all 3 on disk).

Strings: `quickadd.undo.failed`, `transactions.delete.failed`, ×5 locales. Baseline 760 → 762.

### 3.2 — not done tonight

`DemoDataController:39/117`, `CategoriesSourcesView:398/488/505/587`, `DemoSeeder:161` —
ranked and characterised in `outputs/BRIEF_SAVE_SIDE_EFFECTS_AND_BULK_DELETE_MECHANISM.md`.
`SeedService` is deliberately left alone (idempotent by `nameKey`, retried every launch,
derived from the store).

---

## Item 4 — localization

### 4a. THE PREMISE IS FALSE. **STOP-AND-REPORT.** (VERIFIED)

`LocalizedBundle.swift`'s header claims `String(localized:)` and `NSLocalizedString` both
bottom out in `Bundle.main.localizedString(forKey:value:table:)`. Measured from inside the app
module under the **full production sequence** (bundle override + `AppleLanguages`):

```
Bundle.main.localizedString → Настройки   ✅ the override works
NSLocalizedString           → Настройки   ✅ routes through Bundle.main
String(localized:)          → Settings    ❌ STALE — the launch language
```

**Blast radius: 35 live `String(localized:)` sites across 11 files** (44 raw matches, 9 in
comments). `NSLocalizedString` — 80 sites — is fine, as are the 2 sites passing an explicit
bundle.

| File | live `String(localized:)` |
|---|---|
| `Services/PDFExportService.swift` | 10 |
| `Views/DashboardView.swift` | 6 |
| `Services/ProactiveAlertScheduler.swift` | 4 |
| `Services/RecurrenceService.swift` | 3 |
| `Purchases/PurchaseManager.swift` | 3 |
| `Views/Settings/LearnAndTipsView.swift` | 2 |
| `Views/RecurringPromptSheet.swift` | 2 |
| `Views/AddTransactionView.swift` | 2 |
| `Views/Settings/RecurringSettingsView.swift` | 1 |
| `Views/AuthGateView.swift` | 1 |
| `Views/Analytics/AnalyticsBreakdownView.swift` | 1 |

**Severity, stated carefully.** The staleness is **session-scoped**: `AppleLanguages` is written
on switch, so the *next* cold launch resolves correctly. But three of those files bake the
wrong language into artifacts that OUTLIVE the session:

- `ProactiveAlertScheduler` (4) and `RecurrenceService` (3) compose **notification bodies**, and
  a local notification's copy is frozen at schedule time. Switch to Russian and the reminders
  scheduled in that session arrive in English, days later.
- `PDFExportService` (10) — a document the user keeps or sends.

That part I would not call cosmetic. **INFERRED, not measured**: I did not schedule a
notification across a language switch and read it back.

**Mechanism NOT distinguished** (INFERRED): the evidence cannot separate "`#bundle` resolves to
something `object_setClass` never touches" from "Foundation cached the main bundle's
localization on first use". Both produce this outcome, and in the app the first resolution
always happens at launch, before any switch — so the user-visible result is identical either
way. Worth resolving before choosing a fix: the two have different fixes.

Not fixed, per the brief.

**Test: `LocalizedBundlePremiseTests`** (4 tests, green). The broken path is asserted BROKEN — a
`KNOWN DEFECT PIN`, the discipline `LanguageSwitchTests` already uses for the first-tap race. It
fails the moment someone fixes the defect, which is when the pins flip from `!=` to `==`.

**What `LanguageSwitchTests` actually asserts** (the brief asked): a UITest about the picker's
*presentation* — opens in ≤1 tap, target row disappears, the Settings language row still exists
and is hittable, the picker reopens. **Nothing about which language any string resolves to.** So
it was green with the premise untested — itself worth reporting, as the brief anticipated.

**Two harness traps found, both of which faked a result** (recorded in the test header):

1. `String(localized:)` called from the TEST target resolves against `FinanceTrackerTests.xctest`,
   which ships no `.lproj`. The first version of this test reported the premise broken *for the
   wrong reason*. Every assertion now routes through `LocalizationProbe`, in the app module.
   Without this the finding would have been an artifact.
2. The unit-test host is the **real running app**. Writing `appLanguageCode` into standard
   defaults from a non-`@MainActor` test drove `@AppStorage` → `LocalizedBundle`'s `@Published`
   → a live SwiftUI rebuild off the main thread, and **crashed the host process after the suite
   reported all green** — xcodebuild printed `** TEST FAILED **` over four passing tests. The
   suite is now `@MainActor` and the `appLanguageCode` write is dropped (it drives the view
   cascade, which cannot change what `String(localized:)` returns).

### 4b. `.languageReactive()` coverage — LIST ONLY

**The premise failure reframes this item.** `.languageReactive()` rebuilds a subtree so its
strings re-resolve. For `NSLocalizedString` that works. For the 35 `String(localized:)` sites
**it cannot help at all** — rebuilding re-resolves to the same stale value. So placement is only
a question for `NSLocalizedString` + `Text` content.

Carries the modifier (6): `ContentView`, `DashboardView`, `TransactionsView`,
`DuplicateReviewView`, `Settings/SettingsView`, `Settings/GeneralSettingView`.

| Top-level reachable screen | modifier | `String(localized:)` (stale regardless) | `NSLocalizedString` (needs the rebuild) |
|---|---|---|---|
| DashboardView (tab) | ✅ | 6 | 0 |
| TransactionsView (tab) | ✅ | 0 | 0 |
| AnalyticsView (tab) | ❌ | 0 | 0 |
| Settings/SettingsView (tab) | ✅ | 0 | 3 |
| Settings/GeneralSettingView | ✅ | 0 | 0 |
| DuplicateReviewView (sheet) | ✅ | 0 | 0 |
| **Settings/DataSettingsView** | ❌ | 0 | **17** |
| **Settings/CategoriesSourcesView** | ❌ | 0 | **7** |
| **Settings/ImportMappingView** | ❌ | 0 | **5** |
| Settings/EditTransactionView | ❌ | 0 | 3 |
| AddTransactionView (sheet) | ❌ | 2 | 1 |
| Analytics/AnalyticsBreakdownView | ❌ | 1 | 1 |
| Analytics/CategoryDetailView | ❌ | 0 | 1 |
| Analytics/DaySpendingSheet | ❌ | 0 | 1 |
| Analytics/MonthDetailSheet | ❌ | 0 | 1 |
| Settings/LearnAndTipsView | ❌ | 2 | 0 |
| Settings/PremiumSettingsView | ❌ | 0 | 1 |
| Settings/RecurringSettingsView | ❌ | 1 | 0 |
| RecurringPromptSheet (sheet) | ❌ | 2 | 0 |
| QuickEntry/QuickEntryView (sheet) | ❌ | 0 | 1 |
| AuthGateView | ❌ | 1 | 0 |
| Launch/LaunchGateView | ❌ | 0 | 1 |

Components (`AddCategorySheet` 2, `CategoryPickerSheet` 1, `CategoryTileRow` 1,
`NewCategoryViewModel` 1 — all `NSLocalizedString`) inherit whatever their host rebuilds, so
they are not separate placement decisions.

**The three that stand out**, and where I would look first if this becomes a fix:
`DataSettingsView` (17), `CategoriesSourcesView` (7), `ImportMappingView` (5) — all
`NSLocalizedString`, all without the modifier, all pushed from Settings, i.e. reachable in the
same session as a language switch that just happened one screen away.

---

## Item 5 — MonetizationGateFlowTests (investigation)

### The branch that matters, answered from code first

**It is NOT a production bug wearing a test failure's clothes — but the code says something
its comment does not.**

The gate reads `AppGroupReverseTrialStore` → App Group `UserDefaults`, key
`reverseTrialStartDate`. Both user-reachable routes are already reasoned about in the source:

- **Reinstall** — resets it. `ReverseTrial.swift:68-72` states this explicitly and accepts it:
  *"the abuse ceiling is one extra fortnight and the alternative (Keychain, which survives
  deletion) would silently deny the trial to a legitimate user restoring a device, which is the
  worse failure."* That is a decision, not an oversight. VERIFIED (code read).
- **Restore from backup** — App Group defaults are included in device backup, so the start date
  comes back with it. No new trial. VERIFIED (code read).

### The gap (NEW — neither of us anticipated this)

**`daysRemaining` clamps for a rewound clock. `isActive` — the actual gate — does not.**

```swift
static func isActive(start: Date?, now: Date) -> Bool {
    guard let start else { return false }
    return now < expiryDate(start: start)        // no clamp
}

static func daysRemaining(start: Date?, now: Date) -> Int {
    ...
    let clamped = min(max(remaining, 0), duration)   // the clamp lives HERE
}
```

`daysRemaining`'s comment claims *"the worst a rewound clock buys is the trial the user already
had."* That is true of the number on screen. It is **not** true of entitlement: `AccessLogic.isPremium`
→ `ReverseTrial.isActive`, which compares raw `now` against raw expiry with no clamp. Set the
device clock back and premium is restored for as long as the clock stays back — unbounded, not
one fortnight.

Severity: **low, and I am not recommending a fix tonight.** Rolling the device clock back is
self-punishing (it breaks every other app and iOS re-syncs time), and every locally-stored trial
has this property. What is worth correcting is the **comment**, which currently documents a
protection the gate does not have — exactly the kind of claim this project has been burned by.
1.0.4 hanging iCloud sync on the same gate is the reason to record it now rather than later.

**Not fixed** (monetization gate, and the brief says not overnight). Recorded.

### The test failure itself — **DID NOT REPRODUCE** (VERIFIED)

Run at HEAD (`e07e262`), each on a freshly `simctl erase`d simulator:

| Scope | Result |
|---|---|
| `test_allTimePDFExport_isGatedAfterTrialEnds` **alone** | **passed** (22.5 s) |
| whole `MonetizationGateFlowTests` class, in order | **all 5 passed** — accountCap 39.1 s, allTimePDFExport 16.6 s, csvExport 21.3 s, csvImport 15.6 s, trialEnd 6.4 s |
| whole `FinanceTrackerUITests` target, in order | **`test_allTimePDFExport` passed.** The target failed on a DIFFERENT test — see "Found while doing something else" |

So the brief's premise — "fails alone on a clean simulator run at HEAD" — **does not hold at
this HEAD**. It is not order-dependence within its own class either. I am reporting that rather
than hunting for a failure I cannot make happen: the two most likely explanations are that HEAD
moved (three commits tonight) or that the earlier observation was on a simulator carrying state
from a prior run, which is exactly the class of problem this suite's own `--reset-accounts` seam
was added for.

**The ambient-state surface, recorded anyway** — it is real even though it did not bite tonight,
and it is where to look if this recurs:

- `launchAsLapsedFreeUser()` does **not** pass `--reset-accounts` (only the cap test does), and
  `launch()` reuses the app container, so anything a prior test wrote survives into it.
- `reverseTrialEndPaywallShown` is the flag to suspect first. `dismissTrialEndPaywall` is
  `@discardableResult` and three of the four callers ignore its return, so if a prior test
  already set the shown-once flag the paywall does not auto-raise, the helper burns its 25 s
  timeout, and the test proceeds from a different UI state than it assumes. **Hypothesis from
  code reading, not a diagnosis** — it did not fire in any run tonight.

---

## Found while doing something else — written down, NOT fixed

### F1. `BulkDeleteStallMeasurementTests.test_measure_settingsResetTransactions_at8kRows` is broken — **REPRODUCED CLEAN** (VERIFIED)

I first saw this fail during a run where I had concurrently started `xcodebuild build`, which
would have been a completely sufficient explanation. **It is not the explanation.** Re-run alone,
on a freshly `simctl erase`d simulator, with nothing else on the machine, at `2565f9b`:

```
BulkDeleteStallMeasurementTests.swift:120: XCTAssertTrue failed - Reset Transactions row missing
BulkDeleteStallMeasurementTests.swift:121: Failed to tap "Reset Transactions" Button: No matches found
Test Case ... failed (85.6 seconds)
** TEST FAILED **
```

Not a freeze, and not a mislabel. Line 116 — the `General` row — **passes**, so the screen
renders and navigation works. The label is correct: `general.reset_transactions` = "Reset
Transactions", and the row is a `Button` with that `Label`. It is the row itself that is never
found in 60 s.

**Two defects in the vehicle, and the second is the one that matters:**

1. **The test never scrolls.** `grep -n "swipeUp\|scroll"` over the file returns nothing, and the
   Reset row is the last control in a long General form (language, currency, appearance, restart
   onboarding, then reset). Lazy `Form` rows that have not been realized are not in the
   accessibility tree, so `waitForExistence` legitimately fails. Scroll occlusion is already on
   this project's documented harness-trap list. **Leading hypothesis, not proven** — I did not
   add a swipe and re-run, because fixing it is a separate pass.

2. **The confirmation-button label is wrong, and it fails SILENTLY.** Line 124 looks for
   `app.alerts.buttons["Reset Transactions"]` under the comment *"the destructive button carries
   the same label."* It does not. The alert's destructive button is `general.alert.reset` =
   **"Reset"**; only the alert TITLE is "Reset Transactions?". And the lookup is guarded by `if`,
   with the final wait discarded via `_ =` — so once defect 1 is fixed, this test will **tap the
   row, never confirm, never perform the reset, and pass while measuring nothing.** A measurement
   vehicle that reports success without performing the operation is worse than one that fails.

**Scope — deliberately NOT over-claimed.** This does **not** touch the numbers Item 6 rests on.
The cost curve and the 2×2 mechanism probes are UNIT tests (`BulkDeleteCostMeasurementTests`,
`BulkDeleteQuadraticMechanismTests`), which ran green in every full-suite run tonight. This UI
vehicle measures the runloop stall under device-like conditions and is complementary. What is
now unknown is whether it has *ever* produced a real measurement.

Written down, not fixed, per the standing rules.

### F2. `ReverseTrial.isActive` has no clock clamp — see Item 5

Recorded there rather than duplicated here. Comment claims a protection the gate does not have.

### F3. Three sheet sites are fixed but NOT unit-tested

`CategoryLimitSheet` (clear + save) and `AddSourceSheet.add` are `private struct`s inside
`CategoriesSourcesView.swift`. Unit-testing them means extracting them, or driving a UITest
through Settings → Categories & Accounts against a store made unwritable mid-flight. That is
disproportionate scaffolding for three call sites whose change is one `guard` each — stating it
explicitly, per the brief, rather than committing an untested fix quietly.

### F4. `usage.ever.splits` is recorded BEFORE the save that persists the split — in the instrument the pre-test's kill rule depends on (VERIFIED, code read)

Found while re-reading `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md`. It is the same shape Item 3
spent the night removing, sitting in the one place where it corrupts a decision rather than a
screen.

`TransactionEditService.update` (`:64-85`):

```swift
let prior = snapshot(of: tx)
apply(fields, to: tx, in: context)     // ← markUsed(.splits) fires HERE
do {
    try context.save()
} catch {
    apply(prior, to: tx, in: context)  // ← and AGAIN here, if prior had splits
    context.rollback()
    throw error
}
```

`apply` ends with `if !f.splits.isEmpty { FeatureUsageSignals.markUsed(.splits) }` (`:133`).
So:

- a user who builds a split and whose save **fails** is counted as having ever split;
- the revert path calls `apply` a second time, so an edit that *removes* splits from a
  transaction that had them re-marks the flag on the failure path;
- `markUsed(.recurring)` two lines below has the identical shape.

`usage.ever.splits` is not telemetry — it is the numerator of a **pre-registered kill rule**
(≥40% ever-split, ≥15% habitual, N≥25, thresholds fixed before data). Inflating it biases the
instrument toward BUILD, which is the direction that costs money. The absolute rate is presumably
tiny — it needs a failed save — but "small bias in the safe direction" and "small bias in the
expensive direction" are not the same finding, and this is the expensive one.

Written down, not fixed.

---

## Bonus — does `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md` still apply after tonight?

**Yes, substantively unchanged.** I touched none of the three files it modifies
(`TransactionDetailView`, `EditTransactionView`, `AddTransactionView`). Every code claim
re-verified at `2565f9b`:

| Claim | Status |
|---|---|
| `TransactionDetailView` gates the split section on `CategoryAttribution.isSplit(tx)` | ✅ still true (~:37) |
| `showEdit` at `:13`, `.sheet` at `:66` — so Change A needs no new state | ✅ **exactly** those lines |
| `EditTransactionView` routes split picks through `CategoryPickerSheet` | ✅ (`:168`) — Change A still cannot violate the CLAUDE.md single-picker rule by construction |
| `split.section`, `split.add_part`, `split.hint`, `tx_detail.section.split` all exist, ×5 | ✅ (and `split.incomplete_row`, which the optional refinement depends on) |

**Two corrections it needs before it is built:**

1. **The locale baseline is stale.** The proposal says 759. It is **763** at `2565f9b`
   (759 → 760 before tonight, then +2 for the guarded delete paths and +1 for the shared
   Categories & Accounts error).
2. **Its arithmetic is wrong, and the answer is accidentally right.** It writes
   "one new key, ×5 locales (locale baseline 759 → 764)" — but `LocaleCompletenessTests` asserts
   the **English** key count, so one new key is **+1**, not +5. The correct line is
   **763 → 764**. The end number happens to be right for the wrong reason, which is exactly the
   kind of thing that survives review.

**One thing tonight adds to it, not a correction:** F4 above. The proposal exists to make the
pre-test honest by fixing discoverability; F4 is a second, independent way the same pre-test is
currently dishonest, on the counting side rather than the exposure side. Both should be resolved
before T0 starts, because T0 binds to 1.0.4 availability and the instrument reports "ever split"
with no date — so neither can be corrected retroactively by splitting the window.

---

## Night summary — state of the tree

| Commit | Item | Pushed |
|---|---|---|
| `f40cf88` | recurrence watermark ordering (from the prior session) | ✅ |
| `de1da04` | Item 3.1 — guarded delete service, both destructive paths | ✅ |
| `e07e262` | Item 4a — LocalizedBundle premise pinned | ✅ |
| `2565f9b` | Item 3.2 — remaining seven audited save sites | ✅ |
| this report | | pending |

Nothing local-only. Full unit target green (`** TEST SUCCEEDED **`) immediately before each of
`de1da04`/`e07e262` (one run, combined tree — stated rather than implied) and before `2565f9b`.

**Evidence forms used tonight**, since the brief asked for the distinction:
- `** TEST SUCCEEDED **` — xcodebuild's aggregate banner. Available for every commit gate above.
- "337 tests, 2 skipped, 0 failures" — XCTest's top-level `All tests` line. Available for the
  first full run; it also supplies the expected-count anchor the Item 1 residual lacked.
- "every suite reported zero failures" — the weaker per-suite tally. Not relied on after Item 1.

**Forbidden list respected:** no schema change, no V3, no model attributes, no rollback-ladder
work, no repo-visibility change, no force-push, no history rewrite, `store-rehearsal/` untouched,
nothing in App Store Connect.

**Open / not done:**
- Item 4a fix — 35 `String(localized:)` sites. STOP-AND-REPORT honoured; not started.
- Item 5 — no fix (monetization gate, and the named test does not fail). F2 recorded.
- Item 6, Item 7 — document only, as instructed.
- F1 — the stall measurement vehicle is broken; reproduced clean; not fixed.
- F3 — three sheet sites fixed without unit tests, by explicit choice.
- F4 — `usage.ever.splits` marked before its save; not fixed.
