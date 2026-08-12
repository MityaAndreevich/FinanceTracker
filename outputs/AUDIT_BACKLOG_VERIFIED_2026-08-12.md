# AUDIT — the backlog, verified against HEAD

**Date:** 2026-08-12 · **HEAD:** `4e6a8db` · **Version:** 1.0.4 (build 8), not submitted
**Mode:** read-only. No source file was modified, no fix applied, no refactor performed.
Everything below is a claim about the code as it stands at `4e6a8db`, with file:line evidence.

> **Why this document exists.** The working backlog was assembled from session notes across two
> weeks and several branches. Some of it shipped and was never struck off. This establishes what is
> actually true before anything is planned on top of it.

---

## 0. Lead — what is ALREADY FIXED

These were carried as open and are closed at HEAD. This is the part that changes the plan.

| Item | Where it was tracked | Evidence at HEAD |
|---|---|---|
| **Split discoverability — the whole proposal, both changes** | `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md` ("Status: proposal, nothing built") | **Change A shipped, including the refinement the proposal recommended**: `TransactionDetailView.swift:53–74` — the `if isSplit` is now `if / else if !tx.isIncome`, rendering `split.section` + `split.add_part` + `split.hint` on never-split expense rows, and it sets `startSplitting = true` so Edit opens with a seeded split row (`EditTransactionView.swift:21–26`). **Change B shipped**: `add.category.split_hint` exists in all 5 locales and renders at `AddTransactionView.swift:308`. |
| **Silent-failure B1 — account creation** | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md` §3.1 | `AddTransactionView.swift:737–746` — the duplicated insert/save is gone, routed through `SourceCreateService.add`, and a nil return raises `showSaveFailed`. |
| **Silent-failure B2 — offer-code redemption** | same, §3.1 (*"This is a monetization path"*) | `PremiumSettingsView.swift:101–113` — `storeKitLog.error(...)` **plus** a user-facing alert with the underlying `localizedDescription`. |
| **Silent-failure B3 — legacy-store migration** | same, §3.1 | `SharedModelContainer.swift:333, 337–339` — `persistenceLog.notice` / `.error`, compiled in both configurations, with an explicit comment that a DEBUG-only print made exactly the builds users run the ones that recorded nothing. |
| **Silent-failure B4 / B5 — the two QA debug seams** | same, §3.3 (*"the live risk"*) | `AccountResetDebugSeam.swift:59, 67` and `DuplicateReviewDebugSeed.swift:58, 65` both emit `MainThreadStallMonitor.note(...)` on success **and** failure — a channel a UI test can actually read. |
| **`scripts/run-tests.sh` adopted into ARCHITECTURE** | same, §5 (*"until that edit lands, the guard is opt-in"*) | `ARCHITECTURE.md:155–180` documents the wrapper, the four exit codes, and both traps (missing `()`, suite-vs-file names). Documented path == safe path. |
| **Splash navy squircle** | carried open in session notes | `SplashView.swift:20–33` — `Color(.systemBackground)` + transparent `MascotCrab`, sized to match the storyboard. The baked-navy PNG is gone from this path. |
| **Autofill on text fields** | `BRIEF_DISABLE_AUTOFILL_TEXTFIELDS.md` | `Shared/PlainTextEntry.swift` exists as the shared modifier and is applied at **26** sites. The file also records, honestly, the part that did *not* work (the long-press AutoFill edit menu is a separate mechanism and remains). |
| **Tips content landing** | `BRIEF_TIPS_CONTENT_LANDING_V1_0_2.md` | `FinanceTracker/{en,ru,uk,es,pt-BR}.lproj/tips.json` — **102** tips each, 5 locales in parity, committed in `5cd7b56`. ⚠️ The brief and `LocaleCompletenessTests.swift:165` both talk about a *365*-item library; what landed is 102. The mechanism supports 365; the content is 102. |
| **`docs/PRIVACY_POLICY.md` duplicate** | `REVIEW_PRIVACY_POLICY_CORRECTION_2026-08-03.md` header still says **"Status: NOT APPLIED. NOT PUBLISHED. `docs/PRIVACY_POLICY.md` is untouched"** | That header is **stale**. At HEAD the file is a 40-line pointer to the canonical HTML, the divergent copy was deleted 2026-08-03, and GitHub Pages was disabled on this repo the same day. The in-repo half is closed. **What is NOT verifiable from here:** whether the published `budget-crab/PRIVACY_POLICY.html` carries the corrections — it lives in another repository. |

**Consequence worth pulling out of the table.** The receipt-OCR pre-test's kill criterion was
conditional: a null "nobody splits" result was confounded because splitting was invisible, so a KILL
was only valid once discoverability was fixed. **It is now fixed at HEAD.** That precondition is
satisfied and the pre-test's clock can start against a build where the affordance exists.

---

## PART A — every open item, verified

### A1. `AboutView.swift:57` — `idTBD` in the App Store URL

**NOT FIXED.** Confirmed as you said, included for completeness.

```
FinanceTracker/Views/Settings/AboutView.swift:56  /// App Store URL — replace `idTBD` with the real App ID once Apple assigns it post-submission.
FinanceTracker/Views/Settings/AboutView.swift:57  private static let appStoreURL = URL(string: "https://apps.apple.com/app/budget-crab/idTBD")!
```

The real ID **6784424678** appears **nowhere** in the repository (grepped `*.swift`, `*.strings`,
`*.plist`). This is the only `apps.apple.com` URL in the app. It is force-unwrapped and will not
crash — `idTBD` is a syntactically valid path component — so the failure mode is a live "Rate the
app" / "Share" link that lands on an App Store error page. One-line fix, no test needed beyond
opening the link.

### A2. Month-end recurrence drift (Jan 31 → Feb 28 → Mar 28, permanently)

**NOT FIXED.** Both halves of the mechanism described in `BRIEF_MONTHEND_RECURRENCE_DRIFT.md` are
intact and unchanged:

```
FinanceTracker/Services/RecurrenceService.swift:133-136
    static func nextDueDate(for tx: Transaction, recurrence: RecurrenceType) -> Date {
        let lastBoundary = handledDate(for: tx.uuid) ?? tx.date     // advances from the CLAMPED result
        return recurrence.nextDate(after: lastBoundary)
    }

FinanceTracker/Models/RecurrenceType.swift:84-86
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: dateComponent, value: 1, to: date) ?? date   // .month clamps into short months
    }
```

No anchor-preserving path exists anywhere: there is no `min(anchorDay, daysInMonth)` computation in
the target and no test file covering it (`RecurrenceEditTests`, `RecurrencePeriodLabelTests`,
`RecurrenceWatermarkOrderingTests` all test other properties). The brief's decision point — *are
already-drifted series re-anchored or left alone?* — is still unanswered and is a product call, not
an implementation detail.

**Interaction to carry into sync work:** the brief already notes the anchor must come from
`RecurrenceService.canonicalTemplate(among:)` rather than an arbitrary row once twins can exist.
That coupling is real but it does not block fixing the drift today — twins are unreachable without
sync (verified 2026-08-10, 7/7).

### A3. Quadratic `save()` on bulk delete — mechanism fix, or only measured?

**MEASURED ONLY. The mechanism fix is NOT in.**

The mechanism was established, not guessed: `BulkDeleteQuadraticMechanismTests.swift:8–38` runs a
2×2 plus two probes (D: 400 categories; E: `category == nil`) that isolate *maintaining the inverse
of `Category.transactions`* as the cost. The relationship that produces it is untouched at HEAD:

```
FinanceTracker/Models/Category.swift:51-52
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?
```

What **did** ship on this path is a different, smaller fix — the swallowed-save / count-authoritative
outcome in `TransactionResetService.swift:37–61`. That fixes *"the reset lied about failing"*. It
does not touch the cost curve. Settings → Reset at 8k rows is still one unbroken ~6.5s main-thread
block.

⚠️ **Stale comment found while verifying this.** `TransactionResetService.swift:47–51` asserts that a
thrown `save()` *"leaves un-committable pending DELETES … that poison every subsequent save()"*. That
claim was withdrawn as unsupported (`.unique` upserts; cross-context deletes merge). The
`rollback()` it justifies is still correct defensive behaviour — but the stated *reason* is false,
and this project has now been misled three times by a comment that outlived the code beneath it.
Recorded, not fixed.

### A4. The rollback ladder — the three §5 fixes from `DEFECT_V2_MIGRATION_SENTINEL`

**NOT FIXED — all three, and the load-bearing one is untouched.**

| §5 change | State at HEAD | Evidence |
|---|---|---|
| 1. Version-aware sentinel | **NOT FIXED** | `SharedModelContainer.swift:29` — `static let migrationCompleteKey = "v2MigrationComplete"`, still a `Bool` (`:37–39`), still gating via `needsGuardedMigration = storeFileExists && !isMigrationComplete` (`:83–85`). No `storeSchemaVersionConfirmed`, no schema-version triple, anywhere in the repo. |
| 2. Generational backup | **NOT FIXED** | `StoreBackup.swift:46` — `static let backupDirectoryName = "Backups/pre-v2"`, a hardcoded literal. No `pre-v<n>` interpolation exists. |
| 3. `--fail-migration` seam moved to a path every migration executes | **NOT FIXED** | `StoreMigration.swift:101` — the throw is still inside `verifyNoDanglingReferences`, which runs from the **V1→V2 custom stage's `didMigrate`** (`:51–63`). The post-open sanity probe the audit named as the natural home (`SharedModelContainer.swift:141` fast path, `:201` guarded path) has no seam. |

The defect stands exactly as written: every shipped 1.0.3 device has `v2MigrationComplete = true`, so
`bootstrap()` takes the fast path at `:137–153` — which writes **no backup**, **never increments the
attempt sentinel**, and **never enters the retry loop** at `:191–217`. A V2→V3 failure lands on
`.failedPermanently` on the first throw, with `Backups/pre-v2` already deleted by
`StoreBackup.deleteAfterConfirmedGood()` (`:146`).

**This remains a prerequisite of *shipping* V3, not of drilling it.** Nothing in the 1.0.4 work
plan changes that.

### A5. `ReverseTrial.isActive` clock clamp

**NOT FIXED — and this is the item whose specification is wrong, not just its status.**

The gate is unclamped at `ReverseTrial.swift:51–54`. But the file itself already records (`:56–99`,
corrected 2026-08-08) that **the requested fix does not work**: adding `max(now, start)` to `isActive`
only forbids `now` *preceding* the start; a clock rewound to a date *inside* the window still reports
active. That was demonstrated — the pin in `AccessManagerTests` passes with the clamp applied.

So the backlog line "ReverseTrial.isActive clock clamp" should be **struck and rewritten**. The real
work is a persisted monotonic high-water mark of observed time, with expiry compared against
`max(now, watermark)` — a stored value with its own migration, sync and reinstall semantics.

**And it is not free to defer.** `AppCapability.iCloudSync` is `requiresPremium == true`
(`FreeTierLimits.swift:93`). Once sync ships, this gate stops being a local display question and
starts deciding whether data leaves the device. Recommend: re-file as *"monotonic time watermark for
entitlement gates"*, sized against sync, not as a one-liner.

### A6. ChartBisection debug scaffolding — is #22 closed?

**#22 IS NOT CLOSED. The removal instruction does NOT yet apply. Leave the scaffolding in.**

`DEVICE_BISECTION_1_0_3_QUICKADD_CRASH.md:3` — *"Status: **NOT REPRODUCED in the simulator. No fix
committed.** The device is the…"*. There is no later document closing it. `DEVICE_QA_1_0_2.md:45`
still files it as *"the crash watch (#22 — ship-and-monitor)"*.

`ARCHITECTURE.md:197–203` is explicit that deletion is gated on *confirmed closed*, "never before
(they're the only handle we have on it)". Current footprint, **24 references across 8 files** — matching
the removal list exactly, so when #22 does close the deletion is mechanical:

```
FinanceTracker/Shared/ChartDebug.swift                      9   (ChartBisection, BisectableChart, toggle store)
FinanceTracker/Views/Components/CategoryDonutView.swift     3
FinanceTracker/Views/Analytics/AnalyticsBreakdownView.swift 3
FinanceTracker/Views/Analytics/DaySpendingSheet.swift       3
FinanceTracker/Views/Analytics/AnalyticsPulseView.swift     2
FinanceTracker/Views/Analytics/AnalyticsHorizonView.swift   2
FinanceTracker/Views/Settings/GeneralSettingView.swift      1   (Settings → Debug section, :518)
FinanceTrackerTests/ReleaseDebugAffordanceTests.swift       1   (comment only)
```

All production hooks are `#if DEBUG` no-ops in Release (`ChartDebug.swift:144–190`), and
`ReleaseDebugAffordanceTests` pins that. **The scaffolding costs nothing shipped.** The only cost is
reading noise. Do not remove it as cleanup.

### A7. Tier 3 silent `print` sites

Reading "Tier 3" as **§3.3 of `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md`** — the debug seams. I
verified §3.1 and §3.2 alongside it, because the fixes landed across the tiers rather than within one.

| ID | Site | State | Evidence |
|---|---|---|---|
| B1 | Account creation | **FIXED** | `AddTransactionView.swift:737–746` |
| B2 | Offer-code redemption | **FIXED** | `PremiumSettingsView.swift:101–113` |
| B3 | Legacy-store migration | **FIXED** | `SharedModelContainer.swift:333, 337–339` |
| **B4** | `AccountResetDebugSeam` | **FIXED** | `:59`, `:67` — `MainThreadStallMonitor.note` on both paths |
| **B5** | `DuplicateReviewDebugSeed` | **FIXED** | `:58`, `:65` — same shape |
| **B6** | `DemoSeeder` | **NOT FIXED** | `:89, :93, :243, :287, :381, :414` — `print` only. `:381` and `:414` **silently skip** an entry and a split set respectively. |
| **B7** | `SeedService` | **NOT FIXED** | `:29, :92, :214` — `print` only; `:214` is the **category migration**. |

**§3.2 (user is told, cause is unrecoverable off-device):** 1 of 5 fixed.

| Site | State |
|---|---|
| `AddTransactionView:562` → now `:566` | **FIXED** — `logSaveFailure("AddTransactionView.add", error)` sits alongside the print |
| `TransactionsView:213` | **NOT FIXED** — print only |
| `DuplicateReviewView:184` | **NOT FIXED** — print only |
| `AddCategorySheet:287` | **NOT FIXED** — print only |
| `GeneralSettingView:499` | **NOT FIXED** — print only, and here the print *is* the diagnostic (`remaining` count) |

**Net: 5 of 12 named sites fixed.** Production `print(` count is **32** (was 36).

**Severity split, so this is not queued as one undifferentiated blob:**

- **B7 `SeedService:214` is the one that matters.** It is a category migration whose failure is
  invisible in Release. Same class as B3, which was fixed.
- **B6 `DemoSeeder:381` / `:414`** silently drop content. Demo/screenshot paths only — low user risk,
  real risk to anyone trusting a capture.
- **§3.2 remainder** — all four have a user-visible alert already. The gap is root-causability from a
  TestFlight report, not user deception. `PersistenceLog` exists and is used at 24 sites; adding four
  more is mechanical.

**Explicitly still not swept** (unchanged since the audit, restated so coverage is not overclaimed):
81 `try?` sites, 22 `#Predicate` sites, widget/app-group paths beyond the print sweep.

### A8. Sweep — items marked open in `outputs/*.md` that are in fact closed

Swept every `outputs/*.md` status line and cross-checked the ones with a code-verifiable claim.
The closed-but-still-marked-open findings are in **§0** above. The genuinely-still-open set:

| Document | Status line | Verdict |
|---|---|---|
| `DEFECT_V2_MIGRATION_SENTINEL.md` | "blocks V3" | **ACCURATE** — see A4 |
| `DEVICE_BISECTION_1_0_3_QUICKADD_CRASH.md` | "NOT REPRODUCED. No fix committed." | **ACCURATE** — see A6 |
| `MEASUREMENT_BULK_DELETE_CURVE.md` | "measurement only, no fix proposed" | **ACCURATE** — see A3 |
| `DESIGN_ICLOUD_SYNC_1_0_4.md` | "DESIGN ONLY" | **ACCURATE** — `cloudKitDatabase: .none` at `SharedModelContainer.swift:257, 260`; no entitlement change |
| `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md` | "DESIGN ONLY" | **ACCURATE** — watermark still `UserDefaults`-backed per-device |
| `BRIEF_MONTHEND_RECURRENCE_DRIFT.md` | "filed, not started" | **ACCURATE** — see A2 |
| `REVIEW_PRIVACY_POLICY_CORRECTION_2026-08-03.md` | "NOT APPLIED… untouched" | **STALE — see §0** |
| `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md` | "proposal, nothing built" | **STALE — see §0** |
| `SPEC_PHOTO_INPUT.md` | "spec-ready, not a build brief" | **ACCURATE**, and superseded by the pre-test gate |

**Two documents whose *content* is stale rather than their status:**

- `FEATURE_PREP_BACKLOG.md:58` lists split transactions under 1.0.3 as *"the pre-test for row 1"* —
  correct, but does not record that the discoverability precondition is now met.
- `LocaleCompletenessTests.swift:165` still says *"a 365-item library can land"*; 102 landed.
  Baseline is **765** English keys, all 5 locales in parity (`:238–244`).

---

## PART B — onboarding and discoverability

### B.1 What exists, and whether it is live

**It is live, and it is more complete than the backlog implies.** Everything below runs on a genuine
first launch of a shipped build.

| Component | File | Drives what | Live? |
|---|---|---|---|
| `OnboardingCoordinator` | `Onboarding/Coachmarks/OnboardingCoordinator.swift` | Phase machine: `greeting → coachmark(0..2) → firstWin → done`. Persists to `hasCompletedOnboarding`; also sets `hasSeenFeatureTour` on completion so the rating gate stays satisfied (`:96–104`). | **LIVE** — `@StateObject` in `ContentView.swift:20`, started at `:207–211` |
| `MascotGreetingView` | `Onboarding/MascotGreetingView.swift` | The `.greeting` card. Renders `onboarding.greeting.privacy`. | **LIVE** — `ContentView.swift:91` |
| `CoachmarkOverlay` + `CoachmarkID` | `Onboarding/Coachmarks/` | Highlights **the real controls in place** via `anchorPreference` → `overlayPreferenceValue` → `GeometryProxy`. | **LIVE** — `ContentView.swift:72–85` |
| `FirstWinView` | `Onboarding/FirstWinView.swift` | Guided first win: "Add one now" (opens Quick Entry) or "Explore with demo data" (`DemoSeeder.seedOnboardingDemoGuarded`). | **LIVE** — `ContentView.swift:93–104` |
| `InlineHintBubble` | `Onboarding/InlineHintBubble.swift` | One-shot in-context hints for targets that live **off** the Dashboard. | **LIVE**, exactly **2** sites |
| `DashboardTeachingSlot` | `DashboardView.swift:1089–1122` | Exactly one teaching card at a time: tip-of-the-day, else Day-0 nudge, else nothing. | **LIVE** — `DashboardView.swift:963–989` |
| `EdgeSwipeHintView` | via `ContentView.swift:167–172, 293–300` | Flashes the edge-swipe affordance on the first 3 launches, then never again. | **LIVE** |

**Which screens the coach-marks cover — three, all co-located (`CoachmarkID.swift:16–19`):**

1. `.quickAdd` → the Dashboard quick-add bar (`DashboardView.swift:275`)
2. `.budget` → the Dashboard budget control (`DashboardView.swift:251`)
3. `.analyticsTab` → the Analytics tab item

**The two inline hints:**

- `onboarding.hint.openform` → "Use detailed form" in Quick Entry (`QuickEntryView.swift:680`)
- `onboarding.hint.period` → the Transactions month pager (`TransactionsView.swift:92`)

### B.2 The three-page intro no longer exists

Direct answer to the question as posed. `tutorial.page1.*` / `page2.*` / `page3.*` are **orphaned
strings** — no view renders them. The only survivor in use is `tutorial.page3.demo_offer`
(`GeneralSettingView.swift:164`). The carousel was retired for the coach-mark flow
(`ContentView.swift:18–19`, `RootView.swift:64–66`).

So: **replaying re-runs greeting → 3 coach-marks → first-win. There is no 3-page intro to re-run.**

Orphaned string groups found while checking (dead weight in the 765-key baseline, ×5 locales):
`tutorial.page1.*`, `tutorial.page2.*`, `tutorial.page3.{headline,bullet1,bullet2,bullet3}`,
`tutorial.{skip,cta.next,cta.get_started}`, and the entire retired language/currency wall
(`onboarding.language.*`, `onboarding.currency.*`, `onboarding.start`, `onboarding.search.*`).

### B.3 Settings has TWO tutorial-restart affordances. One works. One is a latent no-op.

**This is the real finding in Part B.**

**Affordance 1 — "Replay tutorial", `settings.tutorial.replay` (`GeneralSettingView.swift:420–429`). WORKS.**

```swift
UserDefaults.standard.set(true, forKey: OnboardingCoordinator.replayKey)   // :425
hasSeenFeatureTour = false                                                 // :426
RatingPromptCoordinator.resetForTutorialReplay()                           // :427
NotificationCenter.default.post(name: .budgetCrabReplayOnboarding, ...)     // :428
```

`ContentView.swift:280–283` receives it, switches to the Dashboard, and calls `startIfNeeded()`,
whose guard (`OnboardingCoordinator.swift:49`) passes because `replayKey` is set. **Replay is
immediate and does re-run the coach-marks.** It lives in Settings → General → "Tutorial & Sample
Data".

**Affordance 2 — "Restart onboarding", `general.restart_onboarding` (`GeneralSettingView.swift:436–440` → `restartOnboarding()` at `:456–459`). EFFECTIVELY DEAD.**

```swift
private func restartOnboarding() {
    hasCompletedOnboarding = false      // :458 — and that is all it does
}
```

`RootView` reads `hasCompletedOnboarding` (`:11`) but **never branches on it** — `appContent`
unconditionally returns `AuthGateView()` (`:62–68`). The `.animation(…, value: hasCompletedOnboarding)`
at `:69` is vestigial from the deleted gate. And `ContentView`'s `.task` — the only caller of
`startIfNeeded()` — already ran, because Settings is a tab *inside* ContentView.

**Net effect:** the user taps a destructive-styled confirmation alert (`:152–155`) and **nothing
happens**. Onboarding re-runs on the *next cold launch*, with no indication that this is what was
promised. Two buttons, in the same Settings screen, that claim the same thing; one silent.

This is a textbook instance of the "reports success while doing nothing" class already documented in
this project — the button confirms, and the visible outcome is nothing.

**Also dead:** `OnboardingCoordinator.requestReplay()` (`:94`). Settings writes `replayKey` directly;
nothing calls the method. Harmless, but it is the API the working path bypasses.

### B.4 `LearnAndTipsView` — coverage, and overlap with a tutorial

259 lines, free, no premium gate. Reached via Settings → "Learn & Tips" (`SettingsView.swift:62–66`).
Three things in one destination:

1. **Today's tip** + the browsable per-user collection, searchable — scoped to *unlocked* tips only,
   deliberately, so search cannot spoil the daily reveal (`:46–52`).
2. **Progress line** — unlocked/total count, never locked content (`:56–64`).
3. **Eight help articles** in four sections (`:155–172`):
   - *Getting Started* — Quick Add, Voice Entry, Categories
   - *Advanced Features* — Analytics, Widget, Siri
   - *Privacy* — Local Storage, Language change
   - *Contact* — copy email / open in Mail / online FAQ

**Overlap with a tutorial: substantial in content, near-total in the wrong direction.** The eight
articles already say most of what a tutorial would say — `help.siri.body` explains the exact Siri
phrasing, `help.widget.body` gives the Home Screen add procedure, `help.analytics.body` explains all
three Analytics views including the drag-to-scrub interaction. **This is good prose that nobody
finds**, because it is four taps deep in Settings and is itself an undiscovered feature.

**Recommendation for later (not built here):** do not write new tutorial copy for anything an article
already covers. Point at the article. The deficit is routing, not text.

---

### B.5 THE CLASS — every user-facing capability, and how a first-time user finds it

Split discoverability was one instance. Here is the full enumeration, scored on **how a user who was
never told discovers it**.

Legend — **①** on-screen and self-evident · **②** discoverable by ordinary poking (visible control,
unclear label) · **③** only via Help/Settings archaeology · **④ no discovery path at all**

#### Entry

| Capability | Discovery path | |
|---|---|---|
| Quick-add bar (natural language) | Dashboard, plus coach-mark step 1 | ① |
| "+" tab → Quick Entry | Tab bar centre | ① |
| Voice input | Mic in Quick Entry, prominent; **hidden entirely when no on-device recognizer for the app language** (`VoiceInputService.swift:123`) | ① / **④ when hidden** — the user gets no explanation, the button simply is not there |
| Full form (`AddTransactionView`) | "Use detailed form" in Quick Entry + one-shot `InlineHintBubble` | ① |
| **Siri / App Intents / Shortcuts** | **Only** `help.siri` article, 4 taps into Settings. No in-app prompt, no Shortcuts donation surface in the UI. | **④** |
| **Widget** | **Only** `help.widget` article. Nothing in-app mentions a widget exists. | **④** |
| CSV import | Settings → Data → Import | ③ |
| Import column mapping / Mint-YNAB-Monarch presets | Inside the import flow once started | ② |

#### Transactions

| Capability | Discovery path | |
|---|---|---|
| Edit a transaction | Tap row → detail → Edit | ① |
| **Splits** | **FIXED** — `split.add_part` row on every non-split expense detail (`TransactionDetailView.swift:53–74`) + pointer footer on the entry form (`AddTransactionView.swift:308`) | ② (was ④) |
| Recurrence | Toggle in the full form (`AddTransactionView.swift:451`) — invisible to anyone who only uses Quick Entry | ② |
| Recurring prompt / Add-or-Skip | Arrives on its own when due | ① |
| Possible-duplicate review | Badge on the row after an import | ② |
| **Merchant→category learning** | Nothing surfaces it. Categories just start being right. `help.categories.body` mentions it in the last sentence. | **④** — arguably correct as invisible magic, but the *premium value story* is invisible with it |
| **Shake-to-undo last auto-save** | `DashboardView.swift:318` `onShake { undoLastAutoSave() }`, 30-second window. **Zero strings mention shaking.** No hint, no article, no toast. | **④** — the starkest one on this list |
| Swipe-to-delete / context menu | `TransactionsView.swift:601, 612` — standard iOS idiom | ① |
| Search + filters | `.searchable` on Transactions | ① |
| Month pager | Visible ‹ › + one-shot `InlineHintBubble` | ① |

#### Dashboard & analytics

| Capability | Discovery path | |
|---|---|---|
| Safe-to-spend / daily allowance | Dashboard hero | ① |
| Set a budget | Dashboard CTA card + coach-mark step 2 | ① |
| Pace cue | Rendered inline, unlabelled | ② |
| Analytics: Pulse / Breakdown / Horizon | Tab + segmented picker (`AnalyticsView.swift:94`) + coach-mark step 3 | ① |
| Drill-down (tap slice → category detail; tap month → transactions) | **No affordance.** Charts are tappable with no visual cue. `help.analytics.body` explains it. | ③ |
| **Drag-to-scrub on Pulse / Horizon** | **No affordance.** Documented only in `help.analytics.body`. | **④** |
| Tip of the day | Dashboard teaching slot | ① |
| Edge-swipe between tabs | `EdgeSwipeHintView`, first 3 launches | ① |

#### Categories, accounts, settings

| Capability | Discovery path | |
|---|---|---|
| Custom categories / icons | Settings → Categories & Accounts | ③ |
| **Category monthly limits** | Inside a category row, below the fold. Nothing on the Dashboard or in Analytics points at it. | **④** |
| Accounts (Sources) | Settings → Categories & Accounts | ③ |
| Export CSV / Excel / PDF, month or all | Settings → Data | ③ |
| **Proactive alerts** | Settings → Alerts. Also **requires a budget to be set** (`AlertsSettingsView.swift:104` `needsBudgetSection`) — a user without a budget sees a screen that cannot be switched on. | ③, **④ for the precondition** |
| Biometric / passcode lock | Settings → Privacy | ③ |
| Appearance (Light/Dark) | Settings → General | ③ |
| In-app language switch | Settings → General | ③ |
| Demo / sample data | Settings → General → Tutorial & Sample Data, **and** the first-win card | ② |
| Replay tutorial | Settings → General (see B.3) | ③ |
| Learn & Tips hub | Settings row | ③ |
| Premium / paywall | Contextual gates + Settings badge | ① |
| Offer-code redemption | Settings → Premium | ③ |
| Feedback | Settings row | ③ |

#### The **④** list — capabilities with no discovery path at all

> **⚠️ CORRECTED 2026-08-12, same day** (`PROPOSAL_1_0_5_SCOPE.md` §0). Verifying two of these in
> order to propose a fix showed the fix already exists. **The list is SIX, not eight.**
>
> - **~~Voice unavailability~~ — WRONG. The mic never vanishes.** `QuickEntryView.swift:769–773`
>   renders `micButton` unconditionally and shows `quick_entry.voice.unavailable` ("Voice not
>   available for this language") on tap. Fixed by Bug 7. I drew the finding from
>   `VoiceInputService.swift:8` and `:123` — a doc comment and a DEBUG print that both still say
>   *"Mic will be hidden"* and describe pre-Bug-7 behaviour. **A stale comment produced a false
>   audit finding — the fourth instance of that pattern in this project.**
> - **~~Alerts' budget precondition~~ — WRONG, and not a design defect either.**
>   `AlertsSettingsView.swift:104–113` renders a title ("Set a budget first"), a reason, **and a CTA
>   that opens `BudgetSetterSheet` in place** (`:50`). It is already a correctly-built guided
>   precondition.
>
> The remaining six stand as written.

**This is the specification for the tutorial and the hints. Nothing else should be written until
this list is agreed.**

1. **Shake-to-undo** — implemented, 30s window, zero mentions anywhere in the product.
2. **Widget** — a shipped, redesigned, twice-iterated surface that the app never mentions.
3. **Siri / Shortcuts** — headless intents auto-surfaced to the system; the app never says so.
4. **Chart drag-to-scrub** — the primary interaction of two of the three Analytics views.
5. **Category monthly limits** — a 1.0.3 feature buried inside a settings row.
6. **Merchant learning** — the thing that makes the app get better, entirely silent.
7. **Voice unavailability** — when the recognizer is missing the mic vanishes with no explanation.
8. **Proactive alerts' budget precondition** — a settings screen that cannot be turned on, unexplained.

**Ranking, if a build has to pick.** 2, 3 and 5 are *shipped features earning nothing*. 4 makes two
existing screens feel broken. 1 and 6 are delight/retention. 7 and 8 are dead-end states — cheapest
to fix (one honest sentence each) and the most damaging per unit of effort, because a dead end reads
as a bug.

**A structural note that outlives any one hint.** The three coach-marks all target the Dashboard and
the tab bar, because `CoachmarkID` is explicitly scoped to co-located targets
(`CoachmarkID.swift:14–15`) and everything off-Dashboard uses one-shot `InlineHintBubble`s — of which
exactly **two** exist. The hint mechanism is built, proven, localized, and used at 2 of ~8 sites that
need it. **The gap is inventory, not machinery.**

---

### B.6 Flagged strings — the on-device claims that become false when sync ships

You asked me to flag any beyond the five in `DESIGN_ICLOUD_SYNC §2.1`. There are more, and the §2.1
list itself needs a correction.

**§2.1 says "Five keys × 5 locales" and then names four:** `tutorial.page3.bullet1`,
`help.privacy.body`, `onboarding.greeting.privacy`, `about.tell_friend.share`. Count and list
disagree.

**And `tutorial.page3.bullet1` — the one you quoted — is a DEAD STRING.** No view renders it
(§B.2). It costs nothing when sync ships; it should be *deleted*, not rewritten.

**Full sweep of live, rendered strings that assert data does not leave the device:**

| Key | Rendered at | Verdict under sync |
|---|---|---|
| `onboarding.greeting.privacy` — "nothing leaves your phone" | `MascotGreetingView.swift` | **BECOMES FALSE** |
| `help.privacy.body` — "never leaves your device" | `HelpView.swift` | **BECOMES FALSE** |
| `settings.privacy.title` — "Your Data Stays on Your Device" | `PrivacySettingsView.swift` | **BECOMES FALSE** |
| `settings.privacy.subtitle` — "No cloud account. Everything stays on your iPhone." | `PrivacySettingsView.swift` | **BECOMES FALSE** |
| `privacy.claim.no_cloud_account` | `PrivacySettingsView.swift:85` | **BECOMES FALSE** |
| `privacy.claim.no_data_uploaded` | `PrivacySettingsView.swift:86` | **BECOMES FALSE** |
| `paywall.subtitle` — "no servers, no accounts, no tracking" | `PaywallView.swift` | **BECOMES FALSE** |
| `about.privacy_hint` — "No accounts, no servers." | `AboutView.swift` | **BECOMES FALSE** |
| `about.tell_friend.share` — "a private, on-device finance app" | `AboutView.swift` | **BECOMES FALSE** (and it is *outbound marketing copy*) |
| `quick_entry.privacy_chip` — "Stays on your iPhone" | `QuickEntryView.swift` | **BECOMES FALSE** |
| `quick_entry.a11y.privacy_chip` | `QuickEntryView.swift` | **BECOMES FALSE** |

**Ten live keys, not four.** `privacy.claim.no_data_uploaded` and `privacy.claim.no_cloud_account`
were missed by §2.1 entirely and are the sharpest — they are enumerated *claims* on a screen titled
"What we do not do".

**Stays TRUE under sync — do not touch these** (they are about *processing*, not storage):
`help.quick_add.body` (parsing is local), `help.voice_entry.body` (audio never sent to a server),
`quick_entry.listening`, `quick_entry.a11y.mic_hint`, `tutorial.page3.bullet3` (dead anyway).

**Dead, delete rather than rewrite:** `tutorial.page2.caption`, `tutorial.page3.bullet1`,
`tutorial.page3.bullet3`.

Recorded for the sync work; no string was changed by this audit.

---

## PART C — the two committed features, sized honestly

### C.1 REPORTS (backlog #2)

**What already exists.** Not "some export" — a fairly complete set:

| Shipped | Where |
|---|---|
| CSV export, this-month and all-time | `CSVExportService.swift`; `DataSettingsView.swift:116–126` |
| Excel/TSV export, month and all | `TSVExportService.swift`; `DataSettingsView.swift:143–155` |
| **PDF report**, month and all | `PDFExportService.swift`; `DataSettingsView.swift:128–141` |
| Analytics **Pulse** — day-by-day cash flow, drag-to-scrub | `AnalyticsPulseView.swift` |
| Analytics **Breakdown** — category donut + rows, top-5+Other, drill-through | `AnalyticsBreakdownView.swift` |
| Analytics **Horizon** — 12-month net trend, scrub → month sheet | `AnalyticsHorizonView.swift` |
| Category detail, day sheet, month sheet | `Analytics/CategoryDetailView.swift`, `DaySpendingSheet.swift`, `MonthDetailSheet.swift` |
| Frozen-language artifacts (PDF renders in the in-app language) | `PDFExportService.swift:7–14`, pinned by `FrozenArtifactLanguageTests` |

**What the PDF actually is today.** `PDFExportService.swift:105–117` — the "report" is a title, a
range line, **a three-number summary (income, expense, net)**, and then a paginated *transaction
table*. It is a **statement**, not a report. No chart, no category breakdown, no period comparison,
no trend.

**So the honest delta.** The spec in `FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md:28–34` asks for a
Reports *view* with period selector, trend line, top categories, income-vs-expense, net, and export.
Measured against HEAD, four of those five already exist as Analytics screens. **Building a Reports
tab as specified would substantially duplicate Analytics.**

The genuine, non-duplicating delta is three things:

1. **Annual / arbitrary-period scope.** Analytics is hard-scoped: Pulse = this month, Breakdown =
   this month, Horizon = trailing 12 months. There is **no year view and no custom range** anywhere.
   PDF export offers only `.month` and `.all` (`CSVExportScope`). *This is the real feature.*
2. **A PDF that contains the analysis.** Put the Breakdown donut/table and the Horizon trend into the
   PDF — the summary block at `:65` is where they go. Today a user who wants to hand their accountant
   a category breakdown cannot; they get 400 rows.
3. **Period-over-period comparison.** "This month vs last", "this year vs last". Nothing computes a
   delta between two periods anywhere in the codebase. This is the one thing users mean by "reports"
   that has no partial implementation.

**Recommended framing: this is "Annual & comparative reporting + a real PDF", not "Reports".**
Scoped that way it is a delta, reuses `AnalyticsSeries` / `CategoryAttribution` / `Money`, and needs
**no schema change**. Framed as the spec writes it, it is a second Analytics tab and will be judged
against the one that already exists.

**Cost note, since PDF is on the critical path:** `PDFExportService` is hand-rolled `UIGraphicsPDFRenderer`
drawing with manual pagination (`countPages`, per-row `y` arithmetic). Adding charts means rendering
SwiftUI `Chart`s to images via `ImageRenderer` and placing them in that manual layout. That is a real
piece of work, and `ImageRenderer` has known limits already hit in this project (it will not composite
`.thinMaterial` / `.secondary`; it reports blank inside a `ScrollView`).

### C.2 FAMILY / SHARED ACCESS (backlog #9)

**Stating the relationship precisely, because the founder's understanding is half right.**

**True:** the V2 migration made the schema CloudKit-shaped. Concretely — `@Attribute(.unique)` was
removed, every relationship got an inverse, `MerchantCategoryLearning` was split into a second,
non-synced store configuration (`SharedModelContainer.swift:45–58`) precisely so its `.unique` stays
legal. That work is a **hard prerequisite of anything CloudKit**, private or shared.

**Also true:** it is *only* a prerequisite. It is a schema-shape precondition, and it is the **same**
precondition for both. It buys sharing nothing that it does not equally buy private sync.

**Not true:** that the migration was done "for" sharing, or that it gets sharing meaningfully closer.
`DESIGN_ICLOUD_SYNC_1_0_4.md:7–10` excludes sharing by name, at the top of the document, before
anything else: *"Out of scope, named so nobody assumes it: `CKShare` / couples / family sharing (a
genuinely different design — shared zones, participant management, per-record ACLs — and a separate
doc when we want it)."* It is repeated in the non-goals at `:525`.

**The ladder, in order. Nothing below is optional and nothing can be reordered.**

```
   V2 schema shipped ────────────────────────────── DONE (1.0.3, live)
        ↓
   Rollback ladder fixed (A4) ──────────────────── NOT DONE, blocks any further migration
        ↓
   Recurrence watermark → model (§0.1) ─────────── NOT DONE, blocks sync (double-charge)
        ↓
   Private sync working ────────────────────────── DESIGNED, UNBUILT
        ↓
   ═══ everything below is NEW DESIGN, not written ═══
        ↓
   CKShare + shared zone + participant mgmt
        ↓
   Per-record ACLs / scoping model
        ↓
   Usable shared budget
```

**What sits between working private sync and a usable shared budget — sized, not designed.**

*Platform mechanics:*
- **Shared zone architecture.** SwiftData's CloudKit integration targets the private database. A
  shared budget needs records in a shared zone, which today means dropping to `CKShare` /
  `CKRecordZone` and reconciling that with SwiftData's ownership of the store. This is the single
  largest unknown and it is an **architecture** question, not an implementation one.
- **Invitation and participant lifecycle.** `UICloudSharingController`, accept/decline, revoke,
  what happens to a participant's rows when they leave. Every one is a UI surface that does not exist.
- **Per-record ACLs.** Which rows are shared at all? A whole ledger? One account? A category?
  **This is a product decision that has never been made**, and every technical answer below depends on it.

*Consequences in code that already exists:*
- **Conflict resolution is designed for one user on N devices** (`DESIGN_ICLOUD_SYNC §3`). Two
  *people* editing concurrently is a different problem: last-writer-wins on a shared budget silently
  discards a partner's edit. §3.2 (split parent + children) and §3.4 (delete racing an edit) get
  materially worse with a second human.
- **The `uuid`-uniqueness audit (§3.6) grows.** First sync between two devices is already a union
  producing legitimate duplicate `uuid`s. Two *accounts* merging is a bigger union with no shared history.
- **The entitlement gate.** `ReverseTrial.isActive` is unclamped (A5) and per-device, and §4.1
  recommends keeping it per-device. Shared access means deciding whether a participant needs their
  own Premium — a monetization decision with the clock-watermark work (A5) sitting under it.
- **Every privacy string in §B.6 breaks harder.** Private sync makes "stays on your iPhone" false but
  arguably still "yours". Shared access makes it false in the way users actually care about: another
  person can see it. The App Store privacy label re-audit (`APP_PRIVACY_ANSWERS.md §6`) is a
  *mandatory* trigger, and the "Data Not Collected" answer that likely survives private sync is much
  less obviously safe once a second identity is involved.
- **Widget and App Group** (`§5`) assume one user's snapshot. Whose numbers does a shared widget show?

**The estimate, stated as a shape rather than a number:** private sync is one designed release with a
written verification plan. Shared access is **a new design document of comparable size, plus a
product decision on sharing granularity that has not been taken, plus a conflict model for two humans
that does not exist, plus a monetization decision.** Treating it as "sync, then a share sheet" is the
error this section exists to prevent.

**Recommendation (sizing only, not a design):** do not schedule shared access against a release until
private sync has shipped and soaked. The ladder above has two unbuilt prerequisites *before* private
sync even starts, and one of them (A4) blocks every future migration, shared or not.

---

## Appendix — verification method

- Every claim above was checked by reading the file at `4e6a8db`, not by reading a prior document.
  Where a document and the code disagreed, the code won and the document is flagged as stale.
- No build was run: this audit changed no source, so no build result would be attributable to it.
  The last committed state is unmodified.
- **Not covered** (stated so this document's coverage is not overclaimed): the 81 `try?` sites, the
  22 `#Predicate` sites, the widget target beyond its discoverability status, the published
  `budget-crab/PRIVACY_POLICY.html` (different repository), and any claim requiring a physical device.
