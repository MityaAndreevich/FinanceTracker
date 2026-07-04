# NotebookLM Research Queue — Budget Crab

Run in **Claude Code** (`notebooklm` CLI). Each task: notebook → command → query → decision it unblocks.
Fold results back into `outputs/DEMAND_RESEARCH_AND_ROADMAP_2026-07.md` §1 and the relevant memory file.

Notebooks: `de492776` iOS/Apple · `04c87827` ASO/Marketing · `73afc9a4` Finance domain · `0e5f6bb9` Pricing · `ff5e0abc` UX.

---

## P0 — unblocks positioning + roadmap (do first)

**1. Demand primaries (upgrades web-tier §1 to cited)**
```bash
notebooklm use 73afc9a4
notebooklm ask "Rank the most-requested features and the top complaints for personal finance / budgeting apps 2024-2026. Give frequency/prevalence data and cite each source. Separate manual/privacy-first apps from bank-aggregator apps."
```
→ Replaces directional web signals with primaries. Confirms/reorders the demand table.

**2. Pricing model validation (answers cheaper-vs-freemium)**
```bash
notebooklm use 0e5f6bb9
notebooklm ask "For indie finance/subscription apps: does a generous free tier + low paid price outperform a higher premium price on install→paid conversion, LTV, and retention? Give evidence, conversion benchmarks, and any cases where price-war positioning failed."
```
→ Validates or breaks the §2 verdict (privacy-first + generous free + price-as-proof).

**3. Friction UX (validates P0 roadmap)**
```bash
notebooklm use ff5e0abc
notebooklm ask "What quick-entry UX patterns measurably reduce logging abandonment in manual expense trackers? Cite retention impact of widgets, Apple Watch, Siri/shortcuts, and one-tap add."
```
→ Confirms quick-add is the right #1 retention investment.

---

## P1 — acquisition + submission de-risk

**4. ASO for privacy/manual niche**
```bash
notebooklm use 04c87827
notebooklm ask "Highest-converting ASO keywords, title/subtitle patterns, and ad hooks for privacy-first / no-bank-link / manual budgeting apps. Include search-volume or difficulty data if available."
```
→ Feeds the ASO/metadata brief (pair with /aso skill).

**5. Zero-budget channels (the GTM piece you deferred)**
```bash
notebooklm use 04c87827
notebooklm ask "Which zero-budget acquisition channels have documented traction for solo indie finance apps (Reddit, Product Hunt, ASO, organic short-form/Reels)? Rank by evidence and give real case studies with numbers."
```
→ Builds the GTM channel plan on cases, not vibes.

**6. Apple Review risk (before submit)**
```bash
notebooklm use de492776
notebooklm ask "App Review risk factors for finance apps: subscription disclosure requirements, free-trial/intro-offer configuration, privacy nutrition labels, and StoreKit rejection patterns. What causes finance-app rejections?"
```
→ De-risks the submission (ties to the 7-day intro offer we just configured).

---

## P2 — strategic + retention

**7. Couples demand (informs the flagged strategic decision)**
```bash
notebooklm use 73afc9a4
notebooklm ask "How decisive is couples/shared-household support for budgeting-app adoption vs single-user? Quantify demand and whether single-user apps succeed without it."
```
→ Data for the local-first couples decision (don't improvise it).

**8. Onboarding retention**
```bash
notebooklm use ff5e0abc
notebooklm ask "Onboarding patterns that improve D1/D7 retention for finance apps, with measured impact."
```

---

## Rule
Every result gets recorded to memory verbatim (per no-improvisation rule), with notebook ID + query + date. If a notebook lacks the answer, fall back to web search and label it web-tier; never invent.
