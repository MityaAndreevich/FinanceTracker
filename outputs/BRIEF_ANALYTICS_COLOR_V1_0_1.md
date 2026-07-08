# BRIEF (Claude Code) — v1.0.1 Analytics redesign + Color system. Model: Sonnet (switch to Opus only if the color/theme change touches many files). Skills: swiftui-design-skill, apple-hig-expert, high-end-visual-design, emil-design-eng, review-animations, impeccable (for /critique + /polish design vocabulary — its auto-detectors are web-only, ignore those; use the guidance).

**This is a v1.0.1 cycle (1.0 is in App Review — do NOT touch the submitted build path).** Work on `main`, commit per item with conventional prefixes, push, `xcodebuild … build` before each commit. Keep all v1.0 bug fixes intact: CSV integrity, premium gate, ChartGuards NaN sanitization, amount parser, dedup/UUID, QuickEntry fixes. Do NOT reintroduce any anti-pattern in CLAUDE.md (shared Money.swift, `tx.isIncome`, `@AppStorage("defaultCurrencyCode")`, single `CategoryPickerSheet`, no per-view formatters). Localize every new string in ALL 5 locales (en/ru/es-MX/pt-BR/uk) — no hardcoded English.

## Why (research, don't re-derive) — source: outputs/ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md
- Gain frame beats loss frame: loss pain ≈ 2× gain; "safe to spend $X" lowers anxiety vs "you spent $X" (gain framing +23% conv, Strava).
- Alarm-red raises measurable autonomic arousal → anti-pattern for our calm/Quiet-Premium positioning; 70% of our target feel financial anxiety (P3).
- Current device bug: expenses render in income-green (reads spend as positive). Must fix to green=income only.
- Accessibility (required): color is never the only signal — ~8% of males are red-green colorblind. Pair every income/expense/positive/negative signal with an SF Symbol + text label. Red is not universally negative (positive in some markets) → don't hard-code red=expense.

## Scope = 5 items. Read only what you edit (grep first).
Likely files (verify by grep, don't assume line numbers): `Views/AnalyticsView.swift`, `Views/AnalyticsPulseView.swift`, the donut/breakdown view, any existing theme/color definitions (grep `Color(` , `.foregroundStyle`, `Assets.xcassets` color sets), `Shared/Money.swift`, `Shared/ChartGuards.swift`, `@AppStorage("defaultCurrencyCode")`, Localizable.strings (all 5).

### Item 1 — Color system (do FIRST; everything else consumes it)
Create ONE semantic color layer (e.g. `Shared/AppColors.swift` or an asset catalog color set) — no per-view hex. Semantic tokens, not raw colors:
- `income` = green (reserved strictly for income/positive net).
- `expense` = **neutral/muted** (e.g. secondary label / soft slate — NOT bright/alarm red).
- `positiveNet` / `negativeNet`, `neutral`, plus category-palette (multi-color OK for the donut per prior design decision — a single mint accent app-wide, but charts may use a small multi-hue set).
- **Scheme picker** in Settings: `@AppStorage("colorScheme")` enum `{ calm (default), classic }`. `calm` = the muted default above; `classic` = traditional red expense / green income for users who want it. Default MUST be calm.
- **Accessibility helper:** every place that currently signals by hue must also render an SF Symbol + localized label ("Income"/"Expense"). Add a small reusable `Label`/badge component so this is consistent.
- Migrate existing analytics/transaction/Pulse views to the semantic tokens. Remove the bug where expenses use the income-green path (route through `tx.isIncome`).

### Item 2 — Safe-to-Spend as the hero (gain-framed)
- Make Safe-to-Spend the single most prominent element of the analytics dashboard (large title ≥34pt, or the center of the donut). Copy is gain-framed: "Safe to spend {amount}" (localized), NOT "You spent {amount}".
- Reuse the existing safe-to-spend computation if present (grep `safeToSpend` / safe-to-spend); if it lives in a service, don't duplicate. Format via `Shared/Money.swift` (respect `defaultCurrencyCode`).
- Keep the ChartGuards invariants — never feed non-finite/negative to Charts; degenerate input → calm empty state, not a crash.

### Item 3 — "Pace" velocity cue
- Add a spending-velocity indicator: are they spending faster than the days remaining in the period imply? Compute generically (spent-so-far vs elapsed/remaining days of the current PeriodScope). Show a short localized cue ("On pace" / "Spending faster than usual" / "Under pace") with icon+label, calm colors (not red).
- Name it generically ("Pace") — do NOT copy any competitor's branded/trademarked metric name or wording.
- Must be meaningful with few transactions and must not divide by zero (guard days-remaining==0, empty period).

### Item 4 — Donut done right
- Limit to **3–5 segments + an "Other" bucket**; each segment paired with an SF Symbol + localized category label (not color-only).
- Never render a single-category expense in income-green (uses the new semantic tokens).
- Keep ChartGuards sanitization; sparse/one-category data still renders calmly.

### Item 5 — Kill the blank "insights coming later" state
- Remove the blank-slate placeholder. On first open, show the simple donut + Safe-to-Spend immediately, seeding from the existing onboarding demo data if the user has no/low real data (we already have demo data — reuse it, clearly non-destructive). Goal: user sees value before entering many transactions (Headspace-style 96% activation pattern).

## Explicitly OUT of scope for this brief (do NOT build now)
Full/manual net worth, retirement forecasting, debt payoff, Sankey, "Age of Money" (IP), month-over-month trend, cash-flow calendar. These are v1.x, gated on data/fit. Widget redesign is the NEXT brief (it consumes this color system) — don't start it here.

## Tests (targeted, TDD where it fits — no suite-wide runs)
- Color: `income` token used only for income; `expense`/net never uses the income-green path; scheme picker toggles calm↔classic; default == calm.
- Pace: velocity math correct across a filled period, empty period (no crash / neutral), and days-remaining==0.
- Safe-to-Spend + donut: gain-framed string localized in all 5 locales; donut caps at 5 + Other; ChartGuards still rejects non-finite.
- No accessibility regression: income/expense conveyed by icon+label, not hue alone (assert the label/symbol is present).

## Report (≤6 lines/item per CLAUDE.md): what changed, files touched, build status, commit hash per item. Flag anything that turned into a bigger refactor than expected (esp. if the color migration sprawls — then switch to Opus and tell me). Device-verify: calm palette reads correctly in Dark + Light, income green / expense muted, Safe-to-Spend hero legible, no blank analytics state, Pace shows with sparse data.
