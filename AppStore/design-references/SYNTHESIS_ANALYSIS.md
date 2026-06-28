# Synthesis — Multi-Skill Design Analysis (Budget Crab)

**Date:** 2026-06-28 · **Model:** Opus 4.8 · **Type:** Analysis only — no code changed.
**Source docs (this folder):** `design-skill-analysis.md` · `paywall-analysis.md` · `psychology-analysis.md` · `onboarding-analysis.md` · `copywriting-analysis.md`

This rolls the five analyses into one prioritized list. Ranking is **Impact × Effort** (high impact + low effort first). Effort: **L** ≤ a few hours · **M** ≤ a day or two · **H** multi-day.

---

## The three recurring themes

1. **The system exists; discipline is the gap.** A full Quiet-Premium token system (`DesignSystem.swift`, `Color+Semantic.swift`, including `Color.brand`) and a well-documented voice (`.agents/product-marketing.md`) are in place — but views and strings keep bypassing both. Most fixes are *application*, not *invention* → low risk.
2. **The privacy promise is occasionally undercut by its own copy.** "FinanceTracker" name regressions, "we'll do the rest," and "our servers" quietly fight the #1 differentiator. Tightening these *strengthens* the moat for near-zero effort.
3. **Activation & revenue surfaces are passive.** The first-run *shows* instead of *doing*, and the paywall is a text price-list with no value demonstration. These are the two highest-upside (and higher-effort) bets.

> ⚠️ **Measurement reality:** no analytics SDK ships (by design). Revenue/activation changes can only be validated via **TestFlight cohorts + qualitative beta**, not production funnels. Plan experiments accordingly.

---

## TOP 15 — ranked by Impact × Effort

| # | Recommendation | Impact | Effort | Why it ranks here | Source |
|---|---|---|---|---|---|
| 1 | **Fix dev artifacts + wrong brand name** — purge `general.language_hint` & `about.privacy_hint`; "FinanceTracker"→"Budget Crab" in `about.app_name`, `settings.privacy.subtitle`, `pdf.report.title` | ★★★★★ | **L** | **Submission blocker.** Internal TODOs + legacy name currently ship to users (PDF is externally shareable). Trivial to fix. | copywriting P0 |
| 2 | **Paywall: benefit-led headline + on-paywall privacy line + reorder features** (lead unlimited/forever/privacy; demote custom-fields/filters) | ★★★★★ | **L** | Copy-only revenue lever; puts the brand's strongest asset (privacy) on the one screen that asks for money. | paywall P0/P1, psych |
| 3 | **Paywall: price framing** — "Best value" + "Save 42%" + per-month equivalence on Yearly | ★★★★ | **L** | Among the most reliable paywall CRO wins; pure copy/layout, no model change. | paywall P1 |
| 4 | **Adopt existing design tokens app-wide** — kill 5× `mintColor` + `paywallMint` → `Color.brand`; route cards through `.cardSurface`; amounts → `Font.bcAmount/bcDisplay` | ★★★★ | **L–M** | Mechanical substitution; unifies radii/color/type instantly; no token-file edits (those are frozen). | design P0, paywall |
| 5 | **Drop "smart"/"power features"; "we" → on-device actor** ("Budget Crab reads it on your iPhone") | ★★★ | **L** | Aligns voice rules AND reinforces privacy differentiator. Tiny edits, brand-wide effect. | copywriting P1, psych P1 |
| 6 | **Paywall: add value demonstration** — screenshot strip / one-line outcome preview above plan cards | ★★★★★ | **M** | The single biggest paywall lever ("show, don't tell"); turns a price list into a value preview. | paywall P0 |
| 7 | **Make first-run interactive** — the first transaction *is* the tutorial; trim the 3 passive screens | ★★★★★ | **M–H** | Time-to-value is the top retention driver; today there are up to 5 passive screens before any value. | onboarding P0 |
| 8 | **Re-skin the tutorial to the app palette** — drop purple gradient; replace raw `.red` with `bcExpense` terracotta | ★★★★ | **M** | First impression must match the product; fixes a color-psychology + brand-coherence break in one move. | design P1, psych P1, onboarding |
| 9 | **Surface + prime voice in first-run** — interactive mic beat with permission priming; tease Siri/Widget after first save | ★★★★ | **M** | The most differentiated "magic" never happens in session 1 today. | onboarding P0/P1 |
| 10 | **Simplify the Dashboard hero** — collapse 4 secondary gray lines to amount + one | ★★★ | **L** | Removes cognitive load; lets the one number (and the reassuring terracotta) land. | design P2, psych P2 |
| 11 | **De-dupe Dashboard empty-state copy + finish Account rebrand** (`edit.source.picker` "Source"→"Account") | ★★★ | **L** | Two competing empty-state voices + a stray "Source"; quick consistency wins. | copywriting P1/P2 |
| 12 | **Raise donut legibility** — lift opacity floor (~0.5) or small distinct-hue palette for top slices | ★★★ | **L** | ≥4 same-hue slices are near-indistinguishable; keep label+% so it stays CVD-safe. | design P2 |
| 13 | **Dynamic Type adoption** — move fixed `.font(.system(size:))` to text styles / `relativeTo:` | ★★★★ | **M** | HIG baseline; current fixed sizes clip at large accessibility sizes. | design P1 |
| 14 | **Auto-detect language; cut a pre-value config screen** (confirm silently or merge with currency) | ★★★ | **M** | Less friction before first value; also de-risks the known sheet-dismiss timing area. | onboarding P1 |
| 15 | **Promote "Explore with sample data" to a first-class first-run fork** (labeled, one-tap clear) + first-save celebration → Analytics handoff | ★★★ | **M** | Fastest path to "see my money"; adds a peak-end moment. | onboarding P2 |

---

## Sequencing (recommended)

**Wave 1 — before submission (all L, mostly copy):** #1, #2, #3, #5, #10, #11.
These are low-risk, high-value, and #1 is an actual submission-readiness fix. Most are string/layout edits; they preserve the 459×4 locale parity if done as edits (and #15-adjacent dead-key pruning would *change* counts — do that deliberately, not here).

**Wave 2 — token + craft pass (L–M):** #4, #12, #13. One focused branch; mechanical, build-verifiable.

**Wave 3 — growth bets (M–H, validate via TestFlight):** #6, #7, #8, #9, #14, #15.
These move activation and revenue but need qualitative validation since production analytics don't exist. Sequence the paywall value-preview (#6) and the interactive first-run (#7) first — biggest upside.

---

## Guardrails to record (so good decisions don't regress)

- **`bcExpense` ≠ alarm-red is intentional** (loss-aversion / calm-premium). Document it so no future "make expenses pop" change reintroduces red.
- **In-app stays silent on the indie/team story** (per channel rules); the *About* screen is the only sanctioned place to make "built independently" visible.
- **No new banned claims** ("AI-powered," "bank-grade," "end-to-end," "free forever") — the catalog is currently clean; keep it that way.
- **Token files are the single source of truth** — fixes should *consume* `DesignSystem.swift`/`Color+Semantic.swift`, never re-hardcode.

---

## One-line verdict

Budget Crab is **well-built with above-peer craft** (terracotta-not-red, CVD-safe money, chart interaction, disciplined privacy voice). The gap to "cohesive and converting" is mostly **applying systems that already exist** (tokens + voice), **cleaning a few user-visible leaks** (brand name, dev strings), and **making two passive surfaces active** (first-run + paywall). Highest leverage right now: the six Wave-1 copy fixes — they're nearly free and one of them is a submission blocker.
