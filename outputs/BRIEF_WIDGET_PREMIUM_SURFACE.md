# BRIEF (Claude Code) — v1.0.1 Widget premium surface (adaptive mint/dark). Model: Sonnet. Skills: apple-hig-expert, high-end-visual-design, swiftui-design-skill.

**v1.0.1 (1.0 in App Review — don't touch the submitted build).** `main`, commit per item, push, `xcodebuild … build` before commit. Visual-only — do NOT change NetSnapshot contract, hero precedence, spendSeries, contentSignature, localization. Widget file only.

## Context (decided, don't re-litigate)
- Liquid Glass on a home-screen widget is impossible (proven on device: dock refracts a photo wallpaper, widget stays opaque; `WidgetTexture.glass` is visionOS-only). `glassEffect` on the container = a no-op → **revert it**.
- The flat-white opaque card read cheap. CEO approved an **adaptive premium gradient surface**: **light mode = brand mint tint, dark mode = deep charcoal-teal.** Quiet-Premium = calm, low-contrast gradient (adjacent tones), NOT a loud/saturated fill.

## Item 1 — Revert the dead glassEffect
Revert commit 7bbe0ce (container `glassEffect`) back to a `containerBackground`-based card. The surface is now the gradient below, not glass.

## Item 2 — Adaptive gradient surface
Replace the flat surface with a subtle `LinearGradient` (top-leading → bottom-trailing, ~155°) via `containerBackground(for: .widget)`. Use **asset-catalog colorsets or semantic tokens** with light/dark variants (don't hardcode one mode). Target tones (match intent, tune to our existing `bc*` palette — these are the mockup values):
- **Light (mint):** from `#EFFAF5` → `#D7EFE6`; hero number `#123F33`; "Можно потратить" label + up-arrow `#0F6E56`; subtitle `#4A7D6D`; month `#0F6E56` @~70%. Hairline `rgba(15,110,86,0.10)`.
- **Dark:** from `#2A3238` → `#151A1E`; hero number white; label + up-arrow `#6FE3BF`; subtitle white @~55%; month white @~55%.
- Keep depth subtle (the gradient + the system widget shadow) — no heavy inner shadows, no glow.

## Item 3 — Ambient chart tuned per surface
Keep the ambient spend sparkline; adjust so it reads on BOTH new surfaces:
- Light/mint: fill `#1D9E75` @~20%, stroke `#0F6E56` @~60%.
- Dark: fill `#3FD39E` @~22%, stroke `#4FE0AC` @~85% (the "glow" that makes dark look premium).
- Keep the subtitle-band separation (68cbf3b) so the line never crosses "из … дохода". Keep ChartGuards (isFinite, clamp, empty → no chart).

## Item 4 — Re-verify the OTHER states on the new surfaces (regression guard)
- **Over-budget terracotta** must stay legible on BOTH surfaces: on dark, a mid terracotta may be too dark — use a lighter terracotta (e.g. `#F0997B`/`#F0A98F`) so it reads; on mint, ensure it doesn't clash with the green tint. Icon+word stays (accessibility). Never a red bath.
- **Category rows / footer** (medium/large): income green only, spend muted; check contrast on mint and on dark (the pale mint bars/track need enough contrast).
- Text contrast ≥ 4.5:1 in both modes for all labels.

## Tests (targeted)
- `#available` light/dark colorsets resolve; over-budget terracotta path renders on both surfaces.
- Ambient guards unchanged; subtitle non-overlap held.
- Hero precedence / formatCompact / longest-locale (ru "Превышение бюджета") no-truncation unchanged.

## Report (≤6 lines/item): revert confirmed, the gradient approach (colorsets used), chart tuning, over-budget re-check result, files, build, commit per item. **MANDATORY screenshots over a PHOTO wallpaper (iPhone 17 / iOS 26.5), all 3 sizes, light + dark, plus one over-budget** — the whole point is the surface now reads premium, not cheap-white. If simctl can't place home-screen widgets, capture the Xcode preview canvas over a photo background at minimum, and the human will do the final home-screen pass.
