# BRIEF (Claude Code) — v1.0.1 Widget visual redesign: Liquid Glass + ambient chart (Direction B, APPROVED). Model: Sonnet. Skills: apple-hig-expert (Liquid Glass / WidgetKit HIG — READ the WidgetKit "Implementing Liquid Glass" guidance), swiftui-design-skill, high-end-visual-design, emil-design-eng.

**v1.0.1 (1.0 in App Review — don't touch the submitted build).** `main`, commit per unit, push, `xcodebuild … build` before each commit. This is a **visual** pass on the EXISTING widget — reuse the shipped v2 `NetSnapshot` data contract, the gain-frame hero precedence, `contentSignature` reload, `Money.formatCompact`, semantic tokens, and the localization/baked-language work already landed. Do NOT change the data contract or hero logic. Localize any new strings in all 5 locales.

## Design was approved visually by the CEO (a chat mockup). This brief is the spec. Match it; don't reinterpret.

### The look (Direction B + ambient chart, calm palette)
- **Hero:** gain-framed number is the dominant element, bottom-left weighted. Normal month → "Свободно / Free {safe-to-spend}" with a secondary "из {income/budget}" line + a small up-tick. Over budget → "Превышение / Over budget {amount}" with a restrained **terracotta** number + an alert glyph + the word — **never a full red card fill.**
- **Ambient spend chart:** a subtle area+line sparkline of the period's cumulative spend, sitting behind/below the number as an ambient layer (this is the element borrowed from the approved reference). Low opacity so the number stays legible. Positive/normal = calm green tint; over-budget = muted terracotta tint. Guard it with the same ChartGuards discipline (isFinite, ≥0, degenerate/empty → no chart, never a crash).
- **Icon chip** top-right (small rounded translucent chip holding the app/pie glyph).
- **Palette (non-negotiable, traces to research):** green ONLY on positive/income; spend muted; over-budget = restrained terracotta + icon + word, NOT alarm-red, NOT a saturated card fill. Accessibility: state conveyed by icon+label, never hue alone.
- Typography: hero number large + tight tracking; labels secondary; category rows (medium/large) tertiary with hairline mini-bars. Match the app's type scale.

### Material — system Liquid Glass, NOT hand-rolled glassmorphism
- Adopt the **system material**: `.containerBackground(.liquidMaterial, for: .widget)` (per the WidgetKit Liquid Glass guidance). Let the SYSTEM render the glass/tint/refraction. **Do NOT hand-build blur, gradients, or drop-shadows to fake glass** — hand-rolled glass fights the system material and looks dated on iOS 26. Content (number, chart, rows, chip) stays **opaque** on top of the glass, per HIG (glass = container/material layer; content stays solid).
- **Build toolchain:** confirm the project builds on **Xcode 26 / iOS 26 SDK** (Liquid Glass auto-adopts on recompile). **Report the current deployment target and Xcode/SDK version FIRST** — the material path and the fallback depend on it.
- **Fallback for < iOS 26:** if the deployment target includes iOS 17/18, gate the material with `if #available(iOS 26, *)` and fall back to a **calm opaque card** (the current card, but corrected: proper adaptive background, no flat-white-on-white). Both paths must pass the calm-palette + no-truncation rules.

### Ambient chart per size
- **Small:** hero + ambient chart + chip (no category rows — keep it clean).
- **Medium / Large:** hero + ambient chart + top categories with hairline mini-bars (medium ~2, large ~3) + (large) a compact spent/earned footer. Category bars use muted spend color; income green only.

## Truncation / formatting (regression guard — we already hit this)
- Use `Money.formatCompact` for the hero and any constrained number; `minimumScaleFactor` + deliberate `lineLimit(1)`; **no ellipsis in any shipped state.** Check the LONGEST locale (ru / pt-BR) — labels like "Превышение бюджета" must not clip.

## Variants (Item 6 from before — keep, don't expand)
- The AppIntent config (Ring / Minimal / …) stays; if the ambient-chart look supersedes the old "Ring" variant, reconcile them but keep **≤2 variants**, both obeying this spec. Config labels stay localized (the .strings you added).

## Tests (targeted)
- Hero precedence unchanged (budget / income-only / neither / over-budget) — reuse existing tests.
- Ambient chart guards: empty/degenerate period → no chart, no NaN/crash; over-budget uses terracotta tint not red.
- `#available(iOS 26)` branch selects material; older branch selects the opaque calm card (both compile).
- `formatCompact` at the hero; longest-locale no-truncation check.
- Over-budget state asserts icon+label present (not hue-only).

## Report (≤6 lines/unit): FIRST the deployment target + Xcode/SDK version and whether `.liquidMaterial` is available; then the layout/material/chart changes, files, build status, commit hash per unit. **MANDATORY visual verification:** since this is a pure look pass and the material is system-rendered, attach **screenshots** of all sizes in **3 home-screen modes (default / dark / tinted-or-clear)**, normal + over-budget, from the simulator (`xcrun simctl` on an iOS 26 device). If you cannot produce simulator screenshots, say so explicitly and I'll have the human capture them before we call it done — do NOT close this on build-success alone; the whole point is how it looks.
