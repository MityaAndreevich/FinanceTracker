# Budget Crab — Feature Prep Backlog (research-grounded)

> ## ⚠️ READ THIS FIRST — two corrections to the document below (2026-08-02)
>
> **1. Row 1 (photo/receipt OCR) is NOT approved and is NOT "the v1.1 headline differentiator".**
> The 2026-07-19 LLM council reviewed that ranking and killed it: *"Receipt/screenshot OCR — n=1 demand, no moat"* (`BRIEF_1_0_3_FEATURE_PACK.md`). Split transactions shipped in 1.0.3 as its **falsifiable pre-test**. The decision rule is pre-registered in **`DECISION_RECEIPT_INPUT_PRETEST.md`** — read that before acting on row 1 or on `SPEC_PHOTO_INPUT.md`. The §"Why photo input is the headline differentiator" section below is **superseded**; it is kept as the record of what was argued on 2026-07-02, not as a live recommendation.
>
> **2. The sequencing below was written pre-launch and is stale.** It assumes iCloud sync ships in v1.0.1 and recurring rides the same wave. Neither is true. See the corrected §Sequencing.
>
> Everything else — the demand evidence, the competitor column, the local-first filter, the "explicitly NOT building" list — still stands.

**Date:** 2026-07-02 (corrections 2026-08-02) · Purpose: prepare (spec-ready, not build-now) the next features, each traced to OUR research + competitor evidence, filtered through local-first constraints, with the recommended build model + Claude Code skill.

**Golden filter (our moat):** every feature must work **on-device, no servers, no bank connection**. That's what makes us different AND keeps us out of Apple 3.2.1(viii). Features that need a backend are flagged.

**Evidence sources:** review mining (**4,904 usable reviews / 15 apps**, `review_mining_output/` — corrected 2026-08-10; the former "4,972" included 68 rows from a wrongly-resolved remittance app), NotebookLM (73afc9a4 domain, ff5e0abc UX, 04c87827 ASO), competitor teardown (`RESEARCH_SYNTHESIS_2026-07-02.md`), roadmap (`budget_crab_demand_research_roadmap`).

---

## Priority table

| # | Feature | Demand evidence (ours) | Competitors doing it | Local-first fit | Build model | Skill |
|---|---|---|---|---|---|---|
| 1 | **Photo / receipt input (on-device OCR)** — 🚦**GATED, council-killed pending the pre-test: `DECISION_RECEIPT_INPUT_PRETEST.md`** | NotebookLM 73afc9a4: "AI-assisted entry — screenshot/receipt import + NL parsing (LOCAL)" = TOP manual-app request; friction = our #1 churn risk (ff5e0abc). **Council 2026-07-19: this is `n=1` observed demand, not counted demand.** | (aggregators auto-sync instead; few privacy apps do local OCR = our gap) | ✅ Perfect — Apple **Vision** `VNRecognizeText` runs fully on-device | Opus (arch) → Sonnet | /ui-ux-pro-max |
| 2 | **Reports** (monthly/annual, trends, export) | reviews: export_import theme; "reports" requests | Origin "Reports" tab, Copilot cash-flow, Rocket | ✅ All on-device; extends existing CSV/PDF export | Sonnet | — |
| 3 | **Recurring + bill reminders** | reviews: bill tracking; roadmap P1 | Rocket (subscriptions), Origin "Recurring" | ✅ Local notifications, no backend | Sonnet | — |
| 4 | **Budgets / envelopes + safe-to-spend** | NotebookLM: YNAB envelope method most-recommended; feeds redesign hero | Copilot budget rings, YNAB, Rocket "safe to spend" | ✅ Local | Sonnet (Opus if data-model change) | /ui-ux-pro-max |
| 5 | **Widgets + Apple Watch + Siri quick-add** | ff5e0abc: quick-entry = top retention lever; friction #1 risk | MoneyWatch, MOZE, Daily Budget | ✅ Native, no backend | Sonnet | /ui-ux-pro-max |
| 6 | **Natural-language quick add** ("взял пивка на 4 бакса") | NotebookLM: NL parsing demanded; v1.1 AI roadmap | (emerging; Cleo/AI apps) | ✅ Apple **Foundation Models** on-device | Fable/Opus (new framework) | — |
| 7 | **iCloud Sync (private)** — now **1.0.4, designed, unbuilt** | ~~committed v1.0.1~~; reviews: cloud-shutdown fear → "your iCloud" | Monarch/others (but on THEIR servers) | ✅ CloudKit = user's own iCloud, not our servers | Fable/Opus (arch) → Sonnet | /security-review |
| 8 | **CSV import + Mint migration flow** | reviews: Mint refugees; already premium | (aggregators) | ✅ Local parse | Sonnet | — |
| 9 | **Couples (CloudKit Shared DB)** | NotebookLM: decisive at premium price; reviews 69 rage | Monarch, YNAB Together, Honeydue | ⚠️ Needs CloudKit sharing (still private, no our-server) — P2 | Fable/Opus (sync arch) | /security-review |
| 10 | **Forecasting** (cash-flow projection) | NotebookLM; roadmap P2 | Origin "Forecast", Monarch Plus | ✅ Compute local; AI layer via #6 | Sonnet (Opus if logic complex) | — |

## ~~Sequencing~~ — STALE, written pre-launch. Superseded by the table below.

<details>
<summary>Original 2026-07-02 sequencing (kept for the record — do not follow)</summary>

- **Now (pre-launch, bundled with redesign):** #4 budgets/safe-to-spend, #5 quick-add surfaces, #2 reports polish.
- **v1.0.1 (fast-follow):** #7 iCloud Sync (committed), #3 recurring+reminders, #8 Mint import polish.
- **v1.1:** #1 photo/receipt OCR (headline differentiator), #6 NL quick-add, #10 forecasting.
- **v1.2 / data-driven:** #9 couples.

Why it went stale: iCloud sync did not ship in 1.0.1 and is still unbuilt; recurring shipped without it; splits (never in this list) shipped in 1.0.3 and became the gate on row 1.

</details>

## Sequencing — corrected 2026-08-02

**Where we actually are:** 1.0.3 is **live** (`MARKETING_VERSION = 1.0.3`, build 7). 1.0.4 is designed but unbuilt.

| Release | State | What it contains |
|---|---|---|
| 1.0.0 | shipped | launch |
| 1.0.1 | shipped | widget redesign, flexible CSV import (Tier 2 column mapping + Mint/YNAB/Monarch presets — row 8, **done**) |
| 1.0.2 | shipped | reverse trial + AccessManager, Learn & Tips hub, proactive alerts, paywall clarity table, possible-duplicate review |
| **1.0.3** | **shipped, live** | V2 schema + guarded migration, relationship audit, daily allowance, **category limits (row 3, partial)**, **split transactions (row 4's cousin — and the pre-test for row 1)**, feedback channel |
| **1.0.4** | **designed, unbuilt** | **#7 iCloud sync (private CloudKit)** — `DESIGN_ICLOUD_SYNC_1_0_4.md`; auto-post recurrence — `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md`; the feedback usage summary (this pass). Sync and auto-post are **coupled**: per-device `recurring.handled.<uuid>` watermarks mean sync would cause double-charges today, so the watermark→model move is a prerequisite **of sync**, not of auto-post. |

**Corrections to the rows above, against the shipped code:**

- **#3 recurring + bill reminders — SHIPPED, not pending.** `RecurrenceService` + `RecurringSettingsView` + gain-framed proactive alerts landed across 1.0.2/1.0.3. What is left is *auto-posting* (1.0.4) and a month-end drift bug (`BRIEF_MONTHEND_RECURRENCE_DRIFT.md`).
- **#7 iCloud sync — moved v1.0.1 → 1.0.4, still unbuilt.** It is the single largest item on the roadmap and it gates row 9.
- **#8 CSV import + Mint migration — SHIPPED in 1.0.1.**
- **#1 photo/receipt OCR — NOT v1.1. Gated.** See `DECISION_RECEIPT_INPUT_PRETEST.md`. Earliest possible build is after that file's first look, and only on a §4.2 pass followed by 10 user conversations.

**What comes after 1.0.4 — deliberately not fixed yet.** Two of the three candidates are gated on evidence that does not exist today, and picking an order now would repeat the mistake this document is being corrected for:

- **#1 receipt OCR** — gated on `DECISION_RECEIPT_INPUT_PRETEST.md`. May resolve to KILL.
- **#9 couples** — gated on the same data. If the split interviews say "I split because I share costs", couples is the correct build and OCR is not.
- **#6 NL quick-add (Foundation Models)** and **#10 forecasting** — ungated, no dependency on the pre-test, and therefore the safe default work if the pre-test comes back negative or unreadable.

## ~~Why photo input is the headline differentiator (spec ready now)~~ — SUPERSEDED 2026-07-19 (council) and gated 2026-08-02

*Kept verbatim as the record of the 2026-07-02 argument. The council's objection was that (a) and (d) below rest on `n=1` observed demand rather than counted demand, and that "a real gap" is not the same as "a wanted feature". Read `DECISION_RECEIPT_INPUT_PRETEST.md` instead.*
It hits the intersection of: (a) top demanded feature for privacy/manual apps, (b) our #1 churn risk (friction) directly solved, (c) 100% on-device (Apple Vision) = reinforces the privacy moat, (d) a real gap — aggregators "solve" entry via bank-sync; privacy apps mostly don't offer OCR. Snap → transaction, never leaves the iPhone. Detailed ТЗ: `SPEC_PHOTO_INPUT.md`.

## Dashboard / screen customization (CEO idea 2026-07-02) — v1.1+, DATA-GATED, light-first
**What:** let users choose what shows + order/hide modules ("like iPhone" home-screen/Control-Center customization) — not just categories.
**Honest placement:** NOT pre-launch. Real system (layout model + edit mode + persistence + modular sections) = solo-dev effort; would delay launch. NO demand evidence yet (absent from our 4,904-review mining + Stage-1 search). Risk vs our "simple/fast/calm" wedge (more knobs ≠ calmer; 70% feel anxious). Apple hides customization in edit-mode, never front-and-center.
**Fit:** the redesign already made the dashboard MODULAR (hero/donut/tiles = components) → foundation exists. Strong **Crab Kit** candidate (build a customizable modular dashboard once → reuse across all studio apps = portfolio value).
**Scope when scheduled:** START LIGHT — dashboard "edit mode": reorder + show/hide the dashboard cards, persisted in AppStorage (no SwiftData). Full tab/screen customization = later. **Gate:** only build if post-launch reviews/retention show demand.
**Model:** Opus (layout/persistence architecture) → Sonnet. **Skill:** /ui-ux-pro-max.

## Explicitly NOT building (prevents scope creep — with reasons)
- Bank sync/Plaid (=the #1 pain point + kills privacy + Apple 3.2.1(viii) risk).
- Investment/portfolio aggregation, credit score, estate/tax (over-scope; different category; needs feeds/backend).
- Anything requiring our own server or user accounts.

## How this feeds the App Opportunity Factory
This backlog IS Stage-4 (spec) for Budget Crab. The method (demand → competitor → gap → spec) is reusable per Playbook 09. Each feature above became "spec-ready" only because it traces to counted demand + a competitor gap, not intuition.
