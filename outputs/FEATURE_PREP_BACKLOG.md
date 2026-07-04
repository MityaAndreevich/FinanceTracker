# Budget Crab — Feature Prep Backlog (research-grounded)

**Date:** 2026-07-02 · Purpose: prepare (spec-ready, not build-now) the next features, each traced to OUR research + competitor evidence, filtered through local-first constraints, with the recommended build model + Claude Code skill.

**Golden filter (our moat):** every feature must work **on-device, no servers, no bank connection**. That's what makes us different AND keeps us out of Apple 3.2.1(viii). Features that need a backend are flagged.

**Evidence sources:** review mining (4,972 reviews, `review_mining_output/`), NotebookLM (73afc9a4 domain, ff5e0abc UX, 04c87827 ASO), competitor teardown (`RESEARCH_SYNTHESIS_2026-07-02.md`), roadmap (`budget_crab_demand_research_roadmap`).

---

## Priority table

| # | Feature | Demand evidence (ours) | Competitors doing it | Local-first fit | Build model | Skill |
|---|---|---|---|---|---|---|
| 1 | **Photo / receipt input (on-device OCR)** | NotebookLM 73afc9a4: "AI-assisted entry — screenshot/receipt import + NL parsing (LOCAL)" = TOP manual-app request; friction = our #1 churn risk (ff5e0abc) | (aggregators auto-sync instead; few privacy apps do local OCR = our gap) | ✅ Perfect — Apple **Vision** `VNRecognizeText` runs fully on-device | Opus (arch) → Sonnet | /ui-ux-pro-max |
| 2 | **Reports** (monthly/annual, trends, export) | reviews: export_import theme; "reports" requests | Origin "Reports" tab, Copilot cash-flow, Rocket | ✅ All on-device; extends existing CSV/PDF export | Sonnet | — |
| 3 | **Recurring + bill reminders** | reviews: bill tracking; roadmap P1 | Rocket (subscriptions), Origin "Recurring" | ✅ Local notifications, no backend | Sonnet | — |
| 4 | **Budgets / envelopes + safe-to-spend** | NotebookLM: YNAB envelope method most-recommended; feeds redesign hero | Copilot budget rings, YNAB, Rocket "safe to spend" | ✅ Local | Sonnet (Opus if data-model change) | /ui-ux-pro-max |
| 5 | **Widgets + Apple Watch + Siri quick-add** | ff5e0abc: quick-entry = top retention lever; friction #1 risk | MoneyWatch, MOZE, Daily Budget | ✅ Native, no backend | Sonnet | /ui-ux-pro-max |
| 6 | **Natural-language quick add** ("взял пивка на 4 бакса") | NotebookLM: NL parsing demanded; v1.1 AI roadmap | (emerging; Cleo/AI apps) | ✅ Apple **Foundation Models** on-device | Fable/Opus (new framework) | — |
| 7 | **iCloud Sync (private)** | committed v1.0.1; reviews: cloud-shutdown fear → "your iCloud" | Monarch/others (but on THEIR servers) | ✅ CloudKit = user's own iCloud, not our servers | Fable/Opus (arch) → Sonnet | /security-review |
| 8 | **CSV import + Mint migration flow** | reviews: Mint refugees; already premium | (aggregators) | ✅ Local parse | Sonnet | — |
| 9 | **Couples (CloudKit Shared DB)** | NotebookLM: decisive at premium price; reviews 69 rage | Monarch, YNAB Together, Honeydue | ⚠️ Needs CloudKit sharing (still private, no our-server) — P2 | Fable/Opus (sync arch) | /security-review |
| 10 | **Forecasting** (cash-flow projection) | NotebookLM; roadmap P2 | Origin "Forecast", Monarch Plus | ✅ Compute local; AI layer via #6 | Sonnet (Opus if logic complex) | — |

## Sequencing (respects: redesign-before-launch, then retention, then depth)
- **Now (pre-launch, bundled with redesign):** #4 budgets/safe-to-spend (the redesign hero needs it), #5 quick-add surfaces (friction), #2 reports polish. These make the launch screenshots + retention strong.
- **v1.0.1 (fast-follow):** #7 iCloud Sync (committed), #3 recurring+reminders, #8 Mint import polish.
- **v1.1:** #1 photo/receipt OCR (headline differentiator — see detailed spec `SPEC_PHOTO_INPUT.md`), #6 NL quick-add (Foundation Models), #10 forecasting.
- **v1.2 / data-driven:** #9 couples (only if post-launch reviews/support prove decisive demand).

## Why photo input is the headline differentiator (spec ready now)
It hits the intersection of: (a) top demanded feature for privacy/manual apps, (b) our #1 churn risk (friction) directly solved, (c) 100% on-device (Apple Vision) = reinforces the privacy moat, (d) a real gap — aggregators "solve" entry via bank-sync; privacy apps mostly don't offer OCR. Snap → transaction, never leaves the iPhone. Detailed ТЗ: `SPEC_PHOTO_INPUT.md`.

## Dashboard / screen customization (CEO idea 2026-07-02) — v1.1+, DATA-GATED, light-first
**What:** let users choose what shows + order/hide modules ("like iPhone" home-screen/Control-Center customization) — not just categories.
**Honest placement:** NOT pre-launch. Real system (layout model + edit mode + persistence + modular sections) = solo-dev effort; would delay launch. NO demand evidence yet (absent from our 4,972-review mining + Stage-1 search). Risk vs our "simple/fast/calm" wedge (more knobs ≠ calmer; 70% feel anxious). Apple hides customization in edit-mode, never front-and-center.
**Fit:** the redesign already made the dashboard MODULAR (hero/donut/tiles = components) → foundation exists. Strong **Crab Kit** candidate (build a customizable modular dashboard once → reuse across all studio apps = portfolio value).
**Scope when scheduled:** START LIGHT — dashboard "edit mode": reorder + show/hide the dashboard cards, persisted in AppStorage (no SwiftData). Full tab/screen customization = later. **Gate:** only build if post-launch reviews/retention show demand.
**Model:** Opus (layout/persistence architecture) → Sonnet. **Skill:** /ui-ux-pro-max.

## Explicitly NOT building (prevents scope creep — with reasons)
- Bank sync/Plaid (=the #1 pain point + kills privacy + Apple 3.2.1(viii) risk).
- Investment/portfolio aggregation, credit score, estate/tax (over-scope; different category; needs feeds/backend).
- Anything requiring our own server or user accounts.

## How this feeds the App Opportunity Factory
This backlog IS Stage-4 (spec) for Budget Crab. The method (demand → competitor → gap → spec) is reusable per Playbook 09. Each feature above became "spec-ready" only because it traces to counted demand + a competitor gap, not intuition.
