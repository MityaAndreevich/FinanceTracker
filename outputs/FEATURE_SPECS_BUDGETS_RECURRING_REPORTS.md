# Feature Specs — Budgets · Recurring · Reports (spec-ready)

**Date:** 2026-07-02 · Spec-ready ТЗ (convert to Claude Code build briefs when scheduled). Each traces to research + is local-first. Order = priority.

---

## A. Budgets / envelopes  ⭐ PRE-LAUNCH (feeds redesign hero + searched ASO term)
**What:** monthly budget per category (and an optional overall monthly budget) → powers the "safe to spend" hero + per-category progress bars/rings. Envelope-style rollover = later.
**Demand:** NotebookLM (YNAB envelope method = most-recommended); Stage-1 "envelope budget app / cash envelope" SEARCHED; the redesign hero needs a budget to show "safe to spend".
**Local-first:** pure on-device. Needs a `Budget` model (category + month + amount). ⚠️ **SwiftData migration — STOP and report before altering the schema.**
**MVP scope:** set monthly budget per category and/or overall → Dashboard hero shows spent vs budget + $/day safe-to-spend → Analytics shows per-category budget bars (spent/limit, over-budget in `bcWarning`). NO rollover/carryover in MVP.
**Model:** **Opus** (data-model + migration reasoning) → Sonnet (UI). **Skill:** `/ui-ux-pro-max`.
**Acceptance:** set a budget; hero + bars reflect it live; works offline; localized ×5; migration safe (or additive); over-budget uses warning color, not alarm-red everywhere.
**Sequencing:** build alongside redesign P1/P2 (hero depends on it). If timing tight, ship a simple overall monthly budget first; per-category next.

---

## B. Recurring transactions + bill reminders  (v1.0.1)
**What:** user marks a transaction as recurring (frequency + next date) → an "Upcoming" list → a local notification N days before due. Auto-detect recurring from history = later.
**Demand:** review mining (bill/subscription tracking); competitors Rocket Money (subscriptions), Origin "Recurring". Ties to billing-transparency wedge (help users SEE their subscriptions).
**Local-first:** local `UNUserNotificationCenter` reminders + a `RecurringRule` model. No backend. ⚠️ migration — report first.
**MVP scope:** create/edit recurring (amount, category, frequency: weekly/monthly/yearly, next date) → Upcoming list on Dashboard/Transactions → reminder N days before (user-set). Auto-detection later.
**Model:** **Sonnet** (Opus only if the schema change is non-trivial). **Skill:** none.
**Acceptance:** create recurring; upcoming list correct; reminder fires; notification permission handled + localized; fully offline.

---

## C. Reports  (v1.0.1 / v1.1)

> ### ⚠️ SCOPE CORRECTED 2026-08-12 — READ THIS BEFORE THE MVP SCOPE BELOW
>
> Verified against HEAD `4e6a8db` (`AUDIT_BACKLOG_VERIFIED_2026-08-12.md` §C.1).
> **Four of this spec's five MVP bullets already shipped**, as the three Analytics
> screens. Building the MVP as written below would substantially **rebuild
> Analytics**, and would be judged against the version that already exists.
>
> **Already shipped — do not rebuild:**
>
> | Spec bullet | Where it already lives |
> |---|---|
> | spend trend line | `AnalyticsPulseView` (day-by-day, drag-to-scrub) + `AnalyticsHorizonView` (12-month net) |
> | top categories, multi-colour | `AnalyticsBreakdownView` (donut + rows, top-5 + Other, drill-through) |
> | income vs expense, net | `AnalyticsPulseView`; `PDFExportService.computeSummary` (`:105–117`) |
> | export PDF / CSV / Excel | `PDFExportService`, `CSVExportService`, `TSVExportService`; all wired at `DataSettingsView:111–167`, month **and** all-time |
>
> **The verified delta is exactly THREE things. Build these, not a Reports tab.**
>
> 1. **Annual / custom period scope.** Analytics is hard-scoped: Pulse = this
>    month, Breakdown = this month, Horizon = trailing 12 months. There is **no
>    year view and no arbitrary range anywhere**, and `CSVExportScope` offers only
>    `.month` and `.all`. *This is the actual feature.*
> 2. **A PDF that carries the analysis.** Today the "report" is a title, a range
>    line, a three-number summary, then a paginated **transaction table** — a
>    statement, not a report. A user who wants to hand an accountant a category
>    breakdown gets 400 rows. The insertion point is `PDFExportService.swift:65`,
>    right after `drawSummary`.
>    ⚠️ **Cost warning:** `PDFExportService` is hand-rolled `UIGraphicsPDFRenderer`
>    drawing with manual pagination (`countPages`, per-row `y` arithmetic). Charts
>    mean rendering SwiftUI `Chart`s via `ImageRenderer` into that manual layout,
>    and `ImageRenderer` has limits this project has already hit — it will not
>    composite `.thinMaterial` / `.secondary`, and it reports blank inside a
>    `ScrollView`. This bullet is the expensive one; size it separately.
> 3. **Period-over-period comparison.** "This month vs last", "this year vs last".
>    **Nothing in the codebase computes a delta between two periods.** This is the
>    one thing users mean by "reports" that has no partial implementation at all.
>
> **Reframe the feature as "Annual & comparative reporting + a real PDF."** Scoped
> that way it reuses `AnalyticsSeries`, `CategoryAttribution` and `Money`, and
> needs **no schema change**. NOT in 1.0.5.

**What:** richer monthly/annual reports — spend trend over time, category breakdowns, income vs expense, net; export the report to CSV/PDF/Excel (extends existing export).
**Demand:** review mining (export_import theme); competitors Origin "Reports" tab, Copilot cash-flow, Rocket. Also an ASO term ("spending report").
**Local-first:** 100% on-device; extends the existing CSV/PDF/Excel export.
**MVP scope:** ~~a Reports view — period selector (month/year), spend **trend line**, top categories (multi-color), income vs expense, net; "Export report" (PDF summary + CSV data)~~ — **superseded by the three-item delta above.** Reuse the redesign donut + Money.swift formatting.
**Model:** **Sonnet.** **Skill:** none (uses redesign components).
**Acceptance:** view report for a period; export produces correct PDF/CSV; offline; localized; charts use theme tokens (no monochrome red).

---

## Cross-cutting (all three)
- Respect: `defaultCurrencyCode` + `Shared/Money.swift`; no per-view formatters; localize ×5; `ForEach` keyed by UUID; ModelActor for background writes; no 3rd-party libs.
- Any SwiftData schema change → STOP and report before doing it (migration risk).
- Build after / on top of the redesign token system so they inherit the new look.
- Originality guardrail: our own UI + crab/mint; don't clone a competitor's report/budget screen.

## Convert-to-brief checklist (when scheduled)
- [ ] Turn the chosen spec into a Claude Code build brief (English, model per §).
- [ ] Confirm premium-gating per feature (Budgets = likely free core + advanced premium; Reports export-all = premium already).
- [ ] Sequence Budgets with the redesign; Recurring + Reports in v1.0.1.
