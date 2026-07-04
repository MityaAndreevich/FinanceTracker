# BRIEF (Claude Code) — Enrich demo seed for screenshots

Paste into Claude Code (do AFTER redesign P1/P2 so seeded data renders in the new look). **Model: Sonnet.** **Skill:** none.
Goal: replace the sparse demo data (2–3 transactions → empty screens) with a realistic full month so the redesigned Dashboard/Analytics look full and premium in App Store screenshots.

## Context
- Screenshot demo data comes from the DEBUG-only seeder (`DemoSeeder` / `ScreenshotMode`, driven by `AppStore/capture-screenshots.sh --demo-locale`). Keep it hard-`#if DEBUG` (must not ship in Release).
- Locales seeded: EN (USD), RU (RUB), ES/es-MX (MXN), PT-BR (BRL). (UK optional if present.)

## ⚠️ Currency consistency (bug seen in P1 screenshot — fix)
The P1 pt-BR dashboard showed **US$ in the hero/donut, R$ in the rows, $ in the quick-add placeholder** — three currencies on one screen. Root cause: aggregates use `defaultCurrencyCode` (USD) while seeded transactions carry BRL. Fix:
- Each locale's demo must set **`@AppStorage("defaultCurrencyCode")` to that locale's currency** (EN=USD, RU=RUB, ES/es-MX=MXN, PT-BR=BRL) AND seed all transactions in the SAME currency → hero, donut, rows, quick-add ALL match.
- Localize/adjust the **quick-add placeholder example** so its amount + currency match the locale (no hardcoded "$5.50 Starbucks" under a pt-BR screen).
- While here, VERIFY aggregation (hero net + donut total) reads `defaultCurrencyCode` (per CLAUDE.md anti-pattern), not `transactions.first?.currency`.

## Quick-entry screenshot must show the PARSED state (not empty idle)
The redesigned Quick Entry (commit 47d92ba) can't render its parsed-preview state under simctl (no text injection). For App Store screenshot #3 it must look POPULATED (amount hero + parsed preview card + category tile), not the bare idle. Add a **DEBUG-only launch arg** (e.g. `--screenshot-quickentry-parsed`, hard-`#if DEBUG`) that preloads a locale-appropriate parsed transaction (amount + merchant + suggested category) so the capture shows the rich state. Wire it into `capture-screenshots.sh` for the `quickentry` screen. Currency must match the locale (per the currency-consistency section below).

## Requirements
1. **~30–40 transactions across the current month**, spread over realistic dates (not all one day), across **8+ categories** with the redesign color/icon map (Housing, Groceries, Transport, Dining/Coffee, Subscriptions, Shopping, Health, Bills, + Income).
2. **Believable amounts + merchants**, localized per locale (localized merchant names + currency + category names). Don't ship English merchants under a Spanish screenshot.
3. **Positive, healthy state:** income entries present; a positive "safe to spend" (spent < budget); a monthly budget set so the hero + budget bars render. Avoid an all-negative/red month.
4. **A few recurring/subscriptions** (e.g., streaming, gym) so any "upcoming/recurring" UI has content.
5. **Multi-category distribution** that makes the donut look good (4–6 visible slices, no single 95% slice).
6. **Deterministic** — fixed seed data (not random) so screenshots are reproducible across runs and locales.
7. Wipe + reseed per launch (as the current flow does); leave the real (non-demo) app data untouched.

## Acceptance
- Running `AppStore/capture-screenshots.sh EN` (and RU/ES/PT-BR) yields a Dashboard + Analytics that look FULL (no large empty void), with a multi-color donut and a populated this-week list.
- No demo data leaks into Release (verify `#if DEBUG` gating holds).
- Amounts/dates/merchants are locale-appropriate.
- Build passes; commit (`chore(demo): richer screenshot seed`), push.

## Report back (≤6 lines)
Files changed, per-locale transaction count, build status, commit hash, confirmation demo stays DEBUG-only, any category missing an icon/color in the P1 map.
