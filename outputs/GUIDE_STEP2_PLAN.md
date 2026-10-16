# Guide step 2 — GuideDestination routing + journey test

Already on main: the bound Settings path (`c0da729`) and the R1 guard `SettingsStackDeepPopTests`
(commissioned red, §13.7). Step 2 adds the routing and the journey test.

## One entry point (condition 1)
- `GuideRouter` (@Observable, owned by ContentView, in the environment). ONE function:
  `GuideRouter.open(_ d: GuideDestination)`. Every caller goes through it.
- Caller 1 (step 2, DEBUG only): `--guide-route-harness` shows a small corner Menu, one item per
  destination, each item's action = `router.open(d)`. Nothing else. Registered in
  `ReleaseDebugAffordanceTests.debugOnlySymbols`.
- Caller 2 (step 3): the card's Show me button. It is added as a second caller; `open` is not edited
  to accommodate it.
- Why a harness button rather than a launch-time argument: a launch argument fires on the Dashboard
  at launch, so the test could not choose where the journey STARTS. A button can be tapped from
  anywhere, the way Show me will be.
- `open` selects the tab (via `selectTab`), then on the next main-queue hop (the same hop
  `.budgetCrabPendingIntent` uses, so it lands after Settings' tab-leave reset) sets `settingsPath`, or
  sets a one-shot request that the destination screen consumes (Dashboard sheet/focus, Analytics
  picker, Data/Categories scroll target, Transactions search clear).

## Start away from the target (makes "did nothing" fail)
Every case starts somewhere the destination is NOT: Settings tab for non-Settings destinations,
the Dashboard for Settings destinations. Defaults inside a screen are also moved first (below).

## Destination table (condition 2: each proven by an element on the destination itself)

| destination | open does | proven by (identifier on the destination) | start from | red under "all → dashboard"? |
|---|---|---|---|---|
| quickEntry | present Quick Add sheet | `quickEntry.close` (exists) | Settings | yes |
| addForm | present AddTransactionView | `screen.addTransaction` (new, on the form) | Settings | yes |
| **dashboard** | tab 0 | `screen.dashboard` (new, Dashboard root) | Settings | **NO, vacuous**: break by routing to Settings |
| **dashboardQuickAdd** | tab 0 + focus the bar | Quick Add field has keyboard focus (`app.keyboards.count == 1` + field id) | Settings | expected yes (keyboard absent); if it passes, **break by routing to Settings** too |
| dashboardBudget | tab 0 + BudgetSetterSheet | `dashboard.budget.field` (exists, in the sheet) | Settings | yes |
| transactions | tab 1 + clear search | `screen.transactions` + search field empty | type a search on Transactions, go to Settings | yes |
| analyticsPulse | tab 3 + picker = Pulse | `screen.analytics.pulse` (new) | select Breakdown first (Pulse is the default), then Settings | yes |
| analyticsBreakdown | tab 3 + picker = Breakdown | `screen.analytics.breakdown` | Settings | yes |
| analyticsHorizon | tab 3 + picker = Horizon | `screen.analytics.horizon` | Settings | yes |
| reports | tab 4, push .reports | `reports_period_label` (exists) | Dashboard | yes |
| reportsSettings | tab 4, push .reports, .reportsSettings | `reports_monthly_toggle` (exists) | Dashboard | yes |
| alerts / recurring / privacy / premium / general / categoriesAndAccounts | tab 4, push child | `screen.settings.<name>` (new on each root; General may reuse `settings.language.row`) | Dashboard | yes |
| dataImport / dataExport | push .data, scroll to section | section header id **isHittable** (on screen, not merely in tree) | Dashboard | yes |
| categoryLimits | push .categories, scroll to Expense | first expense row id, isHittable | Dashboard | yes |
| feedback | present FeedbackView sheet | `screen.feedback` (new, on our sheet; the sim has no mail account so it shows our fallback) | Dashboard | yes |
| setupSiri | `shortcuts://` if canOpenURL | Shortcuts app `.runningForeground`. **Verify at build** whether the sim has Shortcuts; if not, this case is recorded unprovable in the sim, not silently skipped | Dashboard | yes, if provable |
| guideRoot | — | **step 3** (the Guide root does not exist yet). Added there | — | — |

Also one Settings case starts INSIDE a pushed Settings child (General) to prove the push replaces a
non-empty path.

## Commissioning (condition 3)
1. Mutant A: `open` routes every destination to `.dashboard`. Expect red on every case except
   `dashboard` (and maybe `dashboardQuickAdd`).
2. Mutant B: `open` routes those to Settings (tab 4). Expect red on both.
3. Each red is quoted per destination in STATE. A case that stays green under its mutant blocks the commit.

## Not in step 2
The one-shot highlight pulse (§7 "Highlight") lands in step 3, with the button that triggers it.

## Amendments approved 2026-10-15 (Dmitry)

1. **Harness is not a D51-class overlay.**
   - It sits outside the tab bar and outside the navigation/top-bar areas.
   - Without `--guide-route-harness` it is NOT in the view tree: no hidden or zero-opacity view. It is a small button only, with no full-screen container and no hit-testing layer over content.
   - Guards:
     - `ReleaseDebugAffordanceTests`: absent from Release.
     - A UI assertion: in a DEBUG build launched without the argument, the harness element does not exist.
2. **categoryLimits.**
   - There is no separate "Category Limits" screen. Limits are rows of Categories & Accounts' Expense section; the limit editor is a sheet (`limit.sheet.title`).
   - So the proof is all three of:
     - the Categories root id;
     - an Expense-section id;
     - the first expense row hittable AND scrolled into the upper part of the screen.
   - Mutant C, `categoryLimits → categoriesAndAccounts` (no scroll), must go red. If the Expense section is visible without scrolling at this device size, the position check is what makes it red.
3. **feedback.** The simulator proves the fallback sheet only. The real Mail path is verified on device in the step-6 acceptance. It is NOT presented as proven here.
4. **Suite cost.** Report the added wall-clock time after the first full green run. If it is over 8 min, propose grouping by family (tabs / sheets / Settings pushes / in-screen / external) before step 3. `EXPECTED_TOTAL_RUN` comes from the observed count.
5. **This file is committed** with step 2 (`outputs/GUIDE_STEP2_PLAN.md`), and STATE points to it.

## As built (2026-10-16) — where the build differs from the plan above

- **Harness menu:** a Menu with one submenu per family (tabs / sheets / settings / inScreen /
  external), so no list needs scrolling. A destination missing from every family still appears, under
  "unsorted". It sits bottom-trailing, 140 pt above the bottom edge: above the tab bar, below every
  navigation bar.
- **`reportsSettings` / `reports`:** proven by `screen.settings.reportsSettings` / `screen.settings.reports`.
  On a fresh install the report toggles are Premium-locked rows, so `reports_monthly_toggle` does not exist.
- **Data:** proven by the section's FIRST ROW (`data.import.first` / `data.export.first`), not the header.
  **On iPhone 17 Pro the whole Data list fits one screen, so the scroll cannot be observed.** The
  proof there is "on screen on arrival"; a "no scroll" mutant would stay green. The scroll is
  observable only on a smaller screen or with larger text. Recorded, not claimed.
- **categoryLimits:** the screen id `screen.settings.categories`, plus the Expense section id, plus
  the first expense row's frame lying between the navigation bar and the tab bar and starting in
  the top 40 % of the window. `isHittable` is not used: that row is an HStack with a tap gesture,
  which XCUI does not report as hittable.
- **setupSiri:** the simulator HAS Shortcuts. The case is proven (`com.apple.shortcuts`
  `.runningForeground`), not "unprovable".
- **feedback:** proven by `screen.feedback.fallback` only. The real Mail path (`screen.feedback.consent`
  → Mail) is verified on device in the step-6 acceptance.
- **Starting on Transactions with a search:** the search is typed with Return, which keeps the text and
  ends editing. With the field still active, the next tab-bar tap does not take (the harness's
  `tapTab` reported "tab tap ignored", correctly).

## Commissioning (observed 2026-10-16, iPhone 17 Pro sim)

| mutant | red | green (expected) |
|---|---|---|
| A: every destination → `.dashboard` | 21 of 22 destinations, each with its own message | `dashboard` (vacuous, as predicted) and the harness test |
| B: `.dashboard` → Settings tab | `dashboard`: *"Show me did not land: 'screen.dashboard' is not on screen"* | — |
| C: `categoryLimits` → no scroll work | *"'categories.expense.first' not scrolled to the top (… minY 563.7 …)"* | — |

`dashboardQuickAdd` went red under A (*"the Quick Add field is not focused"*, *"no keyboard"*), so it
needed no second mutant.

## Full run with step 2 (2026-10-16 00:59 → 01:44, `695ee75`, erased sim)

- `executed=1242 passed=1242 failed=0 skipped=9`. Total 1251 against 1245 expected, so exit 5.
  **EXPECTED_TOTAL_RUN 1245 → 1251**; `CHECK_BUNDLE` gives Δ+0, exit 0.
- **Added cost:** `GuideShowMeJourneyTests` took 381.2 s (6.4 min), under the 8-min line, so there is
  no family grouping. The whole run took ≈ 45.5 min, against C3's ≈ 39 min.
- Machine: one xcodebuild in all 89 samples. Swap 5 575 MB at the start, peak 5 974 MB, 4 758 MB at the end.
  The machine was not rebooted.

## Moved to the step-6 acceptance list (Dmitry, 2026-10-16) — recorded, NOT claimed

- **`dataImport` / `dataExport` scroll and the `categoryLimits` scroll on the smallest supported
  simulator (iPhone 16e / SE class)**, where neither list fits one screen. Until that run, the Data
  scroll is unproven, and the categoryLimits scroll is proven at iPhone 17 Pro size only.
- The real Mail path for `feedback` (on device).

## Rule for step 3 (D50-class, Dmitry 2026-10-16)

**No card promises a control the user cannot use on their tier.**
- A card whose controls are tier-gated says so in its copy, and its Show me lands a free user
  somewhere honest: the locked screen, with its upgrade explanation visible.
- Copy must be true in BOTH states: during the 14-day reverse-trial preview (unlocked) and after it
  (locked).

Gated controls found, per card:
- A7: a custom category past 3.
- A8: an account past 2.
- A10: more than 5 scans a month.
- B3: proactive alerts.
- C5: sharing a non-month report.
- D1: CSV import.
- D3: all-time PDF/Excel.
- E2: scheduled reports.

**Open for step 3:** E2's destination (Automatic reports) showed two locked rows and a privacy footer,
with no visible upgrade explanation (screenshot, 2026-10-16). Either the card states Premium before
Show me, or the screen gets a line; check what a tap on a locked row does.
