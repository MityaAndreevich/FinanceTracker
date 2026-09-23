# DEFECT REGISTER

**Derived 2026-09-12 at HEAD `537e220`.** This file obeys the same rules as `outputs/STATE.md` —
**every row cites a file and a line, and no row was written from memory.**

> ## AUTHORITY — decided 2026-09-22, after the two files drifted on their first update
>
> **This file is the ONLY authority for DEFECT-level facts:** severity, user-reachability, which
> shipped versions carry the defect, whether a regression test exists, and open / fixed / released.
> **`STATE.md` is the authority for PROGRAMME status** (what is decided, which release carries what,
> what is blocked) and, for any defect, **carries a pointer to a row id here — never a restated
> status sentence.** Where a sentence about a defect in `STATE.md` disagrees with a row here, the
> sentence is a drift, this row wins, and the drift gets a `STATE.md` §4 entry.
>
> Why: `STATE.md` rule 1 said *"status lives in STATE.md and nowhere else"* while this file was built
> as a second home for the same status. The founder closed D46 on 2026-09-21 from a device run;
> `STATE.md` §8.2 was updated and this row was not — the two files disagreed on the very first
> update after the register existed. A rule two files both violate is a structural defect, not a
> typo (`STATE.md` §4.9). The fix is one owner per kind of fact, not more care.

---

## HOW TO READ THIS FILE

**`user-reachable?`** means: can an ordinary user, on a build that exists, get to it. It is not a
severity. A defect that is unreachable today can become reachable by a schedule (D4 fires the day a
V2→V3 migration runs; D15 and D16 the day sync ships), and those rows say so.

**`present in`** names *shipped App Store versions*, established by `git merge-base --is-ancestor`
against the release tags — **not by commit date.** The distinction is load-bearing:

**Read `present in` carefully — it names where the DEFECT is, and any fix commit named beside it is
where the PATCH is.** Those are different facts and conflating them inverts the answer. `STATE.md`
§0 Q3 splits them into two columns for exactly this reason, and carries the recorded `git
merge-base` output behind every build claim in this file (`STATE.md` §5).

> **UPDATED 2026-09-21: the currently shipped version is 1.0.5 build 10 — a recorded fact**
> (`STATE.md` §1, App Store lookup). Rows D2, D3, D7–D11 below were re-verified against that and now
> read RELEASED. Every other *"NOT RELEASED"* / *"in review"* phrase in this file was written on
> 2026-09-12 with 1.0.4 b8 as current and is history. New rows D46–D47 at the end of §3.1.
>
> *(2026-09-12 text follows.)* **The currently shipped version is 1.0.4 build 8** — an *inference*, not a recorded fact; see
> `STATE.md` §1, which states the inference and what would settle it.
> **Build 10 contains build 9** (`v1.0.5-build9` is an ancestor of `v1.0.5-build10`, checked
> 2026-09-12), so "fixed in build 9" and "fixed in build 10" are equally out of users' reach today.
>
> **Every fix that landed in build 9 or build 10 is not yet in any user's hands.** Eleven rows below
> are fixed in the tree and still live in the field.

**`regression test?`** is a column because **a defect without one is a defect that can come back
silently.** "No" here is a finding, not an omission.

**`verified`** says where the row's status was last established:
`HEAD 2026-09-12` = re-checked against the working tree or a release tag today.
`doc only` = carried from the cited document and **not** re-verified. Treat `doc only` rows as
claims, not facts — three documents were found stale in this pass (§4 of `STATE.md`, and D-D14/D-D15
below, which were reported as open in August and are fixed).

**Severity** uses the document's own word where it has one. Where it does not, the cell says
`not stated` rather than a severity invented here.

**Shipped versions:** 1.0.0 (2026-07-10) · 1.0.1 · 1.0.2 · 1.0.3 (2026-07-29) · 1.0.4 b8 ·
**1.0.5 b10 = current (available 2026-09-12)** · 1.0.6 b11 = *uploaded 2026-09-21, not submitted*
(`STATE.md` §11). *(Was "1.0.4 b8 = current" until 2026-09-22.)*

---

## 1. FILED DEFECTS — the four that have their own document

| id | title | severity | user-reachable? | present in which shipped versions | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D1** | `VoiceInputService` teardown `abort()`s the process (AVAudioEngine dispose, RPC timeout) | *"this is a process `abort()`, not an exception… a crash with no user-visible cause and no recovery"* (`:5`) | **YES on the code's reading** — *"reachable by opening Quick Entry and closing it"* (`:135`). **Not** claimed to have crashed a real device (`:176`) | **every shipped version** — never fixed, *"Not fixed in build 10"* (`:185`) | **Not a regression test — a known-defect exclusion.** The crashing test is excluded by name and `run-tests.sh` exits 4 on a truncated run (`:196`) | **OPEN**, release hold (`:3`) | `DEFECT_VOICE_INPUT_DEINIT_ABORT.md` | HEAD 2026-09-12 |
| **D2** | CSV import accepts amounts the UI refuses → `Int` overflow traps on the dashboard's first render | *"bricks the app"* (`:91`); *"Silent corruption, in those words"* (`:120`) | **NO longer** — fix is live | **1.0.0 → 1.0.4 b8.** Fixed by `1b6be14`, `c2461b3` — **1.0.5 b10, RELEASED 2026-09-12** | **YES** — `PoisonedAmountLaunchTests` walks cold launch → dashboard unavailable state → Transactions → delete → totals return (`:165–176`); `AmountParsingTests.testLeadingDecimal` caught the fix's own regression (`:192`) | **FIXED in build 10** (`:129`) — **but its own header at `:3` still says *"open… nothing touched"***. See `STATE.md` §4.2 | `DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md` | HEAD 2026-09-12 (tags) |
| **D3** | 1.0.0-era stores stranded on the migration floor (declared V1 carries `isPossibleDuplicate`, added the day after 1.0.0 shipped) | *"Field bug"* (`:1`); terminal — the user's escape was *"deleting and reinstalling, which discards the store"* (`:6`) | **NO longer for anyone who updates to 1.0.5**; a 1.0.0-era store that reaches 1.0.3/1.0.4 first is still stranded there | **Live 1.0.3 → 1.0.4 b8** (`:98`). Fixed by `8c748b7`, **build 9 — RELEASED in 1.0.5 b10, 2026-09-12** | **YES, and proven to fail without the fix** — `PreV1StoreMigrationTests`, 4 tests; with the lift commented out, 2 of 4 fail (`:227–230`) | **FIXED — RELEASED in 1.0.5 b10, 2026-09-12** *(this cell read "NOT RELEASED" until 2026-09-22; the `present in` cell had already been updated on 09-21 — same drift class as §4.9)*. Header at `:3` says *"Not yet committed"* — stale, see `STATE.md` §4.3 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md` | HEAD 2026-09-22 (tags) |
| **D4** | The V2 migration sentinel disconnects the rollback ladder (`Bool` where a schema version was needed) | *"**Severity:** high — affects every shipped 1.0.3 device"* (`:3`) | **NO — latent.** Fires only when a V2→V3 migration runs; V3 has not shipped. *"a prerequisite of **shipping** V3, not a prerequisite of rehearsing it"* (`:26`) | Present in **1.0.3, 1.0.4 b8** and the tree | **No — and it cannot have one on the current seam.** *"The `--fail-migration` seam cannot expose this"* (`:18`) | **OPEN** — *"blocks V3"* (`:5`). Fix = `STATE.md` rows L1–L3 | `DEFECT_V2_MIGRATION_SENTINEL.md` | doc only |

---

## 2. THE OVERFLOW THREAD — 25 fixed, 14 open

| id | title | severity | user-reachable? | present in which shipped versions | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D5** | **14 `Int`-accumulation expressions still trap on an unrepresentable amount** — `AnalyticsSeries` (6), `CategoryDetailView` (2), `DaySpendingSheet` (2), `AnalyticsView` (1), `AnalyticsBreakdownView` (1), `EditTransactionView` (1), `CSVImportService` (1) | *"`AnalyticsSeries` is the one that matters"* (`GO_LIVE_CHECKLIST.md:71`) | **12 of 14 CLOSED in the tree 2026-09-21 (`f2ae0a9`)** — every Analytics-tab site. **2 remain OPEN and reachable:** `EditTransactionView.swift:120` (split validation sum) and `CSVImportService.swift:827` (split-reconstruction gate) — off the Analytics/Reports surface, filed here with that boundary | **every shipped version through 1.0.5 b10**; 12 fixed in the tree, NOT released | **YES for the 12** — `ImportOverflowChainTests.testAnalyticsSeriesReportsOverflowInsteadOfTrapping` / `testCategoryBreakdownReportsOverflowInsteadOfTrapping` (red = a dead runner, host crash reports in `outputs/crash_harvest/2026-09-21/`) and the journey `PoisonedAnalyticsJourneyTests` (red under a five-site mutant). **NO for the 2** | **12 FIXED in tree, 2 OPEN.** The dashboard card's deleted sentence stays deleted until the 2 close | `DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:221–230` · `GO_LIVE_CHECKLIST.md:66–77` | **HEAD 2026-09-12 — re-counted today.** `grep -c addingReportingOverflow` returns **0** in `AnalyticsSeries.swift`, `Analytics/CategoryDetailView.swift`, `Analytics/DaySpendingSheet.swift`, `AnalyticsView.swift`, `Analytics/AnalyticsBreakdownView.swift`. `AnalyticsSeries.swift:92,94` still reads `.income += tx.amountCents` / `.expense += tx.amountCents` |
| **D6** | The dashboard's unavailable card does not NAME the offending row | not stated | YES — a user whose bad row arrived through a mis-mapped import column *"has no way to tell which entry is meant"* (`:218`) | n/a — the card ships in build 10 | n/a | **OPEN** — *"Also filed, not built"* (`:217`); *"Identifying it is a feature, not a copy fix."* | `DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:217–219` | doc only |

> **The rule that binds whoever closes D5** — `:227`: *"**Whoever fixes them applies the same rule** —
> `addingReportingOverflow` and an explicit unavailable state, never a wrapped, saturated, zeroed or
> widened number. Widening is not a fix: `Int128` overflows too, it only moves the cliff."*
>
> **And the copy that depends on it** — the sentence *"Every other screen works normally"* was deleted
> in all five languages and **may only be restored once D5 is closed** (`GO_LIVE_CHECKLIST.md:74`).

---

## 3. UNFILED — described in an AUDIT/BRIEF document, never filed as a defect

These are the dangerous ones: real code defects that existed only inside a document written about
something else. **The first four are user-reachable in the version people have installed today.**

### 3.1 Reachable in the version that was current on 2026-09-12 (1.0.4 build 8) — all five since RELEASED fixed in 1.0.5 b10

| id | title | severity | user-reachable? | present in which shipped versions | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D7** | **`idTBD` in the App Store URL — "Rate the app" and "Share" land on an App Store error page** | not stated; *"One-line fix"* (`:51`) | **NO longer** | **1.0.0 → 1.0.4 b8.** Fixed in **1.0.5 b10** | **YES since 2026-09-21** — `AppStoreLinkTests` (`8e52013`) pins `id6784424678`, commissioned red with the competitor ID | **RELEASED 2026-09-12** | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:48` | **HEAD 2026-09-12.** `v1.0.4-build8:…/AboutView.swift:57` = `…/idTBD`; HEAD `:59` = `…/id6784424678` |
| **D8** | **"Restart onboarding" in Settings is a silent no-op behind a destructive confirmation alert** | not stated | **NO longer** — the control is gone | **through 1.0.4 b8.** Removed in **1.0.5 b10** per `PROPOSAL_1_0_5_SCOPE.md:103` (`git grep restartOnboarding v1.0.5-build10 -- FinanceTracker` → 0) | **No** — and its sibling `requestReplay()` had *"a **passing** test that exercised a path the app never takes"* (`AUDIT_TEST_REACHABILITY_2026-08-13.md:5`) | **REMOVED — RELEASED in 1.0.5 b10, 2026-09-12** *(cell read "NOT RELEASED" until 2026-09-22)* | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:299`, `:312–314` | **HEAD 2026-09-12.** `restartOnboarding` present in `v1.0.4-build8:…/GeneralSettingView.swift:154`; **zero** grep hits in `FinanceTracker/` at HEAD |
| **D9** | **Month-end recurring series drifts off month-end permanently** (Jan 31 → Feb 28 → Mar 28 → …) | not stated | **NO longer** | **1.0.0 → 1.0.4 b8**; fixed in **1.0.5 b10** | **YES** — `RecurrenceMonthEndDriftTests` (5 tests) | **RELEASED 2026-09-12** | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:54–62` · `BRIEF_MONTHEND_RECURRENCE_DRIFT.md:24` | **HEAD 2026-09-12.** `nextDate(after:anchor:)` with `min(anchorDay, daysInMonth(of: last))` exists at `RecurrenceType.swift:119–128`; **absent from `v1.0.4-build8`** (`grep -c "anchor: Date"` = 0) |
| **D10** | **PDF export clips amounts silently** (fixed-width amount column, no paragraph style) | not stated | **NO longer** | **1.0.3, 1.0.4 b8** (three shipped versions with zero tests); fixed in **1.0.5 b10** | **YES** — `f7dde93`, `891bcb1` render real PDFs and read pixels back | **RELEASED 2026-09-12** | `git log f7dde93`, `891bcb1`, `c8bea4f` | HEAD 2026-09-12 (tags) |
| **D11** | **`ReverseTrial.isActive` unclamped — a rewound device clock restores premium indefinitely** | *"unbounded, not one fortnight"* (`OVERNIGHT_2026-08-05.md:292`) | **NO longer** | present through 1.0.4 b8; fixed in **1.0.5 b10** (tag's `ReverseTrial.swift:58`) | **YES now** — `AccessManagerTests.swift:143` *"A rewound clock can no longer revive an expired trial"* (the earlier non-discriminating test is at `:120`) | **RELEASED 2026-09-12** | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:132–135` · fix scoped `PROPOSAL_1_0_5_SCOPE.md:494` | **HEAD 2026-09-12.** `ReverseTrial.swift` now documents *"never earlier than the latest date it has ever seen"* |

#### 3.1b Filed 2026-09-21 — reachable in 1.0.5 b10

| id | title | severity | user-reachable? | present in which shipped versions | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D46** | **Music / podcast does not resume after a voice entry** — and `cleanup()` also deactivated a session it never activated when Quick Entry closed without dictation (`DEFECT_VOICE_INPUT_DEINIT_ABORT.md` §8.3); the controller's `release()` is a no-op unless it activated — the one `setActive(false, options: .notifyOthersOnDeactivation)` was under `try?`; the activation call also passed a deactivation-only option | user-experienced: every voice entry while audio plays leaves it paused; the user presses play. Not data-affecting | **YES** — play audio → Quick Entry → dictate → close. (Open/close without speaking does not touch it.) Confirmed on the founder's iPhone | **every shipped version through 1.0.5 b10** (`git show v1.0.5-build10:FinanceTracker/Services/VoiceInputService.swift` `:321`) | **YES** — `VoiceAudioSessionControllerTests` (retry contract) + `AudioSessionCallSiteGuardTests` (one file, no `try?`), both observed red under mutants | **FIXED in the tree `b3ca3ef`, CONFIRMED ON DEVICE 2026-09-21** — founder, iPhone 14 Pro, Debug build `b3ca3ef`: *"music resumes by itself after a dictated entry"* (`BRIEF_MASTER_2026-09-21.md`, second addendum, item 1). **NOT RELEASED** — ships in 1.0.6 b11 (uploaded, not submitted; `STATE.md` §11). Option B (duck instead of interrupt) proposed, not chosen. *(This cell read "mechanism NOT yet confirmed on device" from 09-21 until 2026-09-22 while `STATE.md` §8.2 said closed — the drift that produced the authority rule at the top of this file)* | `BRIEF_MASTER_2026-09-21.md:95–111`, second addendum item 1 | HEAD 2026-09-22 |
| **D47** | **TSV export flattens a split transaction to one row under the parent category** — the split breakdown is absent, so per-category totals computed in Excel disagree with Analytics for anyone who splits | money-consistency: the Amount column still sums to the ledger; the CATEGORY attribution is wrong for split rows | **YES** — split any transaction, Settings → export Excel, sum by category | **every shipped version through 1.0.5 b10**; fixed in the tree, NOT released | **YES** — `TSVSplitEqualityTests` (file Σ by category == `CategoryBreakdown` == the report), **red first**: Food 12 700 / Home 5 000 / Health 3 000 from the file vs 9 400 / 6 500 / 4 800 in the app | **FIXED in tree `c02b8b0`** (founder's condition for 1.0.6): one row per attributed part, Split and Transaction ID columns appended, first eight unchanged. Stated in What's New | `TSVExportService.swift` header; `ASC_WHATS_NEW_1_0_6.md` | HEAD 2026-09-21 |

| **D48** | **A notification tap only foregrounded the app** — no `UNUserNotificationCenterDelegate` existed; the safe-to-spend alert and recurrence reminders carried no routing | not stated | YES — tap any Budget Crab notification | every shipped version through 1.0.5 b10 | `ReportNotificationSchedulerTests.tapHandOff` (report notifications only) | **FIXED for report notifications in `cff1dbf`** (AppDelegate + App-Group hand-off). **OPEN for the alert and recurrence reminders** — their tap is still a plain foreground; filed, out of 1.0.6 scope | `AppDelegate.swift` header | HEAD 2026-09-21 |
| **D49** | **Siri "Show spending … last month / this year" silently showed this month** — `AnalyticsView` discarded `pendingAnalyticsPeriod` because its screens are fixed windows | not stated | YES — the Siri shortcut with any period but "this month" | 1.0.3 (Analytics redesign) → 1.0.5 b10 | No | **FIXED in tree `cff1dbf`** — those periods now open a report on that period (`ReportPeriod.from(siriPeriodRaw:)`); D24 (English-only phrases) unchanged | `AnalyticsView.swift:235`, `ShowSpendingIntent.swift` | HEAD 2026-09-21 |

| **D50** | **Five shipped teaching strings are false or dead against the build** (claim class, brief §2.8): `help.widget.body` says the widget shows *"this month's net"* (it shows safe-to-spend / over budget / spent); `cs.category.limit_hint` promises *"see how much of it is left"* (no surface shows a remainder); `help.siri.body` quotes a Siri sentence that is not a registered phrase; `add.source.expense_disabled_hint` says accounts are income-only (dead string; accounts attach to both); `tab.add` / `quick_entry.title` name labels that are not on screen (dead) | user-facing copy; no data effect | **YES** — Settings → Learn & Tips / Set up Widget & Siri / Categories & Accounts footer | every shipped version through 1.0.5 b10 and 1.0.6 b11 | No — proposed `GuideClaimTests` (dead keys) in `DESIGN_USER_GUIDE.md` §9; the false-but-live sentences need a copy fix, not a test | **OPEN** — fix scheduled with the User Guide (1.0.7) | `DESIGN_USER_GUIDE.md` §1.3 | HEAD 2026-09-22 (greps and `en.lproj` lines cited there) |

Recorded, not a defect: **the app cannot re-import its own TSV** — `CSVImportService.parsePreview`
sees one column and `prepare` recognises no header (`TSVExportServiceTests.importerDoesNotReadTSV`).
TSV is an Excel hand-off, not an interchange format; the test exists so that this cannot start being
mis-imported silently.

### 3.2 Not user-reachable, or reachable only on a schedule

| id | title | severity | user-reachable? | present in | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D12** | `SeedService:214` — the **category migration** fails invisibly in Release (`print` only) | *"B7 … is the one that matters. It is a category migration whose failure is invisible in Release."* (`:202`) | Yes, silently | through 1.0.4 b8 | No | **OPEN** (scoped `PROPOSAL_1_0_5_SCOPE.md:480` as *"the last silent site worth doing"*) | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:186`, `:202` | doc only |
| **D13** | `DemoSeeder` silently skips an entry (`:381`) and a split set (`:414`) | *"Demo/screenshot paths only — low user risk, real risk to anyone trusting a capture."* (`:204`) | Demo paths only | through 1.0.4 b8 | No | **OPEN** | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:185`, `:204` | doc only |
| **D14** | Four error paths are `print`-only: `TransactionsView:213`, `DuplicateReviewView:184`, `AddCategorySheet:287`, `GeneralSettingView:499` | *"all four have a user-visible alert already. The gap is root-causability from a TestFlight report, not user deception."* (`:206`) | Alert shown; diagnosis lost | through 1.0.4 b8 | No | **OPEN** | `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:194–196`, `:206` | doc only |
| **D15** | AppIntents / Dashboard resolve an **arbitrary recurrence twin**; the shared watermark then silently skips the other | not stated | **Post-sync only** — *"All of it is a blocker to flipping `cloudKitDatabase:` to `.private(…)` in a build that reaches a user."* (`:130`) | latent | No | **OPEN** — gates S1 in `STATE.md` | `AUDIT_UUID_UNIQUENESS_SYNC_1_0_4.md:65–69`, `:77–81`, `:130` | doc only |
| **D16** | Recurrence watermark is **per-device** ⇒ two devices both prompt ⇒ **double charge** | *"both devices prompt, two charges"* (`:46`) | **Post-sync only** | latent | No | **OPEN** — *"**Open decision.**"* (`:52`). Same item as `STATE.md` S1's prerequisite | `AUDIT_UUID_UNIQUENESS_SYNC_1_0_4.md:45–52` | doc only |
| **D17** | Mapped-path import retry **double-imports in both modes** — `.skipDuplicates` only flags, never drops | *"| **Data safety** | **MEDIUM**"* (`:236`) | **YES** — *"and this is the acquisition path, the Mint-migration wedge"* (`:204`) | through 1.0.4 b8, and HEAD | Not stated | **OPEN, and deliberate** — *"This is not an oversight in the code; `:318–320` states the contract deliberately"* (`:206`) | `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md:198–208` | doc only |
| **D18** | Import **cancellation does nothing** — neither loop checks `Task.isCancelled` | not stated | Yes — a cancelled import runs to completion | through 1.0.4 b8, and HEAD | No — *"Untestable on the current path."* (`:97`) | **OPEN** | `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md:95–97` | doc only |
| **D19** | `MAX_ROWS = 10k` cap counts the header row on foreign imports | *"Off-by-one on the cap, not on the data."* (`:101`) | Yes, at 10k rows | through 1.0.4 b8, and HEAD | No | **OPEN** | `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md:98–101` | doc only |
| **D20** | `angularInset: 1.5` yields **negative-width donut sectors** for sub-1% slices | *"One real defect surfaced but is **not** claimed as the cause"* (`:88`) | **YES** — *"Ordinary data produces it (0.12% for a $3 coffee in a $2500 month)"* (`:90`) | through 1.0.4 b8 | `DonutSectorInsetTests`, 22 cases — **all simulator-clean** (`:68`) | **OPEN**, and explicitly not the cause of #22 | `DEVICE_BISECTION_1_0_3_QUICKADD_CRASH.md:88–91` | doc only |
| **D21** | **#22 — 1.0.3 first-QuickAdd crash on device** | not stated | **YES on device** | 1.0.3, 1.0.4 b8 | Not reproduced — *"**NOT REPRODUCED in the simulator. No fix committed.** The device is the arbiter."* (`:3`) | **OPEN** — *"**#22 IS NOT CLOSED.**"* (`AUDIT_BACKLOG_VERIFIED_2026-08-12.md:148`) | `DEVICE_BISECTION_1_0_3_QUICKADD_CRASH.md:3` | doc only |
| **D22** | **StoreKit product IDs may disagree with App Store Connect** (`bc_*` in code/tests/`.storekit`, `ft_*` in the docs) | *"**[P1]**"* (`:32`) | **If ASC holds `ft_*`: catastrophic** — *"zero purchases possible and premium features … permanently locked"* (`:32`) | unknown — **not decidable from this repo** | `PurchaseEntitlementTests` asserts `bc_*`, so code and tests are *"internally consistent"* (`:32`) — which is why the test cannot catch this | **OPEN, needs a human** — *"I cannot see App Store Connect… This needs a human check against live ASC."* (`:88`) | `CODE_REVIEW_FINDINGS.md:32`, `:88` | **HEAD 2026-09-12.** Code (`PurchaseManager.swift:24–25`), tests (`PurchaseEntitlementTests.swift:27–29`) and `FinanceTracker.storekit` all agree on `bc_*`. **The repo half is consistent; the ASC half is unverifiable from here.** |
| **D23** | Two `fatalError`s on container init turn a corrupt store into a **crash loop with no recovery** | *"**[P1]**"*; *"effectively total data loss from the user's perspective"* (`:34`) | **YES** — *"Reachable at runtime (disk corruption, failed schema migration)"* (`:34`) | through 1.0.4 b8 | No | **OPEN** | `CODE_REVIEW_FINDINGS.md:34` | doc only |
| **D24** | Siri / Shortcuts phrases are **English-only in a 5-locale app** | *"**[P1]**"* | **YES** — *"Siri surfaces the app in English regardless of app language."* (`:38`) | through 1.0.4 b8 | No | **OPEN** | `CODE_REVIEW_FINDINGS.md:38` | doc only |
| **D25** | `DashboardView.swift:292` bypasses `Shared/Money.swift` (`String(format: "%.2f", …)`) | *"**[P2]**"*; *"`%.2f` is locale-invariant so it's not a corruption bug today"* (`:42`) | No user-visible defect today | through 1.0.4 b8 | No | **OPEN** — a named `CLAUDE.md` anti-pattern in shipped code | `CODE_REVIEW_FINDINGS.md:42` | doc only |
| **D26** | Stale `.unique` comment at `CSVImportService.swift:679` claims `uuid` is unique; it is not, as of V2 | not stated | No | through 1.0.4 b8 | No | **OPEN** | `AUDIT_UUID_UNIQUENESS_SYNC_1_0_4.md:109–110`, `:127` | doc only |

### 3.3 Defects in the TEST APPARATUS — the ones that make every other row less trustworthy

**These belong in a defect register.** A measurement vehicle that reports success without measuring
is the same class as a feature that reports success without saving, and this project has now shipped
that mistake at both levels.

| id | title | severity | user-reachable? | present in | regression test? | status | document | verified |
|---|---|---|---|---|---|---|---|---|
| **D27** | `BulkDeleteStallMeasurementTests` — **will pass while measuring nothing** once its scroll defect is fixed (looks for a button labelled "Reset Transactions"; the button is "Reset") | *"A measurement vehicle that reports success without performing the operation is worse than one that fails."* (`:367`) | No — test-only | n/a | It **is** the apparatus | **OPEN** — *"Written down, not fixed"* (`:375`). And: *"What is now unknown is whether it has **ever** produced a real measurement."* (`:373`) | `OVERNIGHT_2026-08-05.md:355–375` | doc only |
| **D28** | `RecurrenceService.notificationID`'s twin-sharing property is **load-bearing and pinned by nothing** — replace it with `UUID()` and **88 tests across five suites still pass** | not stated | Consequence is user-visible: *"a user with twin templates gets two reminders for one charge, and cancelling resolves only one"* — and *"Silent — nobody reports a duplicate reminder as a bug"* (`:62–64`) | through 1.0.4 b8 | **No, and no seam exists** — *"There is no seam, so no unit test can observe the identifier."* (`:58`) | **OPEN** — *"**Deliverable is the list. Nothing here is fixed.**"* (`:13`) | `AUDIT_TEST_DISCRIMINATION_2026-08-08.md:51–66` | doc only |
| **D29** | `PlainTextEntryCoverageTests` — three tests **pass on an empty corpus**; `FileManager.enumerator(at:)` returns non-nil for a path that does not exist, so the `XCTSkip` is unreachable | *"It does not even skip — it **passes**."* (`:59`) | No — test-only | n/a | It is the apparatus | **OPEN** | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md:59` | doc only |
| **D30** | `ReleaseDebugAffordanceTests.launchArgumentReadsAreDebugOnly` — vacuous pass on an empty corpus, guarding *"Release ignores every launch argument — several of them wipe data"* | *"This is the highest-consequence member of (a)."* (`:63`) | No — test-only | n/a | It is the apparatus; **its sibling in the same file is guarded** (`:65`) | **OPEN** | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md:63–65` | doc only |
| **D31** | **Four well-tested code paths the app never runs** — `DuplicateReviewService.flaggedCount` (6 tests), `DemoSeeder.hasDemoData` (4), `TipLibrary.search`, `QuickAddSaveService.previewCategory` (6). In the first, *"The one behavioural difference between them is the one thing the tests cannot see."* (`:94`) | *"MEDIUM"* / *"MEDIUM"* / *"LOW–MED"* / *"LOW"* (`:26–29`) | The **shipped** copies are user-facing; the **tested** copies are not | through 1.0.4 b8 | The tests exist and cover the wrong copy | **OPEN** — *"**Nothing is fixed here.**"* (`:3`) | `AUDIT_TEST_REACHABILITY_2026-08-13.md:82–125` | doc only |
| **D32** | **`CSVImportActor` — the orchestration the app actually runs — has zero test references.** Nine test files exercise `CSVImportService`, which the app does not run | *"**HIGH**"* (`AUDIT_TEST_REACHABILITY_2026-08-13.md:24`) | The untested path **is** the shipped path | through 1.0.4 b8, and HEAD | **NO** | **OPEN** — scheduled as the first item after 1.0.5 (`STATE.md` C1) | `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md:107` · `PROPOSAL_1_0_5_SCOPE.md:591` | **HEAD 2026-09-12.** `grep -rn CSVImportActor FinanceTrackerTests/` → **one hit, a comment** (`SaveFailureReachabilityProbe.swift:151`) |
| **D33** | `wipeLedger` is a **45 764 ms main-thread block** and now the live cause of a recurring UI-suite red | *"It is not a race that sometimes loses — it is a race that cannot be won"* (`:98`) | **No** — DEBUG-only; *"`--seed-large-dataset` is **absent from the Release binary's symbols**. No user can reach this path."* (`:240–242`) | DEBUG builds only | **YES** — `PurgeCostMeasurementTests.test_wipeLedgerCost_at8kRows` | **OPEN** — *"Still not fixed, and deliberately not fixed here"* (`:195`) | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:89–98`, `:222–224` | doc only |
| **D34** | `scripts/capture-store-fixture.sh` **erases a simulator by name without asking** and leaves it non-pristine | *"Anything else using that simulator — a staged repro, a run in flight — is destroyed silently."* (`:254`) | No — tooling | n/a | n/a | **MITIGATED by documentation only** — *"The same warning is now in the script's header"* (`:274`) | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:254–275` | doc only |
| **D35** | One UI-suite failure **nothing explains** — `BreakdownOtherExpandTests.test_otherRow_expands_andTailCategoryDrillsDown`, on the working arm, where this brief's mechanism cannot apply | not stated | No — test-only | n/a | n/a | **OPEN** — *"Recorded rather than absorbed"* (`:205`) | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:201–205` | doc only |

---

## 4. CLOSED — verified fixed today, and recorded so nobody re-opens them from a stale document

The documents describing these still read as open. **Three of them were ranked high-value by the
sweep that produced this register, and re-checking killed them.** That is the method working, and it
is the reason `verified` is a column.

| id | title | the document still says | actually | verified |
|---|---|---|---|---|
| **D36** | `deleteAll` swallows its save error and dismisses the sheet as if it worked | *"it propagates the error; `DuplicateReviewView.perform` swallows it into a `#if DEBUG` `print` and **dismisses the sheet**; nothing calls `rollback()`"* — `MEASUREMENT_BULK_DELETE_CURVE.md:60–68` | **FIXED, and already shipped in 1.0.4 build 8.** `DuplicateReviewView.swift:170` dismisses only on success; `:182` raises `showActionFailed`; `DuplicateReviewService.swift:40` calls `modelContext.rollback()`. All three present in `v1.0.4-build8`. The poisoned-context half of the claim was separately withdrawn (`AUDIT_BACKLOG_VERIFIED_2026-08-12.md:102–106`) | HEAD + tag, 2026-09-12 |
| **D37** | Bulk-delete freeze — 49 s at 8 000 flagged rows | `MEASUREMENT_BULK_DELETE_CURVE.md:17–18` | **FIXED** — *"After the quadratic `save()` fix (`a487658`), end-to-end bulk delete is **2.87 s**"* (`:213`). Residue recorded, not scheduled (`:217`) | doc, `:213–217` |
| **D38** | B1 / B2 / B3 — Release-silent account creation, offer-code redemption, legacy-store migration | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md:97–99` | **FIXED** — `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:180–182` | doc |
| **D39** | B4 / B5 — debug seams reporting failure only to `print` | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md:122` | **FIXED** — `AUDIT_BACKLOG_VERIFIED_2026-08-12.md:183–184` | doc |
| **D40** | `xcodebuild -only-testing` reports `** TEST SUCCEEDED **` on zero matched tests | `AUDIT_SILENT_SUCCESS_CLASS_2026-08-09.md:134`, `:139` | **GUARDED** — `scripts/run-tests.sh`, proven against a negative control: *"`xcodebuild` reported success on that run. The wrapper did not."* (`:159–166`) | doc |
| **D41** | "Import failed" shown after a partial commit | `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md:210–220`, severity *"**HIGH**"* (`:237`) | **FIXED in 1.0.5** — *"the disclosure half is BUILT (1.0.5)"* (`:5`). **RELEASED in 1.0.5 b10, 2026-09-12** *(read "NOT RELEASED" until 2026-09-22 — fifth stale-open cell of the §4.9 sweep)* | doc + `STATE.md` §1 |
| **D42** | P0 — headless AppIntent crashes on a locked device, losing the transaction | `CODE_REVIEW_FINDINGS.md:24` | **FIXED** — *"`URLFileProtection.complete` → `.completeUntilFirstUserAuthentication`"* (`:27`) | doc |
| **D43** | Shipped string `cs.category.secondary_label` described a control that no longer exists | `AUDIT_ISPRIMARY_BEFORE_V3_2026-08-13.md:47–50` | **FIXED in that pass** (copy only) | doc |
| **D44** | `purgeIfLeftOver` ran after the demo seed and deleted it | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:71–73` | **FIXED** (`:219–221`) — but it uncovered D33, which is the live cause now | doc |
| **D45** | `String(localized:)` ignores the in-app language override — 35 sites | `OVERNIGHT_2026-08-05.md:150`, `:483` | **FIXED** at `9b9d8c5`, and pinned by `LocalizedCallSiteGuardTests`. *(Carried from memory `project_localized_string_bundle_rule`, **re-verified**: the guard test exists.)* | HEAD 2026-09-12 |

---

## 5. UNRESOLVED POINTERS

| what | problem | evidence |
|---|---|---|
| *"The 25-vs-2 artifact"* | A precedent named by the founder whose write-up **could not be located in `outputs/`**. *"an unlocatable precedent is exactly the kind of claim this project's citation protocol exists to catch"* | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:12–14` |
| `DECISION_RECEIPT_INPUT_PRETEST.md` | Cited by six `outputs/` documents; **not in this repo.** Real path is the sibling repo `../budget-crab-internal/working-docs/` | `STATE.md` §4.5 · `.gitignore` (last block) |
| `BRIEF_1_0_3_FEATURE_PACK.md` | Cited as the source of the 2026-07-19 council kill (`FEATURE_PREP_BACKLOG.md:6`); **not present in `outputs/`** | `ls outputs/` |

---

## 6. THIS REGISTER'S BLIND SPOT

**It was built by reading documents, so it can only contain defects somebody wrote down.**

Three consequences, stated so they are not discovered later:

1. **A defect found, fixed, and never written about is absent from this file — and so is a defect
   found and never written about.** The second kind is the dangerous one and this method cannot see
   it. The counter-instrument is `COVERAGE_MATRIX.md`, which reads *code* rather than documents.
2. **`doc only` rows are August claims.** Of the six rows I re-verified at HEAD today, **three had
   changed** (D36 was already fixed and shipped, D9 and D11 are fixed in the tree). By that rate,
   several `doc only` rows above are wrong in the same direction. **Re-verify before acting on
   any of them** — the command is in `STATE.md` §5.
3. **Severity is mostly `not stated`** because most of these defects were described inside documents
   about something else, and a defect described in passing does not get triaged. That is the cost of
   the scatter this register replaces, and it does not go away by having been collected.
