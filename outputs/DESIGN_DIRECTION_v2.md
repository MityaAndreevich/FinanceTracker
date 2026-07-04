# Budget Crab — Design Direction v2 (modern refresh)

**Date:** 2026-07-02 · Supersedes the cream/minimal visual execution (kept: crab brand, mint accent, name, positioning, pricing).
**Decision:** user theme switcher (System / Light / Dark), **Dark + data-viz is the default**, modern depth + multi-color, redesign **before public launch**. Full rationale: memory `budget_crab_design_redesign_decision`.

## 0. Originality guardrails (non-negotiable)
- **Use conventions, not clones.** Dark theme, donut charts, budget rings, "safe to spend", category color-coding, layered cards = industry-standard UI patterns, freely usable.
- **Never copy protected expression:** no competitor logos, icon sets, illustrations, exact color signatures, verbatim copy, or pixel-identical layouts (esp. Copilot/Rocket/Origin).
- Our identity = common patterns + **our crab mascot + our mint (#3DDC97) + our own layout, type, and copy.** The Cowork concept is a direction reference, not a design to trace.

## 1. Theme system
User setting in Settings → Appearance: **System · Light · Dark** (`@AppStorage("appearanceMode")`, applied via `.preferredColorScheme`). Dark is the default for new installs. All colors come from semantic tokens (below) — no hardcoded hex in views.

### Semantic tokens (define once, both themes)
| Token | Dark | Light |
|---|---|---|
| `page` (bg) | #0F1420 | #F6F7F5 |
| `surface1` (card) | #171E2B | #FFFFFF |
| `surface2` (elevated/tile) | #202838 | #FFFFFF (+border) |
| `textPrimary` | #F2F5F9 | #14181F |
| `textSecondary` | #8C97A8 | #5F6B7A |
| `textMuted` | #5A6577 | #9AA4B2 |
| `divider` | #1C2433 | #ECEEEA |
| `accent` (brand mint) | #3DDC97 | #17B47D |
| `positive` (income) | #3DDC97 | #17B47D |
| `warning` (over budget) | #EF9F27 | #C9791A |
| `danger` (only real alerts) | #E24B4A | #C43C3C |

Rule: **expenses are NOT alarm-red.** Amounts render in `textPrimary`; red is reserved for genuine over-budget/alerts. Income in `positive`.

### Category palette (assign one color + SF Symbol per category)
Housing/Rent purple `#7F77DD` `house.fill` · Groceries teal `#1D9E75` `cart.fill` · Transport blue `#378ADD` `car.fill` · Dining/Coffee amber `#EF9F27` `cup.and.saucer.fill` · Subscriptions violet `#9B8CFF` `repeat` · Shopping pink `#D4537E` `bag.fill` · Health green `#639922` `heart.fill` · Bills coral `#D85A30` `bolt.fill` · Entertainment blue-teal · Uncategorized gray `#7C8698` `questionmark`. (Extend as needed; keep hues distinct + legible on both themes.)

## 2. Typography & shape
- System SF Pro. Titles 32-34 bold; section headers 17-20 semibold; body 15-17; captions 12-13. Money = rounded/tabular figures.
- Cards radius 16; icon tiles/chips radius 11-12; pills only when intentional.
- **Depth via solid layered surfaces + 1px borders** (NOT gradients — they flash and look cheap). surface2 sits above surface1 above page.

## 3. Core components
1. **Safe-to-spend hero card** — label + big number (`$1,240`) + "$X/day for N days" + progress bar (spent vs budget). Positive, actionable. This is the dashboard anchor.
2. **Multi-color donut** — category breakdown, one distinct color per category, center = total. Replaces the monochrome-red donut everywhere.
3. **Transaction row** — colored category icon tile (36px, category color on tinted bg) + merchant + category · account + amount.
4. **Metric mini-cards** — small labeled numbers (2-up).
5. **Tab bar** — 5 items, elevated center "+" in mint, active tab mint.
6. (Optional P2) **Budget rings** — Activity-ring style per top category (our own styling).

## 4. Per-screen changes
- **Dashboard (hero):** safe-to-spend card → this-month multi-color donut + top categories → this-week list. Fill the screen; no empty void.
- **Analytics:** multi-color donut (fix monochrome), category rows with colored bars + %, period selector, optional spend trend line.
- **Transactions:** grouped by day, colored category tiles, running clarity.
- **Quick add / Add:** keep it fast (72s rule); modern sheet, default category "Uncategorized", haptic + checkmark on save. No predictive modal pop-ups ("Mint pattern" anti-pattern).
- **Categories & Accounts:** colored icons, tidy rows.
- **Settings:** add **Appearance** (theme switcher) at top of a section.
- **Paywall:** already clean — align to dark tokens; keep billing-transparency line ("cancel anytime, no ads").

## 5. Demo seed for screenshots
Current 2-3 transactions = empty look. Build a realistic **full month**: ~30-40 transactions across 8+ categories, believable amounts, a positive "safe to spend", 4-6 category donut. Locale-appropriate per EN/RU/ES/PT-BR. This alone transforms the screenshots.

## 6. Phased delivery (Claude Code briefs, English)
- **Phase 1 (foundation + biggest win):** semantic color tokens + theme system (System/Light/Dark setting) + category color/icon map + **Dashboard redesign** (safe-to-spend hero + multi-color donut + filled layout). → `BRIEF_REDESIGN_P1.md`.
- **Phase 2:** Analytics (multi-color donut) + Transactions + apply category tiles app-wide + tab bar polish.
- **Phase 3:** richer demo seed + regenerate screenshots (all locales, dark) + micro-polish (empty states, haptics) + Figma compositing of store screenshots.
- After P3: re-archive → TestFlight → then public submit.

## 7. What does NOT change
Brand name (Budget Crab), crab mascot + app icon, mint accent, privacy/local-first positioning, Path A pricing, IAPs, compliance. This is a visual-layer refresh, not a re-architecture.
