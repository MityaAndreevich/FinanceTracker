# BRIEF (Claude Code) — Revert in-app prices Path B → Path A

**Paste this whole brief into Claude Code.** Model: **Sonnet** (mechanical execution, not architectural). Skills: none required; optionally `/release-review` for a final glance.

## Context
Pricing was reversed 2026-07-02 from Path B back to **Path A** (see memory `budget_crab_decision` reversal + `outputs/RESEARCH_SYNTHESIS_2026-07-02.md`). The in-app paywall strings, `.storekit` config, and PaywallView mock were synced to **Path B** last session (Brief 38, commit b788d15) and now contradict Path A. Revert them.

## Target values (Path A)
| Field | Path B (current, wrong) | Path A (set to) |
|---|---|---|
| Monthly | $3.99 | **$4.99** |
| Yearly | $29.99 | **$34.99** |
| Lifetime | $79.99 | **$99.99** |
| Savings badge | Save 37% | **Save 42%** |
| Yearly per-month | $2.50/month | **$2.92/month** |
| Trial disclosure post-trial price | $29.99/year | **$34.99/year** |

**Do NOT change:** the 7-day free trial itself (duration stays 7 days — only the post-trial price changes), Family Sharing config, product IDs (`bc_premium_monthly` / `bc_premium_annual` / `bc_premium_lifetime`).

## Steps
1. **Find every occurrence** (grep first, per repo context-discipline):
   ```
   rg -n "3\.99|29\.99|79\.99|37%|2\.50|2,50" FinanceTracker/ FinanceTracker.storekit
   ```
   Expected hot spots (verify, don't trust blindly):
   - `FinanceTracker/en.lproj/Localizable.strings`: `paywall.yearly.save_amount` ("Save 37%"→"Save 42%"), `paywall.yearly.per_month` ("$2.50/month, billed annually"→"$2.92/month, billed annually"), `paywall.plan.yearly.subtitle` ("7-day free trial, then $29.99/year"→"…$34.99/year"), `paywall.trial.disclosure` ("After 7 days free, $29.99/year…"→"$34.99/year"), `paywall.trial.modal.body` ("$29.99/year auto-renews"→"$34.99/year").
   - Same keys in `ru.lproj`, `es.lproj` (es-MX), `pt-BR.lproj`, `uk.lproj` — apply the locale-formatted equivalents (keep each locale's number formatting; only the numeric value + % change). Save 42% localized: RU «Экономия 42%», ES «Ahorra 42%», PT «Economize 42%», UK «Економія 42%».
   - `FinanceTracker.storekit`: displayPrice / price fields for the 3 products → 4.99 / 34.99 / 99.99.
   - `PaywallView` (mock/fallback price literals if any) → 4.99 / 34.99 / 99.99.
2. **Apply replacements.** Prefer StoreKit-driven prices where the view already reads product.price; only edit hardcoded literals + the promotional strings above.
3. **Sanity math check:** $4.99×12=$59.88 vs $34.99 = 41.6% → "Save 42%" ✅; $34.99/12=$2.92 ✅.
4. **Build:** `xcodebuild ... build` — must pass before commit (repo rule).
5. **Regression:** if a PaywallView snapshot/unit test exists, run it; else manually confirm no remaining `29.99/37%/2.50` in the paywall via `rg`.
6. **Commit + push** (conventional prefix, body explains *why*):
   ```
   fix: revert in-app prices Path B→Path A ($4.99/$34.99/$99.99, Save 42%)

   Pricing reversed 2026-07-02 after research (2 rounds + 7x LTV; real review
   data showed price-rage is dark-patterns not level). Syncs paywall strings,
   .storekit, PaywallView mock to Path A. Trial stays 7 days; post-trial 34.99.
   ```
   Push to `origin/main`.

## Report back (≤6 lines, repo style)
1) what changed, 2) files changed, 3) build status, 4) commit hash, 5) confirm `rg "29\.99|37%|2\.50"` returns nothing in paywall/storekit.

## Guardrails
- Do NOT touch ASC (I handle IAP prices there via the checklist).
- Do NOT alter the 7-day trial length or Family Sharing.
- If you find prices in an unexpected place (e.g. onboarding, About, marketing copy in-app), list them and ask before changing — don't assume.
