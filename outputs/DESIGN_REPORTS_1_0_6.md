# DESIGN — Reports, 1.0.6

**Status: DESIGN, awaiting the founder's approval. No code written.** Brief:
`outputs/BRIEF_MASTER_2026-09-21.md:129–163` (Phase 1). Written 2026-09-21 at HEAD `70f346b`.
Status for this item lives in `outputs/STATE.md` row **RP1**, not here.

Two things are decided by the brief and not re-argued: reports are being built (founder's decision),
and nothing leaves the device. Two things are **proposed and not decided** — the free/premium split
(§9) and two small product choices flagged **DECIDE** in §4 and §6. Everything else is an engineering
choice; where one is arguable the alternative is stated in §3.

---

## 0. What the evidence says, before the design

The brief's rule: every product decision traces to a number. These are the numbers, with their
provenance, and they are weaker than the feature's priority — that is stated so the sizing in §11
can be read correctly.

| question | source | finding |
|---|---|---|
| Do competitors ship periodic reports, and how are they delivered? | notebook `73afc9a4`, fresh conversation 2026-09-21, no `[History]`, negative control ("spending velocity heatmaps") → NOT IN SOURCES | Yes, weekly and monthly, by push + in-app: *"Notifications: Get weekly reports and alerts for fees, upcoming bills, and budget progress"* (PocketGuard); *"monthly spending reports"* (Rocket Money); *"weekly spending recaps"* and comparison across *"both monthly and annual time frames"* (Monarch). Contents named: category and merchant breakdown, income vs expenses, net cash flow. Whether users **ignore** them: NOT IN SOURCES |
| Is there demand in our market? | notebook `e4a8bc88` | **NOT IN SOURCES — and the notebook itself is broken**: *"The notebook sources consist primarily of HTTP error/404 pages and the RevenueCat State of Subscription Apps 2026 report"*. Filed in `STATE.md` §8.7 |
| Is there demand in the competitor review corpus? | `review_mining_output/reviews_20260702_135538.csv`, N = 4,904 (Barri excluded, same denominator as the family research), regex counts run 2026-09-21 | `\breports?\b` **53 (1.08%)**; `summar(y|ies)` 17 (0.35%); weekly/monthly + summary/report/recap 8 (0.16%); "compare … last month/year" **2 (0.04%)**; annual review **0**; custom date range 2 (0.04%); PDF 5 (0.10%). Explicit asks or complaints about reports: **11 (0.22%)**, e.g. Goodbudget *"the report charts are very limited"*, *"What's lacking is the report feature"*; Spendee *"Would love to have widgets for monthly budget summary!"* |
| What do subscription apps gate? | notebook `0e5f6bb9`, fresh, negative control ("charging for dark mode") → NOT IN SOURCES | Exports / historical data as paid: **NOT IN SOURCES**. Only analogue: Cal AI gates *"analytics"* and upsells *"body scan reports"* |
| When should a money app notify? | notebook `a16f8bf7`, fresh, negative control → NOT IN SOURCES | **NOT IN SOURCES** for money apps. Apple's general guidance only: *"make sure your notifications are timely, serve a clear purpose, and deliver meaningful information"* |

**Reading.** Reports are a *standard* feature (every named competitor has one) with a *weak explicit
demand signal* in reviews — 0.22% asks, the same band as sync (0.28%), which this project called "no
signal". Period comparison and annual review, the two things the earlier spec named as the real
delta, have almost no review signal at all (0.04% and 0). None of that argues against building it —
the founder has decided — but it argues for **building the small version that reuses what exists**,
and for not spending the expensive bullet (charts in the PDF) on a first release. The design below
is sized that way, and §11 says what is deliberately left out.

---

## 1. What exists, and what the design reuses

Everything below was read at HEAD `70f346b`; line numbers are from that commit.

| ground | what it gives Reports | constraint it imposes |
|---|---|---|
| `Shared/MonthTotals.swift:32,38,50` | Dashboard's month income / expense / category buckets, overflow-safe, `nil` = unavailable | A month report **must equal these** — so it calls them, never re-sums |
| `Shared/AnalyticsSeries.swift:37,77` | `pulse` (daily net + earned/spent) and `horizon` (12 months) | **The six unguarded sums** (`:31,49,51,53,92,94`, D5). Reports would inherit the trap; §5 fixes it |
| `Shared/CategoryAttribution.swift:119` | `shares(for:)`, Σ shares == parent total by construction | Every category-dimension figure goes through it — never `tx.category` directly |
| `Shared/SafeToSpend.swift:57`, `CategoryLimitPolicy.swift:72` | remaining budget, per-category limit status (month only) | Budget is **monthly** (`monthlyBudgetCents`); week/year/custom reports carry no budget line (§4.3) |
| `Services/LedgerAggregator.swift:80` | `@ModelActor`, scoped fetches off main, DTO boundary (`SafeToSpend.Aggregate`) | Report building runs here; a `ReportSnapshot` is the DTO |
| `Services/PDFExportService.swift:162` `tableLayout`, `:390` `drawSummary`, `:242` entry point; `PDFExportRenderTests` | Column allocator that shrinks the amount font rather than truncating; the ink-diff pixel idiom | **Do not regress.** New sections compose these primitives in a new file; the existing tests stay untouched and must stay green |
| `Services/TSVExportService.swift:18` | whole-ledger / this-month TSV, now tested | Needs a period overload (§7) |
| `Services/ProactiveAlertPolicy.swift:100` `nextFireDate`, `ProactiveAlertScheduler.swift:21` `NotificationScheduling`, `:40` one stable identifier, `ProactiveAlertRefresher.swift:35` coalescing refresh, `AlertsSettingsView.swift` | The whole local-notification shape: weekday+time trigger, `repeats:false` + reschedule on every refresh, entitlement re-check, permission asked only on toggle | Reports notifications are a second instance of this shape, not a new mechanism |
| `AppIntents/ShowSpendingIntent.swift:23`, `ContentView.swift:414` `handlePendingIntentNavigation` | App-Group flag + `.budgetCrabPendingIntent` → ContentView routes | **There is no `UNUserNotificationCenterDelegate` and no AppDelegate** — a tap today just foregrounds the app. §6 adds the delegate |
| `Purchases/FreeTierLimits.swift:52` `AppCapability`, `PaywallComparison.swift:92` | exhaustive `requiresPremium` switch; the paywall table derives from capabilities; row `paywall.compare.row.reports_alltime` = *"All-time PDF & Excel reports"* already sells "reports" as the all-time export | Whatever §9 decides must keep that table honest — a new capability needs a row or an `unshippedCapabilities` entry |
| `Services/RecurrencePeriod.swift:64–90` | a frozen ISO-week calendar (Mon, min 4 days) | Reports use the **user's** week (`Calendar.current.firstWeekday`), not the frozen one — those are identity keys for recurrence, this is display. Stated so nobody unifies them |
| `en.lproj/Localizable.strings` — **759 keys**, `LocaleCompletenessTests.swift:305` | 5 languages, parity-enforced, `pdf.*` (11 keys) | New keys under `reports.*`; the 759 tripwire and its changelog comment move in the same commit |
| `outputs/FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md:46` | *"The verified delta is exactly THREE things. Build these, not a Reports tab."* | No tab. Entry from Settings and from Analytics (§4.1) |

Two gaps found while reading, both relevant: **`AnalyticsView.recomputeBreakdown` (`:351–379`) is an
inline, unguarded copy of the category fold** that `MonthTotals.categorySpendBuckets` does guarded —
Reports must equal Analytics' breakdown, so §5 extracts it. And **the Siri `.lastMonth` period path is
dead** (`AnalyticsView.swift:218–223` discards `pendingAnalyticsPeriod`) — Reports gives it a live
consumer for free (§6.4).

---

## 2. Definitions

- **Period** — one of: **week** (the user's calendar week, `Calendar.current` with its
  `firstWeekday`), **month**, **year** (calendar year), **custom** (an inclusive day range, start ≤
  end, at most 5 years). Identified by any date inside it plus the kind; a custom period by its two
  days.
- **Previous period** — for week/month/year, the one immediately before. For custom, the range of the
  **same number of days** ending the day before `start`. Stated because "last month" for a custom
  Mar 10–Apr 20 is not well defined and the equal-length rule is the one that makes the comparison
  arithmetic honest.
- **Closed period** — for the automatic report: the last period that ended at or before the
  notification's fire date. A weekly report set to Wednesday reports on the week that ended the
  previous Sunday/Saturday, not on a partial week (§6.2).
- **Figure** — an `Int` cents value. **Unavailable** — the state a figure takes when the sum cannot
  be represented; rendered with the existing `dashboard.totals_unavailable.*` copy, never as a number.

---

## 3. Approaches considered

**A — Pure snapshot + a report view + CG-drawn PDF sections (RECOMMENDED, and what §4–§8 specify).**
A `ReportSnapshot` value computed on `LedgerAggregator` from the existing Shared aggregators; one
`ReportsView` presented from Settings and Analytics; PDF sections drawn with Core Graphics
primitives in a new file that composes `PDFExportService`'s allocator; notifications as a second
instance of the proactive-alert shape. No schema change. No Swift Charts in the report.
*Why:* equality with the rest of the app comes by construction (the report *calls* `MonthTotals`);
the PDF stays pixel-testable with the idiom that already exists; nothing touches the two chart views
that carry the open `EXC_BREAKPOINT` (#22).

**B — Make Analytics period-aware and call "Report" = Analytics + export.** Add a period selector to
Pulse/Breakdown/Horizon and an export button. *Why not:* the earlier spec ruled it out (`:74` "do not
rebuild Analytics"); Horizon's semantics are "trailing 12 months", not "a period"; both scrubbable
charts are the surface of #22 and every new rendered mark there is a crash risk (ARCHITECTURE.md
"Deferred BEHIND #22"); and the in-app report would then depend on `ImageRenderer` for PDF, which
this project already found renders blank inside a `ScrollView` and drops `.thinMaterial`
(`FEATURE_SPECS_…:52–62`).

**C — Generate the report in the background at period close (BGTaskScheduler) and attach the PDF to
the notification.** *Why not:* the brief forbids depending on it (`:143–145`); BGTasks are not
guaranteed to run, so "your report is ready" would sometimes be a lie — rule 8.

---

## 4. Screens

### 4.1 Entry points — two, no tab

1. **Settings → Reports** (a `NavigationLink` row in `SettingsView` Section 2, directly after Alerts
   — same notification family, `AlertsSettingsView` is the template). Pushes `ReportsView`.
2. **Analytics toolbar button** (`doc.text.magnifyingglass`, label `reports.open`), presents
   `ReportsView` as a sheet pre-set to the month Analytics is showing. *Rationale:* Phase 3's whole
   premise is that users do not find features that live only in Settings. **DECIDE:** keep or strike
   the Analytics button. Recommended: keep.

### 4.2 `ReportsView`

```
┌──────────────────────────────────────────────┐
│ ‹  September 2026  ›        [Week|Month|Year|Custom]
├──────────────────────────────────────────────┤
│ SUMMARY                                       │
│  Income        + 4 200,00 ₽   ▲ 12% vs Aug    │
│  Expenses      − 3 180,50 ₽   ▼  4% vs Aug    │
│  Net           + 1 019,50 ₽                   │
├──────────────────────────────────────────────┤
│ BUDGET (month only)                           │
│  3 500 budget · 3 180 spent · 319 left        │
│  ▸ 2 categories over their limit              │
├──────────────────────────────────────────────┤
│ WHERE IT WENT                                 │
│  Food          ████████████   1 240  39%      │
│  Home          ██████           620  19%      │
│  …             (top 8 + Other)                │
├──────────────────────────────────────────────┤
│ DAY BY DAY  ▁▂▃▁▅▂▁▁▃▇▂▁ …  (plain bars)      │
├──────────────────────────────────────────────┤
│ LARGEST  5 rows: date · merchant · amount     │
├──────────────────────────────────────────────┤
│ ⋯ toolbar:  Share ▾  PDF · Excel   ⚙ Automatic│
└──────────────────────────────────────────────┘
```

- **Period bar.** A segmented `Picker` (week / month / year / custom) and the `‹ ›` navigator in the
  `PeriodSelector` idiom (`Shared/PeriodSelector.swift`), never forward past today. **Custom** shows
  two `DatePicker`s (start, end); end < start is corrected to start; spans > 5 years are refused with
  `reports.custom.too_long`.
- **Summary** — three figures; the third column is the period-over-period delta: signed cents and a
  percentage. Percentage is **omitted** (not 0%, not ∞) when the previous figure is 0; the cents
  delta is always shown. Deltas use `subtractingReportingOverflow`.
- **Budget** — month periods only, and only when `monthlyBudgetCents > 0`: budget, spent, remaining
  via `SafeToSpend.remainingCents`, and the count of categories over limit via
  `CategoryLimitPolicy`. Week/year/custom: the section is absent, with no explanation line — a
  weekly budget does not exist in this app and the report must not imply one.
- **Where it went** — expense categories via `CategoryAttribution`, top 8 + "Other" (the Analytics
  fold, extracted in §5.2 so the two cannot differ), each with amount and share. Named category
  amounts are identical on every screen; the fold size is a per-screen presentation parameter
  (Dashboard 6, Analytics 5, Reports 8), so "Other" differs by screen while Σ(named) + Other ==
  expense total holds on each — §10.2 tests that identity, not the fold size; bars are plain
  `Capsule`s scaled by share — **no Swift Charts**, so `ChartGuards` and #22 are untouched.
  Tapping a row pushes the existing `CategoryDetailView` for that period only when the period is a
  month (that view is month-scoped); other periods: rows are not tappable.
- **Day by day** — daily net for week/month, monthly net for year, daily for custom ≤ 62 days else
  monthly. Plain bars.
- **Largest** — top 5 expenses by amount, date · merchant-or-category · amount.
- **Unavailable** — if the snapshot is `nil`, the money area is replaced by the existing unavailable
  card copy (`dashboard.totals_unavailable.title/body`, reused verbatim so the sentence is one claim
  in one place). Share stays enabled and produces the PDF/TSV with the same unavailable statement in
  place of the summary (the transaction table still lists rows: the rows are representable, the sum
  is not).
- **Empty** — a period with no transactions renders zeros, not the unavailable card, and the "Where
  it went" section shows `reports.empty.no_expenses`.
- **Loading** — snapshot built off-main; a `ProgressView` in the summary slot for the first build,
  previous snapshot kept on screen during period changes (no flash to empty).

### 4.3 What the screen deliberately does not show

No income-by-category (the app's categories are expense-first; income categories exist but
Analytics does not break income down either — parity over novelty). No merchant table. No forecast.
No year-over-year monthly grid. Each is a plausible later addition and each is a new claim surface.

---

## 5. Data: `ReportPeriod`, `ReportSnapshot`, and the overflow fix

### 5.1 New Shared types (pure, `Sendable`, `Equatable`, no SwiftData)

```swift
enum ReportPeriod: Equatable, Sendable {
    case week(containing: Date), month(containing: Date), year(containing: Date)
    case custom(start: Date, end: Date)           // inclusive days, start ≤ end
    func range(calendar: Calendar) -> Range<Date> // [start, end) at day precision
    func previous(calendar: Calendar) -> ReportPeriod
    func shifted(by n: Int, calendar: Calendar) -> ReportPeriod   // custom: by its own length
    func canShiftForward(now: Date, calendar: Calendar) -> Bool
    var identity: String   // "week:2026-09-14" · "month:2026-09" · "year:2026" · "custom:2026-03-10..2026-04-20"
    func label(locale: Locale, calendar: Calendar) -> String
    static func closed(before fire: Date, cadence: ReportCadence, calendar: Calendar) -> ReportPeriod
}
enum ReportCadence { case weekly, monthly }

struct ReportSnapshot: Equatable, Sendable {
    let period: ReportPeriod
    let incomeCents: Int, expenseCents: Int, netCents: Int, transactionCount: Int
    let previous: Totals?                  // nil when the previous period is unrepresentable
    let comparison: Comparison             // deltas; percent nil on zero base
    let budget: BudgetLine?                // month only, budget > 0
    let categories: [CategoryShare]        // attributed, sorted, top-N + other folded by the VIEW, not here
    let series: [BucketNet]                // daily or monthly nets, zero-filled
    let largest: [LargestRow]              // ≤ 5
}
```

`ReportBuilder.build(input: ReportInput, period:, calendar:, monthlyBudgetCents:) -> ReportSnapshot?`
is a **pure function over DTO rows** (`CategoryAttribution.Row` + a parent-row DTO), so it runs on the
aggregator's executor and in a unit test identically — the `SafeToSpend.makeAggregate` pattern
(`LedgerAggregator.swift:40–77`). `nil` means one of its sums overflowed; it follows the Optional
idiom of `MonthTotals`/`SafeToSpend`/`CategoryLimitPolicy` (three peers) rather than
`PaceMetric.State.unavailable` (one) — stated so the choice is visible.

**Equality by construction.** For a month period, `incomeCents`/`expenseCents` are
`MonthTotals.incomeCents/expenseCents` applied to the same rows; `categories` are
`MonthTotals.categorySpendBuckets`; `series` is `AnalyticsSeries.pulse(...).daily`. For a year,
`series` is `AnalyticsSeries.horizon`-shaped month buckets computed by the same function over the
year's rows. Week and custom use the same functions over their ranges. **§10.2 tests the equalities
anyway** — by construction is an argument, a test is evidence.

`LedgerAggregator.reportSnapshot(period:now:calendar:) async -> ReportSnapshot?` fetches with
`#Predicate { $0.date >= start && $0.date < end }` for the period and its previous period, maps to
DTOs on the actor, calls the builder. Never on the main actor (`LedgerAggregator.swift:5–19` records
why: ~1.0–1.2 s per pass at 12k rows).

### 5.2 D5 — the overflow fix that Reports would otherwise inherit

Brief `:152–155`; register D5. The rule (`DEFECT_REGISTER.md` §2 box): `addingReportingOverflow` and
an explicit unavailable state, never a wrapped, saturated, zeroed or widened number.

| site | change |
|---|---|
| `AnalyticsSeries.pulse` → `PulseTotals?`; `horizon` → `[MonthNet]?` | the six sums guarded; `nil` on overflow |
| `LedgerAggregator.horizonSeries` | returns `[MonthNet]?`; the `?? []` on fetch failure becomes a logged error + `nil` (rule 7: silent failure) |
| `AnalyticsView` | gains one `totalsUnavailable` flag and the unavailable card, swapped in for all three screens the way `DashboardView.swift:252–258` does — the first cross-screen use of that copy |
| `AnalyticsView.recomputeBreakdown:371`, `AnalyticsBreakdownView:86,134` | the fold is **extracted** to `Shared/CategoryBreakdown.swift` (`buckets(rows:) -> [Bucket]?`, `fold(_:maxNamed:) -> (named, otherCents)?`), guarded, used by Analytics, Reports, and — replacing its private twin at `DashboardView.swift:218–241` — the Dashboard donut, so three folds become one |
| `CategoryDetailView:50,64`, `DaySpendingSheet:43,70` | guarded; each view shows the unavailable line in place of its header total |
| `EditTransactionView:120`, `CSVImportService:827` | **NOT in this release** — off the Analytics/Reports surface; filed rows stay open with that boundary stated |

**Claim this makes true, and which may then be restored:** *"Every other screen works normally"* was
deleted from the dashboard card because Analytics trapped (`GO_LIVE_CHECKLIST.md:66–77`). After
§5.2, Analytics and Reports no longer trap — but `EditTransactionView` still can, so **the sentence
stays deleted**. Restoring it is a separate claim needing all 14 closed.

**Commissioning note.** A trapping site cannot be observed "red" by a failing assertion — it crashes
the test process. The red observation for each guard is a scoped `run-tests.sh -only-testing:` run
that exits non-zero with the runner dead, recorded in the commit; then green. The journey test in
§10.3 is the assertion-shaped guard.

---

## 6. Automatic reports — the mechanism

### 6.1 Shape (a second instance of the proactive-alert shape, not a new one)

- **Settings** (`ReportsSettingsView`, reached from the ⚙ in `ReportsView` and from a row under the
  Reports entry): *Weekly report* toggle + weekday `Picker` + time; *Monthly report* toggle + time
  (fires on the 1st). Defaults when enabled: Monday 09:00; 1st 09:00. Keys:
  `reportWeeklyEnabled/Weekday/Hour/Minute`, `reportMonthlyEnabled/Hour/Minute`. Permission is
  requested in `toggled(on:)` only, never at launch (`AlertsSettingsView.swift:139–150`).
- **Policy** (`ReportNotificationPolicy`, pure): `plan(now:, settings:, calendar:) -> [Plan]` — one
  per enabled cadence; `fireDate` via the same `Calendar.nextDate(after:matching:)` primitive as
  `ProactiveAlertPolicy.swift:100`; the notification's period is
  `ReportPeriod.closed(before: fireDate, cadence:)`.
- **Scheduler**: identifiers `budgetcrab.report.weekly` / `budgetcrab.report.monthly`, one pending
  request each, `UNCalendarNotificationTrigger(repeats: false)`, rescheduled on every refresh pass
  (foreground + `didSave`, the existing `ProactiveAlertRefreshScheduler` gets a second `apply`), so a
  language change or a settings change never leaves a stale request. `userInfo = ["reports.period":
  period.identity]`.
- **Body carries no figures.** `reports.notif.title` *"Your weekly report is ready"*,
  `reports.notif.body.format` *"Sep 14 – 20: tap to see where your money went."* The figures for a
  period that has *just closed* cannot be known at schedule time (the period was open then) —
  computing them on open is the only honest form, and it is what the brief specifies. It also keeps
  the frozen-artifact surface to the period label; `FrozenArtifactLanguageTests` gets a case for it.
- **Entitlement** re-checked every pass; lapse cancels both requests (`ProactiveAlertRefresher.swift:171–174`).

### 6.2 What "the period that just closed" means for an odd choice of day

Weekly on Wednesday → the week that ended last Sunday (or Saturday, per `firstWeekday`). Monthly
always on the 1st, so no ambiguity. **DECIDE:** should the monthly report offer a day-of-month
picker? Recommended: no — a report "for August" fired on the 15th of September is confusing, and the
1st is what "monthly report" means in every competitor named in §0.

### 6.3 Tap → report (the missing delegate)

There is no notification-tap routing in the app today (§1). Add:
- `AppDelegate: UIApplicationDelegate, UNUserNotificationCenterDelegate` via
  `@UIApplicationDelegateAdaptor`, set as the center's delegate at launch.
- `didReceive response`: read `userInfo["reports.period"]`, write `pendingOpenReport = identity` into
  `UserDefaults.appGroup`, post `.budgetCrabPendingIntent` — the exact flag-and-post route
  `ShowSpendingIntent.swift:23–35` uses.
- `ContentView.handlePendingIntentNavigation` (`:414–427`) consumes it: presents `ReportsView` as a
  sheet with that period, on whichever tab is showing. A sheet, not a tab switch plus a push, because
  Settings' `NavigationStack` is re-identified on tab change (`:173–180`) and a programmatic push into
  it is the exact presentation-state class this project has debugged twice
  (`project_edit_stuck_edittx_resolved`).
- `willPresent` (app in foreground): show the banner; do not auto-open.
- The alert's existing tap (safe-to-spend) stays a plain foreground — out of scope, filed.

### 6.4 Siri, for free

`ShowSpendingIntent`'s `.lastMonth` / `.thisYear` periods currently reach a consumer that discards
them. With `ReportsView` accepting a `ReportPeriod`, `pendingAnalyticsPeriod` maps to it and the
sheet opens on that period. No new intent, no new phrases (D24 English-only phrases stays filed).

---

## 7. Export

### 7.1 PDF — "carries the analysis, not only a table"

New file `Services/ReportPDFRenderer.swift`, `makeReportPDF(snapshot:rows:currencyCode:) ->
PDFExportResult`. It reuses `PDFExportService`'s page constants, fonts, `tableLayout`, the paginated
transaction table and the footer **as they are**; `makeMonthlyReportPDF` and everything
`PDFExportRenderTests` pins are not modified. New sections, all drawn with Core Graphics — no
`ImageRenderer`, no SwiftUI — because the project has measured that route failing and because CG
rects are what the ink-box idiom can verify:

1. Title + period label + generated-on date.
2. **Summary table** — 3 rows × 4 columns: label · this period · previous period · change. Amounts
   through the same allocator (font shrinks, never truncates; `amountFontFloor` 7 pt).
3. **Budget line** (month only).
4. **Categories table** — Category · Amount · Share · a proportional filled rect (`UIBezierPath`),
   top 8 + Other — the same fold as the screen, so the PDF's "Other" equals the screen's. Row height as the transaction table's.
5. **Transactions table** — the existing one, **included by default for week and month, off by
   default for year and custom** (a 3,000-row year is ~90 pages), with a toggle in the share menu
   (`reports.pdf.include_transactions`). **DECIDE:** the default. Recommended as stated.
6. Unavailable: sections 2–4 replaced by the unavailable statement; section 5 still renders.

Filename `BudgetCrab_Report_<identity>.pdf` (identity has no locale-sensitive characters).

### 7.2 TSV

`TSVExportService.makeTSV(modelContext:period:)` — the same eight columns and the same tests,
filename `BudgetCrab_<identity>.tsv`. Wired to the report's share menu. D47 (splits flattened) is
unchanged by this and stays filed; it is not made worse.

### 7.3 Gating

Share → PDF / Excel from a **month** report: free (`exportPDFMonth`/`exportExcelMonth`, existing).
Any other period: behind `exportPDFAll` / `exportExcelAll` (existing) — the capability's meaning is
"beyond this month", and its paywall label is renamed in §9 to say so.

---

## 8. Settings, strings, usage signal

- `SettingsView` Section 2: `reports.title` row after Alerts.
- New keys (≈40) under `reports.*` and `reports.notif.*`, ×5 languages, `LocaleCompletenessTests`
  tripwire 759 → the new count with a changelog line. Every sentence that describes behaviour
  ("tap to see…", "on the 1st of each month") is checked against the build before the strings land —
  rule 8; the list of such sentences is in §12.
- `FeatureUsageSignals.Feature.reportOpened = "report_opened"` (raw value stable), marked when a
  snapshot is displayed; surfaced in `UsageSummaryBuilder` as one more bucketed line. On-device only.
  This is the alongside-measurement the brief asks for in Phase 3, started here at zero cost.

---

## 9. Free vs premium — PROPOSED, NOT DECIDED

The existing split: month PDF/Excel free, all-time PDF/Excel premium (label *"All-time PDF & Excel
reports"*), weekly safe-to-spend alert premium (`proactiveAlerts`). Evidence for where to put reports
is NOT IN SOURCES (§0); what follows is an **explicit guess to be validated**, framed by
consistency with what the paywall already says.

| option | free | premium | consistency |
|---|---|---|---|
| **P1 (recommended)** | view **any** period in the app; month PDF/Excel | week/year/custom PDF & Excel (existing `exportPDFAll`/`exportExcelAll`, relabelled *"PDF & Excel reports for any period"*); **automatic weekly/monthly report notifications** (new `AppCapability.scheduledReports`, new paywall row *"Weekly & monthly report notifications"*) | mirrors today exactly: viewing is free everywhere (`basicAnalytics`, `fullHistory`), scheduled notifications are premium (`proactiveAlerts`), non-month exports are premium |
| P2 | week + month views, month exports | year + custom views, comparison, all other exports, automatic | gates *viewing* history, which today is free (`fullHistory`) — a new kind of gate, and the one the review corpus complains about most in competitors |
| P3 | everything | nothing new; only existing export gates | no new revenue surface for the most-built feature of the release; the paywall's "reports" row keeps meaning "all-time export" |

**Why P1.** It adds one honest paywall row for the one part of the feature that costs the user nothing
to try (the in-app report) and something to keep (the notification), which is the shape the trial is
built to sell. **Risk to state:** no source says automatic reports convert; the number that would
validate it is the `scheduledReports` toggle rate in the usage summary after one release, which §8
records.

If Dmitry chooses P1, the relabel of `paywall.compare.row.reports_alltime` is a copy change in five
languages and the row stays derived from `.exportPDFAll` (the `excelSharesThePDFGate` test keeps it
honest).

---

## 10. Test plan

Pre-registered. Every guard is observed red before the fix it guards (rule 2); for trap sites, red is
a dead runner in a scoped run (§5.2). Presence assertions only (rule 4). Pixels for PDFs (rule 5).

### 10.1 Pure types
- `ReportPeriodTests`: ranges for week (firstWeekday 1 **and** 2), month, year, custom; `previous`
  incl. equal-length custom; DST transition weeks (America/New_York, Europe/Kyiv); leap day; 5-year
  cap; `identity` round-trips and is ASCII-only; `closed(before:)` for a Wednesday weekly and a
  1st-of-month monthly across a year boundary.
- `ReportBuilderTests`: fixture ledgers → exact figures; comparison deltas (percent nil on zero base,
  sign on decrease); budget line present only for month with budget > 0; categories via
  attribution with a split row (Σ categories == expense total); series zero-filled and equal in
  length to the period's days/months; largest ≤ 5 sorted; **poisoned row → `nil`** (all four period
  kinds).

### 10.2 Equality — the brief's explicit requirement
`ReportEqualityCanaryTests`, over the `SplitCanaryTests` fixture (seeded, splits applied):
- month report `incomeCents/expenseCents` == `MonthTotals.incomeCents/expenseCents(monthTxs)`
- month report categories == `MonthTotals.categorySpendBuckets` and == `CategoryBreakdown.buckets`
  (the extracted Analytics fold)
- month report `series` == `AnalyticsSeries.pulse(...).daily`; earned/spent equal
- year report's monthly buckets == the overlapping months of `AnalyticsSeries.horizon`
- week report totals == filtering the month report's `series` to the week's days
- the PDF summary strings == `Money.format` of the snapshot figures (read back positionally, then
  pixel-verified in 10.4)
- **Negative control**: a mutant that drops the last day of the period must fail the pulse equality.

### 10.3 Journey
`PoisonedAnalyticsJourneyTests` (XCUITest, erased simulator, the `PoisonedAmountLaunchTests` shape):
seed a ledger with `Int.max − 8` and an ordinary row → Analytics: Pulse, Breakdown, Horizon each show
the unavailable card (assert the card's title text **exists**); tap through to a category → header
shows the unavailable line; open Reports → week, month, year, custom each show the card; Share → PDF
produces a file (assert the share row appears with the filename). No trap anywhere on the path.

### 10.4 Render — pixels
`ReportPDFRenderTests`, the `PDFExportRenderTests` idiom (rasterize at 8×, ink-box, ink-diff 0 vs a
reference drawn in an oversized rect): the summary amounts, the previous/change columns, every
category amount, the budget line; a 3-page year PDF with transactions on; the "unavailable" page.
**Locale × currency matrix** (process locale via `-testLanguage/-testRegion`):

| locale | currency | why |
|---|---|---|
| en_US | USD | baseline |
| ru_RU | RUB | NBSP grouping, comma decimal, ₽ suffix — the 1.0.5 defect's locale |
| es_MX | MXN | `$` prefix with a different grouping |
| pt_BR | BRL | `R$` two-character prefix |
| uk_UA | UAH | ₴ suffix, Cyrillic labels widest |
| de_DE | EUR | already in the PDF corpus |
| ja_JP | JPY | **zero-decimal** — `COVERAGE_MATRIX.md` §4 calls this UNSURE; if `Money.format` prints ¥12.34 this run will say so, and that is a finding to file, not to fix here |

Plus the existing `PDFExportRenderTests` and `PDFExportLayoutTests` **unchanged and green** — the
no-regression guard the brief names.

### 10.5 Notifications
`ReportNotificationPolicyTests` (pure: fire dates, closed period, no digits in the body — assert the
body matches the template with the label only); scheduler: two identifiers, replace-not-accumulate,
lapse cancels; `FrozenArtifactLanguageTests` case for the body under `withRussian`; tap routing:
flag written → `ContentView` presents the sheet with the right period (unit-level via the flag
consumer; UI-level in 10.3's suite with a launch argument that pre-writes the flag).

### 10.6 Suite bookkeeping
Full run from an erased simulator at the end of the phase; compare against the known-failure set in
`GO_LIVE_CHECKLIST.md` §0 (two known reds); harvest `EXPECTED_TOTAL_RUN` only from an exit-5/0
unfiltered run (`STATE.md` §7).

---

## 11. Release cut and sizing

- **1.0.6 = Phase 0 (shipped in tree) + Reports as specified above.** No schema change, no
  migration, no CloudKit.
- Relative cost, largest first: (1) PDF sections + pixel tests; (2) D5 fix across 13 sites +
  journey test; (3) ReportsView; (4) notifications + delegate; (5) period/snapshot types. The first
  two are the ones the earlier spec warned about and they are also the two that carry money
  correctness — they are not the ones to cut.
- **Deliberately out**: charts in the PDF (§3-A), income by category, merchant table, forecast,
  year-over-year grid, monthly report day picker (§6.2), the safe-to-spend alert's own tap routing,
  `EditTransactionView`/`CSVImportService` overflow sites (§5.2), D47.

---

## 12. What's New — 1.0.6 (en-US draft; four translations after the build proves each sentence)

Every sentence below is a claim (ARCHITECTURE.md). The bracketed test is what proves it before the
text is submitted; a sentence whose test is not green is deleted, not softened.

```
New: Reports. Pick a week, a month, a year or your own date range and see
where your money went — income, expenses, what changed since the previous
period, and your biggest categories. [ReportBuilderTests, ReportEqualityCanaryTests]

Share any report as a PDF with the analysis on the first page, or as an
Excel file. [ReportPDFRenderTests, TSVExportServiceTests]

Turn on a weekly or monthly report and Budget Crab will remind you when
the period closes — tap the notification to open it. Nothing leaves your
phone: reports are built on your iPhone when you open them.
[ReportNotificationPolicyTests, PoisonedAnalyticsJourneyTests tap case; the privacy sentence is
true today and is re-read at the sync gate, GO_LIVE_CHECKLIST §0b]

Also fixed: music and podcasts resume after you dictate an entry.
[VoiceAudioSessionControllerTests — AND the device confirmation in STATE.md §8.2; if that run is
not done, this sentence is deleted]

Also in this release:
• Analytics no longer stops working on a ledger with an amount it cannot add up — it says so
  instead. [PoisonedAnalyticsJourneyTests]
• Excel export dates are always plain year-month-day. [TSVExportServiceTests]
• Wording and translation fixes across all five languages.
```

Not claimed: anything about D1 (voice teardown abort), D47, the 14th overflow site.

---

## 13. Open items for the founder — the whole list

1. **§9 free/premium**: P1 / P2 / P3.
2. **§4.1** Analytics toolbar entry point: keep or strike.
3. **§6.2** monthly report day-of-month picker: no (recommended) / yes.
4. **§7.1** transactions table default in year/custom PDFs: off (recommended) / on.
5. Approve §3-A, or send it back.

Nothing in this document is built. STOP.
