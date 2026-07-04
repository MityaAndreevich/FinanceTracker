# BRIEF (Claude Code) — Visual Redesign Phase 2: Analytics + Transactions + app-wide tiles

Paste into Claude Code AFTER Phase 1 is merged. **Model: Sonnet** (execution on the P1 foundation). **Skill:** `/ui-ux-pro-max`.
Source of truth: `outputs/DESIGN_DIRECTION_v2.md`. Depends on P1 (semantic tokens + theme + category color/icon map must exist).

## Goal
Roll the new visual language from the Dashboard across the rest of the app. Kill the monochrome-red look everywhere. Use only P1 tokens + the category color/icon map. Originality guardrail: patterns not clones; our crab/mint styling.

## Locked decisions from Phase 1 review (implement in P2)
1. **Activate "safe to spend" via a single monthly budget:** add a **Settings field** (General) to set an overall monthly budget → writes the existing `@AppStorage("monthlyBudgetCents")`. When set, the Dashboard hero switches from net-this-month to true safe-to-spend (remaining + $/day + spent/budget bar, `bcWarning` when over). Localize the setting ×5. NO SwiftData change; per-category budgets are a later feature (see `FEATURE_SPECS_...Budgets`).
2. **Semantic red/green + arrows (refined 2026-07-02 — the problem was MONOCHROME red on everything, not red itself):**
   - **Individual EXPENSE amounts in transaction rows → `bcTextPrimary` (neutral), NO per-row red, NO per-row arrow.** A single expense is normal, not an alert — painting every row red is false-alarm noise.
   - **INCOME amounts → `bcPositive` (green) + up-arrow.**
   - **Net-this-month, trends/deltas (vs last month), and over/under-budget → USE the familiar red/green + arrow markers semantically:** `bcPositive` + up-arrow when positive / under budget; a **calm** red (`bcDanger`/coral, NOT the harsh terracotta) + down-arrow when net-negative / over budget. This is where the psychological marker earns its place — direction matters here.
   - **Keep arrows only where direction is the message** (net, deltas, income, budget status) — not on every transaction row.
   - Retire the old monochrome terracotta (`Color.money`/`bcExpense`) that painted all expenses red. Reserve harsh alarm-red for genuine errors/alerts.
   Result: familiar red/green + arrows where change/direction matters; calm neutral where it doesn't — consistent with the redesigned Dashboard.

## Scope
1. **Analytics redesign:**
   - Replace the monochrome-red donut with the **multi-color donut** (one distinct category color each, from the P1 map), center = total. Reuse the Dashboard donut component.
   - Category rows: colored icon tile + name + % + amount + a thin **colored progress bar** (category color). No all-red styling.
   - Keep the Pulse/Breakdown/Horizon + Expenses/Income segmented controls; restyle to tokens.
   - Fill the screen (no empty void); if data is thin, show a compact empty state (invitation, not "nothing here").
2. **Transactions redesign:**
   - Group by day with clear date headers.
   - Row = colored category icon tile (36px, category color on tinted bg) + merchant + category · account + amount. Expenses in `textPrimary` (NOT red); income in `bcPositive`.
   - Keep swipe actions / edit; restyle to tokens.
3. **App-wide category tiles:** apply the color+icon tile to any list showing categories (Categories screen, pickers, quick-entry chips).
4. **Tab bar polish:** tokens; elevated center "+" in mint; active = mint. Icons consistent.
5. Ensure both **Light and Dark** themes look right on every changed screen (test the theme switcher).

## Constraints
- No gradients/blur (solid layered surfaces + 1px borders). No emoji in UI.
- Currency via `defaultCurrencyCode` + `Shared/Money.swift`. No per-view formatters.
- Localize any new strings in all 5 locales. Key `ForEach` by stable UUID (not offset).
- Don't touch pricing/IAP/paywall logic (colors may adopt tokens). No SwiftData migration without stopping to report.

## Build / commit / report
- `xcodebuild` passes after each unit; commit in logical units (`feat(design):`), push.
- Report (≤8 lines): screens changed, files, build status, commit hashes, any screen still on old style, anything needing a Phase-3 decision.
