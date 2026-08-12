# BRIEF (Claude Code) — v1.0.2 "Learn & Tips" hub: daily crab tip + annotated help. Model: Sonnet. Skills: apple-hig-expert, swiftui-design-skill. This is the MECHANISM; the 365-item content is supplied separately (do not invent financial content — use the provided library / placeholders until it lands).

**v1.0.2 branch.** `main`, commit per unit, push, build + test before commit. Localize all UI chrome in 5 locales. Content (the tips themselves) is provided as data — see Item 1. Low-risk feature; does NOT touch monetization/sync/data-migration. No CLAUDE.md anti-patterns.

## Why
Daily educational tips (a financial term + plain-language explanation + one smart strategy) are a retention/habit driver and on-brand (honest education). Kept **FREE** (retention, not a paywall — research: educational content drives retention, not WTP). The same content feeds our social channels (write once, use twice) — so structure it as clean data, not hardcoded views.

## Item 1 — Content model (data-driven, not hardcoded)
- A `DailyTip` model/struct: `id`, `term`, `explanation` (plain language), `strategy` (one actionable line), optional `category`. Load from a bundled localized data file (JSON/plist) so content can grow without code changes and be reused for social.
- Ship with a small seed set + a clear place to drop the full 365-item library when it's written (the founder/ContentStudio supplies it). Do NOT author financial content yourself — use provided text or neutral placeholders.
- 5-locale ready (the data file is per-locale or keyed for translation).

## Item 2 — Daily surfacing
- A **"Tip of the day"** card surfaced on a sensible surface (e.g., a dismissible card on Overview, or the top of the Learn hub). Deterministic daily rotation (same tip for everyone that day, or per-user cycle) — no repeats until the set is exhausted.
- Calm, on-brand, dismissible; never blocks the core flow; respect Reduce Motion. NOT a notification (that's the separate alerts feature).

## Item 3 — "Learn & Tips" hub in Settings
- A Settings → **Learn & Tips** section containing:
  - the full browsable tip library (searchable list),
  - the **annotated how-to / help screens** (the onboarding reference material — the demoted-from-primary static help; keep it as on-demand reference, TipKit stays the primary contextual layer).
- Clean, native, calm. Reuse existing components.

## Item 4 — Reuse, don't duplicate
- Route any tip copy through existing string/formatting infra. Don't add per-view formatters. Keep it free (no `isPremium` gate).

## Tests (targeted)
- Content loads from the data file; missing/empty file → hub shows an empty state, no crash.
- Daily rotation deterministic; no repeat until set exhausted.
- Tip card dismiss persists for the day; hub search works.
- 5-locale parity for UI chrome; longest-locale no truncation.

## Report (≤6 lines/item): the content model + where the 365-item library plugs in, the daily card, the Settings hub, files, build/test, commit per unit. Device-verify: tip of the day shows + rotates; Learn hub lists tips + help screens; all free; Dark+Light.
