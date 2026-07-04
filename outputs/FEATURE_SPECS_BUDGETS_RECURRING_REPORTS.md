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
**What:** richer monthly/annual reports — spend trend over time, category breakdowns, income vs expense, net; export the report to CSV/PDF/Excel (extends existing export).
**Demand:** review mining (export_import theme); competitors Origin "Reports" tab, Copilot cash-flow, Rocket. Also an ASO term ("spending report").
**Local-first:** 100% on-device; extends the existing CSV/PDF/Excel export.
**MVP scope:** a Reports view — period selector (month/year), spend **trend line**, top categories (multi-color), income vs expense, net; "Export report" (PDF summary + CSV data). Reuse the redesign donut + Money.swift formatting.
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
