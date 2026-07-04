# BRIEF (Claude Code) — Bug-fix pass: Quick Entry / save / parse regressions + light theme

Paste into Claude Code. **Model: Opus** (multi-bug root-cause debugging across the entry/save/parse path) → Sonnet to execute. **Skill:** `/ui-ux-pro-max` (layout + light theme).

## Context / accountability
Device testing after the redesign + demo-seed work surfaced regressions in the ENTRY/SAVE/PARSE mechanics — which the redesign was NOT supposed to touch (the briefs said "reuse QuickAddParser/CategorySuggestionService/QuickAddSaveService/VoiceInputService, UI only"). Investigate what the Quick Entry redesign (47d92ba) and demo-seed (f6b5a4d) changed in those paths and RESTORE correct behavior. **Add regression tests so these can't recur.** Do NOT "rewrite" the mechanics — find the regression and fix it.

## 🎯 ROOT-CAUSE NARROWING (from a Cowork git investigation — use this)
Pre-redesign known-good commit = **`ae1ba21`** (parent of the P1 commit bf1598e). Diffing ae1ba21→HEAD:
- **The mechanic SERVICES are UNCHANGED and still pass their tests:** `Services/QuickAddParser.swift`, `AI/CategorySuggestionService.swift`, `Services/QuickAddSaveService.swift`, `Services/VoiceInputService.swift` — plus their test files — are byte-identical to pre-redesign. **DO NOT modify these.** Parse/category/save LOGIC is intact.
- **Only the VIEWS changed:** `Views/QuickEntry/QuickEntryView.swift` (+644), `Views/DashboardView.swift` (+267), `Data/DemoSeeder.swift` (+60).
→ So **B1/B2/B4 are regressions in how the rewritten views WIRE UP the (working) services** — wrong call, missing state reset, mishandled parse result. **Fix approach (as the CEO suggested): `git show ae1ba21:FinanceTracker/Views/QuickEntry/QuickEntryView.swift` and the old DashboardView, see how they correctly wired save/parse/category, and restore that behavior in the new UI.** Keep the new look, restore the old logic wiring.
- **B3 (detailed-form save fails):** `Views/AddTransactionView.swift` was NOT touched by the redesign → B3 is likely from the **demo-seed schema change** (`DemoSeeder.swift`, daysAgo→dayOfMonth) or a model/required-field/validation issue, NOT the redesigned views. Investigate that path separately.
- **B5 (category name "Food & Drink" in RU):** the new UI probably renders the raw category seed NAME instead of a localized display name — check how the preview/legend/tiles resolve the category's display name.

## Bugs (from device test — reproduce each first, then fix)

**B1 (critical) — Quick-add double-counts.** On the Dashboard quick-add, entering "50 кофе" adds ~100 (double). **Likely root cause = B2:** Save doesn't reset the quick-add state, so the preview stays and the user taps Save again → a second identical transaction is written. Verify: is it a true double-fire in one Save, or a second manual tap on a non-cleared control? Fix so ONE Save writes exactly one transaction with the exact parsed amount.

**B2 (critical) — Dashboard quick-add Save doesn't dismiss/clear.** After Save, the parsed preview + input stay visible (looks like it needs another tap). Fix: on successful Save → clear the input, dismiss the preview, haptic + checkmark, and disable/guard against re-submitting the same pending entry.

**B3 (critical) — Detailed Add form save fails.** Opening the detailed "+" form and tapping Добавить → alert "Не удалось сохранить транзакцию. Попробуйте ещё раз." Saving is broken entirely on this path. Root-cause (validation? missing required field like account/category after the seed schema change? ModelContext issue?) and fix. This is the core action — must work.

**B4 (critical) — NL parse + voice category detection regressed.** Entering "50 кофе" shows the amount but also "Не удалось распознать — откройте форму" (contradictory), and category is NOT detected from voice/text (we fixed this before — it's a regression). Restore: valid input parses (amount + merchant + category) without the false "couldn't recognize" error; voice dictation resolves a category via CategorySuggestionService. Check whether the seed/redesign changed the parser wiring or the category lookup.

**B5 (localization) — English strings leak in RU (Transactions is correct, so it's specific keys).** Dashboard hero shows English "Spent"/"Earned"; the parsed preview shows the English category name "Food & Drink" under a Russian UI. Fix: (a) localize the "Spent"/"Earned" labels ×5; (b) **category DISPLAY NAMES must be localized** — seeded categories should resolve to the localized name everywhere (preview, donut legend, tiles), not the raw English seed name. Audit for any other hardcoded English in the Dashboard/QuickEntry.

**B6 (currency) — $ vs ₽ inconsistency in RU.** Real-use RU shows "$" in aggregates while the quick-entry placeholder is hardcoded "350₽". Currency should follow `@AppStorage("defaultCurrencyCode")` everywhere (it's a setting, not tied to language). Fix: the quick-entry placeholder must use the actual default currency (or a neutral example), not a hardcoded ₽; confirm all amounts (hero, donut, preview, rows) use defaultCurrencyCode consistently.

**B7 (layout) — Quick Entry "+" sheet overlaps / cramped ("каша").** Elements collide on device. Fix spacing/layout; verify no overlap across device sizes AND Dynamic Type (larger text). The chips row, preview card, error banner, input, and Save must never overlap.
**B7-followup (device-confirmed 2026-07-02):** when the keyboard is up and text is typed, the **input field (green-bordered) overlaps the CATEGORY CHIP LABELS** (the text under the category icons is clipped by the input's top edge). Fix: guarantee fixed vertical spacing so the input bar sits clearly BELOW the chips row with a gap (anchor/scroll so keyboard-up never pushes the input over the chips). **Verify in ALL 5 locales (EN, RU, es-MX, pt-BR, uk) — NOT just EN/RU** — longer localized category names + labels overlap worse; also at default AND large Dynamic Type. No label should be clipped or overlapped in any locale.

**B8 (analytics) — Trends/Horizon chart broken.** The net-trend line crashes to ~−300,000 with a wrong Y domain (see screenshot). Fix the chart's data/axis domain (likely seed data spanning many months or a cumulative-sum bug). Should render a sane, readable trend.

## Design fix (with /ui-ux-pro-max)
**D1 — Light theme reads empty/cheap (plain white).** Warm it up + add depth: warmer off-white page + slightly-elevated card surfaces with a visible hairline/soft shadow separation (not pure #FFFFFF flat on #FFFFFF). Keep tokens; adjust the LIGHT values of bcPage/bcSurface1/bcSurface2 + card separation so light mode looks crafted, not blank. Dark mode stays as-is.

## Tests (mandatory — CEO asked for many)
- Unit: parse "50 кофе" / "350₽ кофе" / "Кофе 1000" → correct amount + category (guards B4); QuickAddSaveService writes exactly ONE transaction per call with the exact amount (guards B1).
- Unit/logic: detailed-form save succeeds with a valid entry (guards B3).
- Snapshot/UI (or #Preview hooks): quick-entry parsed state has no overlapping frames at default + large Dynamic Type (guards B7).
- Verify localization: no English category name / "Spent/Earned" under RU (guards B5).

## Process
- Reproduce → root-cause → minimal fix → test → verify on device (light + dark). Do NOT broaden scope beyond these bugs + D1.
- Build passes; commit per fix (`fix(quickentry): ...`, `fix(save): ...`, `fix(i18n): ...`, `fix(analytics): ...`, `feat(theme): warmer light surfaces`); push.
- If a bug traces to the demo-seed data (not code), fix the seed and say so.

## Report back
Per bug: root cause found, fix, test added, verified? Plus commit hashes, build status, and any bug you could NOT reproduce.
