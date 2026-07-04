# BRIEF (Claude Code) — Visual Redesign Phase 1: theme system + tokens + Dashboard

Paste into Claude Code. Model: **Opus** for the token/theme architecture (multi-file), then Sonnet for view work. Skill: `/ui-ux-pro-max`.
Source of truth for colors/type/components: `outputs/DESIGN_DIRECTION_v2.md` (read it first). This is Phase 1 of 3.

## Goal
Establish the new visual foundation and redesign the **Dashboard** to a modern, dark-default, data-viz look — WITHOUT breaking data/logic. Keep the crab brand + mint accent. Use industry-standard UI patterns only; do NOT clone any competitor's specific look/assets/copy (originality guardrail).

## Explore first (don't guess)
- Current color/theme usage: is there a DesignSystem/Theme file? grep for `Color(`, hardcoded hex, `.foregroundStyle`, any existing `DESIGN_SYSTEM`.
- `Views/DashboardView.swift`, the analytics donut view, `Shared/Money.swift`, Settings views, the `Category` model (does it have a color/icon field?), and how `@AppStorage("defaultCurrencyCode")` is used.
- Confirm repo conventions in CLAUDE.md (Money.swift for formatting, no per-view formatters, no hardcoded English strings — localize new keys in en/ru/es/pt-BR/uk, no ForEach offset-keying, ModelActor for background writes).

## Implement (Phase 1 scope)
1. **Semantic color tokens (Light + Dark).** Create Asset Catalog color sets with Any + Dark appearances (auto-adapt), named semantically per DESIGN_DIRECTION_v2 §1: `bcPage, bcSurface1, bcSurface2, bcTextPrimary, bcTextSecondary, bcTextMuted, bcDivider, bcAccent, bcPositive, bcWarning, bcDanger`. Add a `Color` extension exposing them. Replace hardcoded colors on the touched screens with these tokens.
2. **Appearance setting.** `@AppStorage("appearanceMode")` enum `system|light|dark` (default `dark` for fresh installs; if a simple "first launch" flag is easy, set dark then). Apply `.preferredColorScheme(...)` at the app root. Add **Settings → Appearance** with a 3-way picker (localized in 5 locales).
3. **Category color + icon map.** A single source mapping each category to a color + SF Symbol (DESIGN_DIRECTION_v2 §1 palette). If the `Category` model lacks color/icon, add a computed mapping keyed by category name/type (don't require a data migration in P1). Expose `category.themeColor` + `category.symbolName`.
4. **Dashboard redesign** (DESIGN_DIRECTION_v2 §3–4):
   - **Safe-to-spend hero card**: big number + "$X/day for N days left" + progress bar (spent vs budget). If no budget model exists yet, base it on `monthlyBudget` from a new optional Settings value; if unset, fall back to "spent this month / net" with the progress bar hidden, and REPORT this so we can decide the budget model in P2. Do NOT build a full budgeting engine in P1.
   - **This-month multi-color donut**: category breakdown, one distinct color per category (from the map), center = total spent. Reuse for Analytics in P2.
   - **This-week list**: transaction rows with colored category icon tiles (36px, category color on tinted bg) + merchant + category · account + amount. Expenses in `textPrimary` (NOT red); income in `bcPositive`.
   - Fill the screen — no large empty void. Elevated cards (solid surfaces + 1px border), radius 16. No gradients.
5. Keep all existing behavior (currency via `defaultCurrencyCode` + Money.swift, navigation, data). Keep DEBUG-only screenshot/demo gating intact.

## Build / commit / report
- `xcodebuild ... build` must pass after each meaningful unit.
- Commit in logical units (conventional prefixes: `feat(theme):`, `feat(design):`, `refactor:`), push to origin/main.
- Report (≤8 lines): what shipped, files added/changed, build status, commit hashes, how the safe-to-spend budget fallback was handled, anything that needs a decision for Phase 2, and any screens still on the old style.

## Guardrails
- Originality: patterns yes, competitor cloning no (no lifted icons/illustrations/color signatures/copy).
- No gradients/blur (depth via solid layered surfaces + borders). No emoji in UI.
- Don't touch pricing/IAP/StoreKit, ASC, or the paywall logic (only its colors may adopt tokens).
- Localize every new user-facing string in all 5 locales.
- If a change would require a SwiftData migration, STOP and report before doing it.
```
```
