# Budget Crab — v1.0.1+ Roadmap (single source; build while 1.0 is in review)

All research + ideas consolidated here. Detailed source docs referenced per item. Prioritized by **ROI (retention/conversion), not craft** — per our discipline. 1.0 stays the shipped baseline; 1.0.1 is a fresh cycle in TestFlight, submitted after 1.0 is approved.

## Priority order (why this order = data)
1. **Analytics v1 redesign** — biggest retention lever. Source: outputs/ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md (4-notebook research).
   - Make **Safe-to-Spend the hero**, gain-framed ("safe to spend $X" not "you spent $X" — loss pain ≈ 2× gain).
   - Add **"Pace"** (spending velocity vs days left) — own name, generic.
   - **Kill the blank "insights coming later" state** (blank-slate paralysis) — show simple pie + safe-to-spend immediately / seed demo analytics.
   - Donut: **3–5 slices + "Other" + SF Symbols/labels** (not color-only; accessibility).
   - Month-over-month bar + trend once ≥2 months; avoid "History Amnesia".
2. **Color system** — calm/neutral default, **green = income only**, expense muted (NOT alarm-red — raises anxiety, our P3). **Optional classic red/green picker** (the scheme choice you asked for). Accessibility: icon+label, never color-only.
3. **TipKit contextual onboarding/help** — beats static annotated screenshots (+23% conv Blinkist, 96% activation Headspace). Replaces the "Help & Tips" annotated-screens idea.
4. **Flexible CSV import (Mint/YNAB/bank)** — growth lever (post-Mint vacuum). Source: outputs/MIGRATION_IMPORT_ROADMAP.md. Column-mapping + source presets + handle 2-column debit/credit. Unlocks "switch from Mint" marketing claim + keywords. Dedup already solved.
5. **Widget redesign** (you flagged — looks off-brand, uninformative). See §Widget below.
6. **Audit P1s** — store-corruption recovery path, gate ~15 `print()` in Release, localize Siri/AppIntent phrases, fix stale `ft_*` in ARCHITECTURE.md. Source: outputs/CODE_REVIEW_FINDINGS.md.
7. **@ModelActor write-path** (off-main SwiftData) — perf pass.

## Widget redesign (v1.0.1)
Current issues (device): small widget nearly empty (one cut-off number + tiny icon); large widget = monochrome list of huge raw category totals, no hierarchy, doesn't match the app's calm/rounded design; not actionable. NOTE: it DOES pull App Group data correctly (so the earlier CFPrefs warning is cosmetic, not broken).
Direction (aligns with our own Analytics research + the competitor example you sent — Monarch's "Budget / Actual / Remaining" with a ring):
- **Lead with Safe-to-Spend / Remaining this month** (gain-frame, ring) — the single most useful glanceable number, matches our hero-metric research.
- Small: the ring + "Safe to spend $X" (+ optional "of $Y budget"). Medium: ring + top 2–3 categories with mini bars. Large: ring + safe-to-spend + top categories + spent/earned.
- Match app design: calm base, green=income/positive only, coral/neutral for spend, rounded cards, our type scale. Not raw monochrome totals.
- Fix number formatting for large values (currently overflows/ellipsizes — use compact/abbreviated for the widget).

## Post-launch marketing (not code)
- Product Page Optimization A/B: keyword-first title (`Private Budget: Budget Crab`).
- Custom Product Pages (up to 70): dedicated CSV-export + cash-flow pages (+8.6% conv).
- App Store featuring nomination (free lever).
- Daily finance tips (365, optional toggle) — validate demand first; candidate Premium hook.
- iPad support (adaptive layout + iPad screenshots), then Mac.

## Where the source docs live (all in outputs/)
- ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md — analytics + color + ASO research.
- MIGRATION_IMPORT_ROADMAP.md — import/migration tiers + honest marketing claims.
- CODE_REVIEW_FINDINGS.md — audit P0 (fixed) + P1/P2.
- SUBMISSION_RUNWAY.md — runway + v1.0.1 backlog.
- GO_LIVE_CHECKLIST.md — the remaining path to Add for Review.
Plus cross-chat memory: analytics_color_research, csv_locale_separator_bug, swift_charts_nan_crash, financetracker_v1_1_ai_roadmap, etc.
