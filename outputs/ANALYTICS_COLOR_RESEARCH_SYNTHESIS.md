# Budget Crab — Analytics + Color research synthesis (2026-07-06)

Sources: NotebookLM 73afc9a4 (Finance Domain), ff5e0abc (UX), a16f8bf7 (Psychology), 04c87827 (ASO). Every recommendation traces to a cited finding. Method: cross-reference **users want × users search × what we have** → prioritize.

## TL;DR decisions
1. **Color:** do NOT default to alarm-red for expenses AND stop rendering expenses in income-green. Default = **calm/neutral base, green reserved strictly for income (gain)**, expense = neutral/muted (not bright red). Lead the dashboard with the **GAIN frame ("safe to spend $X")**, not the loss frame ("you spent $X"). Offer an optional classic red/green scheme, but **calm is the default**.
2. **Analytics near-term:** make **Safe-to-Spend the hero** (gain-framed), add a **"Pace" velocity cue**, fix the donut (3–5 segments + "Other", icon+label not color-only). Kill the blank "insights coming later" state.
3. **Free ASO win:** we already have hardened **CSV export/import** — it's a high-intent, low-competition keyword ("CSV export") we can OWN. Add to keywords + a Custom Product Page post-launch.
4. **Do NOT build for v1.0:** full net-worth, retirement forecasting, debt payoff, Sankey, "Age of Money" — wrong fit or need deep data. Reasons below.
5. **None of this blocks submit** except the green-as-income fix (already briefed) + adding the CSV keyword (metadata, free).

---

## 1. Color scheme — decision + evidence (answers "red vs calm?")
**Verdict: calm default, gain-framed, optional classic scheme. NOT alarm-red.**

- **Alarm-red raises real anxiety.** Loss-attention studies: losses trigger measurably higher autonomic arousal — increased heart rate + pupil diameter; aggressive red over-stimulates this stress response (a16f8bf7). It's a documented anti-pattern for "Quiet Premium" (ff5e0abc).
- **Gain frame beats loss frame.** Prospect Theory: loss pain ≈ **2× ** gain pleasure. "Safe to spend $X" (gain) reduces anxiety vs "you spent $X" (loss); outcome/gain framing lifted conversion +23% (Strava) (a16f8bf7). → Our dashboard should foreground **what's left / safe-to-spend**, not the spent total.
- **Our current green-everything is also wrong** — it reads spending as income/positive (the device bug). Fix toward **neutral expense + green-only-for-income**.
- **Accessibility (must):** color must never be the only signal — ~8% of males are red-green colorblind; pair with **SF Symbols + text labels** ("Expense"/"Income"), not hue alone (ff5e0abc, WCAG/HIG). Red also isn't universally "bad" (red = positive in Chinese stocks) — another reason not to hard-code red=expense.
- **Product move:** ties directly to the **color-scheme picker (task #32)** — ship calm/muted as default, offer a classic red/green option for users who want it. Default protects the anxiety-sensitive majority (our P3: 70% feel financial anxiety).

## 2. Analytics — what to build, ranked (want × search × fit)
Tag = [demand rank] · [we have?] · [effort]

**BUILD / IMPROVE (fits privacy-first manual tracker):**
- **Safe-to-Spend as hero + "Pace" cue** — demand #2; we HAVE safe-to-spend. Make it the most prominent element (center of donut or 34pt+ title), gain-framed. Add a velocity cue ("spending faster than days remaining") — concept from PocketGuard's "Pace" but **implement generically under our own name** (don't copy the branded term). Meaningful from day 1 (few transactions). [High value, low-med effort]
- **Category donut done right** — limit **3–5 segments + "Other"**, pair each with an SF Symbol/label, don't let a single-category expense render as income-green. Meaningful early. [Fixes current bug, low effort]
- **Kill the blank "insights coming as you track" state** — this is textbook "blank-slate paralysis." Show the simple pie + safe-to-spend immediately, or seed demo analytics (we already have onboarding demo data). Top apps (MoneyWiz, Copilot) populate the dashboard with generated data so users see value before entering real data. [Med effort, high activation impact]
- **Month-over-month bar + trend line** — appears once ≥2 months exist. Avoid "History Amnesia" (resetting charts to zero each month) — keep historical context via horizontal scroll. Add haptic scrubbing (`.chartXSelection`) for inline detail. [v1.x, med effort]

**CANDIDATE (v1.x, gated on data/fit):**
- **Cash-flow calendar** — date-based money view; a searched gap (below) we don't have. Strong v1.x candidate. [med effort]
- **Sankey / cash-flow flow graph** — power-user "pretty graph" that drives ratings (Sure Finance, Spendee), but looks empty with sparse data → gate behind data maturity. [higher effort, v1.x delight]

**DO NOT BUILD (wrong fit — reasons):**
- **Full Net Worth** — demand #1, BUT needs account/asset balances; conflicts with no-bank-linking + manual model. A *manual* net-worth (user types balances) is the only privacy-compatible version — defer + evaluate, don't rush.
- **Retirement/multi-variable forecasting** — for serious planners with deep data + investments. Not our user.
- **Debt payoff tracker** — specific segment, not our core (though it's a searchable keyword — see ASO).
- **"Age of Money"** — YNAB's trademarked metric; needs 3 months; behavioral-niche. Skip (also IP caution).

**Competitor mistakes to avoid (from domain reviews):** rearward-looking-only charts, History Amnesia, duplicate transactions corrupting charts (we just fixed dedup ✓), single-number "static projections."

## 3. ASO — analytics terms that double as keywords
Finance downloads −4.6% but **revenue +10.2%** (2025) → users pay for value-add insights, not cheapest. Indie lane = **feature long-tails (difficulty 30–50) + niche/privacy intent (<40)** that bank apps ignore.

**Immediate (free) wins — we already have the feature:**
- **"CSV export" / "CSV budget export"** (diff 30–50, mod/high intent) — we HAVE hardened CSV export+import. Add to keyword field; it's a keyword+feature we can own. Consider Title: `Budget Crab: Private Budget & CSV`.
- **"manual expense tracker", "offline budget", "private budget", "no bank link"** (<40, growing) — our exact positioning; ensure these are in title/subtitle/keywords.
- **"bill reminder / bill tracker"** (30–50) — we have Recurring; surface as "bills".

**Feature+keyword GAPS worth owning (build → then keyword):**
- **"cash flow calendar"** — demand + weak competitor coverage; maps to the v1.x cash-flow feature above.
- **"debt payoff tracker"** — searchable, but off-core; only if we ever add it.

**Post-launch ASO levers:** Custom Product Pages (up to 70, +8.6% conversion) — dedicated pages for "CSV Export" and "Cash Flow"; screenshot OCR captions ≥40pt (already done).

## 4. Onboarding / Help — nuance vs the "annotated screenshots" plan
Research says **interactive + contextual beats static annotated screenshots**:
- **Interactive sandbox w/ demo data** (we have) → 96% activation (Headspace). Keep/strengthen.
- **Progressive disclosure** ("one thing well" first) → +23% conversion (Blinkist). Don't tour every tab.
- **TipKit contextual tips** (non-modal, near the element) > screen-dimming coach-marks.
- **Goal-narrative** to prevent the "middle slump" ("this Safe-to-Spend view protects your vacation fund").
- Anti-patterns: prerequisite full tutorials, noisy confetti (hurts premium trust).
→ For the Help backlog: lead with **TipKit + interactive demo**; keep annotated screenshots only as secondary reference, not the primary teaching tool.

## 5. Launch impact
- **v1.0 (already in flight):** green-as-income fix (briefed). Add **CSV + private/offline keywords** (metadata, free, do at ASC).
- **v1.0.1:** color-scheme picker (calm default), Safe-to-Spend-as-hero + Pace, donut fix, kill blank analytics state, TipKit help.
- **v1.x:** month-over-month + trend, cash-flow calendar, Sankey (gated), manual net-worth (evaluate).
- Nothing here delays submit.

## Proposed next briefs (after launch)
1. Analytics v1 redesign: Safe-to-Spend hero (gain-framed) + Pace + donut fix + non-blank empty state.
2. Color system: calm/muted default + income-green-only + accessibility (icon+label) + optional classic scheme picker.
3. ASO: keyword refresh (CSV/private/offline) now; CPP plan post-launch.
