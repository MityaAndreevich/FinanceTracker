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
| 1 | **Photo / receipt input (on-device OCR)** — 🚦**GATED, council-killed pending the pre-test: `DECISION_RECEIPT_INPUT_PRETEST.md`** · ~~rank~~ **RANK STRUCK 2026-08-13** | ~~NotebookLM 73afc9a4: "AI-assisted entry …" = TOP manual-app request; friction = our #1 churn risk (ff5e0abc)~~ **Both citations failed.** The feature keeps genuine qualitative support: users of manual trackers **do** ask for receipt/screenshot import (CONFIRMED), and on-device OCR **is** valued specifically for privacy (CONFIRMED). What is not in the sources is the **superlative** — and the corpus's one explicit "most common request" statement names **AUTOMATIC BANK SYNC, a feature we have deliberately chosen never to build** (*"The most common request we get is, 'When will you add Plaid for automatic bank sync?' Our answer is always the same: we won't."*). "friction = #1 churn risk" is likewise NOT IN SOURCES. **Council 2026-07-19: this is `n=1` observed demand, not counted demand.** | (aggregators auto-sync instead; few privacy apps do local OCR = our gap) | ✅ Perfect — Apple **Vision** `VNRecognizeText` runs fully on-device | Opus (arch) → Sonnet | /ui-ux-pro-max |
| 2 | **Reports** (monthly/annual, trends, export) | reviews: export_import theme; "reports" requests | Origin "Reports" tab, Copilot cash-flow, Rocket | ✅ All on-device; extends existing CSV/PDF export | Sonnet | — |
| 3 | **Recurring + bill reminders** | reviews: bill tracking; roadmap P1 | Rocket (subscriptions), Origin "Recurring" | ✅ Local notifications, no backend | Sonnet | — |
| 4 | **Budgets / envelopes + safe-to-spend** — **SHIPPED**; ~~rank~~ **RANK STRUCK 2026-08-13** | ~~NotebookLM: YNAB envelope method most-recommended~~ **NOT IN SOURCES** (`73afc9a4`, clean re-ask). "feeds redesign hero" stands — that was a design argument, never a citation. Feature is built and working; **only its evidentiary rank is struck.** | Copilot budget rings, YNAB, Rocket "safe to spend" | ✅ Local | Sonnet (Opus if data-model change) | /ui-ux-pro-max |
| 5 | **Widgets + Apple Watch + Siri quick-add** — widget/Siri **SHIPPED**; ~~rank~~ **RANK STRUCK 2026-08-13** | ~~ff5e0abc: quick-entry = top retention lever; friction #1 risk~~ **Both NOT IN SOURCES.** Also struck: *"widgets = contextual triggers"*. ⚠️ The sources say the **opposite** of the WTP reading used to price this class — widgets are a *"differentiator for retention and willingness to pay"*. See `AUDIT_FREE_PAID_LINE_PREMISES_2026-08-13.md`; **the free widget is NOT clawed back**, but the next native surface (Watch, Live Activity) must not inherit "native surfaces are free". | MoneyWatch, MOZE, Daily Budget | ✅ Native, no backend | Sonnet | /ui-ux-pro-max |
| 6 | **Natural-language quick add** ("взял пивка на 4 бакса") | NotebookLM: NL parsing demanded; v1.1 AI roadmap | (emerging; Cleo/AI apps) | ✅ Apple **Foundation Models** on-device | Fable/Opus (new framework) | — |
| 7 | **iCloud Sync (private)** — now **1.0.4, designed, unbuilt** | ~~committed v1.0.1~~; reviews: cloud-shutdown fear → "your iCloud" | Monarch/others (but on THEIR servers) | ✅ CloudKit = user's own iCloud, not our servers | Fable/Opus (arch) → Sonnet | /security-review |
| 8 | **CSV import + Mint migration flow** | reviews: Mint refugees; already premium | (aggregators) | ✅ Local parse | Sonnet | — |
| 9 | ~~**Couples (CloudKit Shared DB)**~~ **STRUCK 2026-08-13** — see note below | ~~NotebookLM: decisive at premium price; reviews 69 rage~~ **Both citations failed.** See `RESEARCH_FAMILY_ACCESS_2026-08-12.md` | Monarch, YNAB Together, Honeydue | ⚠️ Needs CloudKit sharing (still private, no our-server) — P2 | Fable/Opus (sync arch) | /security-review |
| 10 | **Forecasting** (cash-flow projection) | NotebookLM; roadmap P2 | Origin "Forecast", Monarch Plus | ✅ Compute local; AI layer via #6 | Sonnet (Opus if logic complex) | — |

### Note on rows 1, 4, 5 — ranks struck 2026-08-13

**What is struck is the RANK, not the features.** Rows 4 and 5 are shipped and working; row 1 was
already gated behind a pre-test. Nothing here says any of them was the wrong thing to build. It says
**they were not chosen from evidence**, and the table presented them as though they had been.

Full working: `AUDIT_NOTEBOOKLM_CITATIONS_2026-08-13.md` (64 claims re-asked with conversation
history excluded; 21 not in sources).

**The denominator problem — the single most clarifying fact in the whole demand programme.**

Row 1's superlative failed in an unusually informative way. Asked cleanly which feature manual-tracker
users request most, the corpus does not name receipt scanning. It names **automatic bank sync**:

> *"The most common request we get is, 'When will you add Plaid for automatic bank sync?' Our answer
> is always the same: we won't."*

**The loudest request in this category is one we refuse on purpose.** That is a deliberate,
well-defended position — it is the product. But it has a consequence nobody has written down until
now, and it reaches every number in this programme:

> **Every demand percentage we have measured is measured against a population whose first choice we
> do not serve.**

Sync at 0.28%, shared access at 0.04–0.14%, the 27% price-rage wedge — all of these are shares of a
review corpus dominated by people using bank-linked aggregators. We read low percentages as *"no
demand for X."* They may equally mean *"this population is not our population."* The people who would
most want a manual, local-first, privacy-first tracker are the ones **least likely to be in a corpus
of aggregator reviews at all**, because they never installed one.

This does not invalidate the numbers — the falsifications stand, and *"below a threshold we already
declined to build against"* remains a sound comparison **between** features measured the same way.
What it invalidates is reading any of them as an absolute statement about our market.

**It also makes the support mailbox the highest-value unresolved input we have**, by a wide margin.
It is the only channel that samples *our* users rather than a competitor's. One forwarded inbox is
worth more than another 4,904 competitor reviews, because it is the only evidence not drawn from a
population defined by preferring the thing we refuse to build.

---

### Note on row 9 — struck 2026-08-13. RECORD, do not build.

Row 9 is struck because **both** of its demand citations failed verification. Not weakened — failed.
Full working: `RESEARCH_FAMILY_ACCESS_2026-08-12.md`.

**Why each citation failed.**

- *"reviews 69 rage"* — an artefact of a substring match. The theme tagger matched the word
  **couple**, and **50 of the 69 rows are the English idiom** *"a couple of years / weeks / seconds"*
  (*"I came over here a couple of years ago because Mint dissolved"* — Rocket Money, 1★). Of the ~19
  survivors, roughly 9 are genuinely about sharing, and those are **complaints about broken
  implementations, not requests for one**. The number never measured what it was cited for.
- *"NotebookLM: decisive at premium price"* — this is the fabricated citation. It is not in the
  sources; it was generated in an earlier session and cited back to us as literature. It is the
  subject of the citation sweep, and row 9 is the clearest case of what that costs: **a manufactured
  sentence set a feature's priority in this table for six weeks.**

**Measured demand: 0.04 % – 0.14 %** of 4,904 competitor reviews (bucket A, true unmet demand).
Against the same denominator, device sync measured **0.28 %** and this project ruled that *"no
signal"*. Shared access is **below the bar we already declined to build against.**

**The architectural veto — recorded separately because it does not move with demand.**
Even if demand arrived tomorrow, these are structural, not effort:

- **SwiftData's CloudKit integration targets the private database only.** There is no supported
  SwiftData path to a shared zone.
- **Apple DTS points at `NSPersistentCloudKitContainer` for sharing.** That is a different
  persistence stack from the one this app is built on — a rewrite of the storage layer, not a
  feature.
- **`CKShare` permissions are per-participant on a hierarchy, not per-record.** So
  **per-transaction hiding is not expressible at all.** This kills the obvious product shape ("share
  the budget, keep some rows private") outright — it is not hard, it is unrepresentable. Note that
  the sharing-granularity product decision has never been taken (`AUDIT_BACKLOG_VERIFIED §C.2`);
  this veto removes one of the answers before it can be chosen.

**The distinction worth keeping — this is the usable part of the whole investigation.**

> **A shared LEDGER is nearly conflict-free. A shared BUDGET is conflict-dense.**
>
> - **Shared ledger** = two people *appending* transactions. Inserts union. There is almost nothing
>   to reconcile, because nobody is overwriting anybody.
> - **Shared budget** = two people *editing the same limits*. Under last-writer-wins, the loser's
>   entry changes silently, **with no event** — nothing fires, so nothing can notify them. Our
>   conflict model is designed for one user on N devices (`DESIGN_ICLOUD_SYNC §3`); two humans is a
>   different problem.
>
> These have been treated as one feature. They are not, and they differ by an order of magnitude in
> difficulty. **Goodbudget's happy users describe the first one.**

**Logged as SATISFACTION, not demand — and named as the strongest reason to revisit.**
Goodbudget carries **10.8 % sharing salience (54/500), the highest in the corpus** — ~1.8× the next
app, ~13× Rocket Money — and it is **the only manual-entry envelope app in the corpus**, i.e. the
closest analogue to Budget Crab. **48 of those 54 mentions are praise, not requests.** That is people
enjoying a feature they already have, which is not evidence anyone will ask us for it — it does not
move 0.04–0.14 % anywhere near a build threshold. It is filed here because it is the single fact most
likely to be *right* when the demand numbers are wrong, and because it points specifically at the
**ledger** half.

**Standing caveat.** Every demand number above rests on one channel: competitor reviews.
`support@budgetcrab.app` has still never been read, so "no demand" and "we have not looked" remain
indistinguishable for this row as for every other.

---

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
