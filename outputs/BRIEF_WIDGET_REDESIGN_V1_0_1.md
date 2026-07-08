# BRIEF (Claude Code) — v1.0.1 Widget redesign. Model: Sonnet. Skills: swiftui-design-skill, apple-hig-expert, high-end-visual-design, imagegen-frontend-mobile (optional: generate a reference comp for the 3 sizes first, then implement — do NOT ship its output, it's web-oriented; use only as visual reference), emil-design-eng.

**v1.0.1 cycle (1.0 in App Review — don't touch the submitted build).** `main`, commit per size/unit, push, `xcodebuild … build` before commit. Reuse the shipped semantic color system (`Color+Semantic.swift` + `bc*` asset colorsets) and `Shared/Money.swift`. Localize all new strings in ALL 5 locales. No hardcoded English. Don't reintroduce CLAUDE.md anti-patterns.

## Why (device feedback + our research, don't re-derive)
- Current widget is off-brand and uninformative: **small** = one cut-off raw number + tiny icon; **large** = monochrome list of huge raw category totals, no hierarchy, doesn't match the app's calm/rounded look; not glanceable/actionable.
- It DOES read App Group data correctly (the earlier CFPrefs warning is cosmetic — do not chase it).
- Our own analytics research: the single most useful glanceable number is **Safe-to-Spend / Remaining**, gain-framed (loss pain ≈ 2× gain). Widgets are a glance surface → lead with it, ring for progress. Matches the in-app hero + the competitor pattern (Budget / Remaining with a ring).

## Step 0 — verify the data contract FIRST (grep, don't assume)
Grep the widget + App Group snapshot type (memory: `NetSnapshot` / `NetSnapshotBuilder`, `WidgetCenter.reloadAllTimelines`). Confirm the snapshot already carries — and if not, ADD to the builder (writes on the debounced save path already in place):
- `safeToSpend` (or remaining-this-period) amount + the currency (`defaultCurrencyCode`).
- `budgetTotal` for the current period (for the ring denominator + "of $Y"). If no budget is set, ring falls back to spent-vs-income or a neutral state (see below).
- `spent` and `earned` for the current period.
- `topCategories`: top 2–3 by spend, each {localized name, SF Symbol, amount, fraction}.
Keep the builder off the main thread / on the existing debounce; don't add a second write trigger. Reload timelines on save as today.

## Design (consume semantic tokens, calm, rounded)
Ring = progress of spent vs budget (or vs income if no budget). Colors: green = income/positive only; spend = muted/neutral (terracotta), never alarm-red; ring track = neutral. Rounded cards, app type scale, icon+label (accessibility — not hue alone). **Compact/abbreviated number formatting** for large values (e.g. `$12.3K`) so nothing truncates — add a compact formatter path in `Money.swift` (don't create a per-view formatter).

### Small (systemSmall)
Ring + **"Safe to spend {amount}"** (gain-framed, localized) in the center or below; optional tiny "of {budget}" subline. One clear glanceable number. No raw category dump.

### Medium (systemMedium)
Ring + safe-to-spend on the left; **top 2–3 categories** on the right as name + SF Symbol + mini bar (fraction of spend). Calm, hierarchical — not a monochrome list.

### Large (systemLarge)
Ring + safe-to-spend hero at top; **top categories** with mini bars; a compact **spent / earned** footer row (earned in income-green, spent muted). Optional period label ("This month").

## States & guards
- **No budget set:** don't show an empty/00 ring — show spent this period + a neutral ring (or income-vs-spent), and keep safe-to-spend if it's computable without a budget; otherwise show "Spent {amount}" gain-neutral. No blank/placeholder-only widget.
- **No/low data (fresh install):** calm seeded/zero state with the app mark, never a broken or cut-off number.
- Guard all fractions/ring values: `isFinite`, clamp 0…1, guard divide-by-zero (same discipline as ChartGuards). A degenerate value must never crash or render a negative/oversized ring.
- Deep-link: tapping the widget opens the app (to Dashboard/Add) via `widgetURL`/`Link` if not already wired — keep it simple.

## Tests (targeted)
- Snapshot builder: safe-to-spend / budget / spent / earned / topCategories populated correctly from sample data; top-categories capped at 3 and sorted.
- Compact formatter: `1234`→`$1,234`, `12345`→`$12.3K`, locale-correct separators (round-trip in ru_RU/pt_BR), no truncation.
- Ring fraction guards: budget==0 → neutral state (no NaN/crash); fraction clamped 0…1; negative/no-data → safe state.
- 5-locale string parity for new keys.

## Report (≤6 lines/size): data-contract changes to the snapshot, each size's layout, compact formatter, files changed, build status, commit hashes. Device-verify: add all 3 widget sizes to the home screen, Dark + Light, with a budget set AND with none, large values don't truncate, calm palette (green=income only), ring correct. If you generate a reference comp with imagegen-frontend-mobile, attach it but implement natively in SwiftUI (its output is web-oriented — reference only).
