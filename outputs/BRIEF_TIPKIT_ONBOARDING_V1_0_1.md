# BRIEF (Claude Code) — v1.0.1 TipKit contextual onboarding + help. Model: Sonnet. Skills: apple-hig-expert (TipKit HIG), swiftui-design-skill, high-end-visual-design, emil-design-eng (tip appearance/dismissal motion), review-animations.

**v1.0.1 (1.0 in App Review — don't touch the submitted build).** `main`, commit per unit, push, `xcodebuild … build` before each commit. Localize every string in ALL 5 locales. Reuse semantic color tokens + `Shared/Money.swift`. Don't reintroduce CLAUDE.md anti-patterns.

## Why (research — source: outputs/ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md §4. Don't re-derive.)
- **Interactive + contextual beats static annotated screenshots.** This brief *replaces* the earlier "Help & Tips annotated screens" idea.
- Interactive sandbox with demo data → **96% activation** (Headspace). We already ship onboarding demo data — strengthen it, don't rebuild it.
- **Progressive disclosure** ("teach one thing well" first) → **+23% conversion** (Blinkist). Do NOT tour every tab.
- **TipKit contextual tips** (non-modal, anchored near the element) beat screen-dimming coach-marks.
- **Goal-narrative** prevents the mid-onboarding slump (e.g. "this Safe-to-Spend view protects your vacation fund").
- Anti-patterns to avoid: prerequisite full tutorials, modal takeovers, noisy confetti (measurably hurts premium trust).
- Retention context: **55% of trial cancellations happen Day 0** — the user must reach the "aha" inside the first 60 seconds. Tips exist to shorten time-to-aha, not to decorate.

## Scope — small, surgical. Do NOT build a tutorial system.
Use Apple's **TipKit** (`Tips.configure`, `TipView` / `popoverTip`, `Tips.Event`, `@Parameter` rules). Grep first for any existing onboarding/demo-data/help code and extend it.

### Unit 1 — TipKit foundation
- Configure TipKit at launch (`Tips.configure` with a sensible `displayFrequency`, and `datastoreLocation` that survives normal use but is resettable).
- Add a debug affordance to reset tip state (`Tips.resetDatastore()`) behind an existing debug/settings path, so QA can re-run first-run flows without deleting the app.
- **Tips must never appear while the App Review demo/screenshot flows run** if any such flag exists — check.

### Unit 2 — Exactly 3 tips, no more (progressive disclosure)
Ship **three** tips, each with a display rule so it fires at the right moment, and each dismissible forever:
1. **Quick Add** (highest value, marquee feature): anchored at the "+" / Quick Add field. Rule: shows on first Overview appearance. Copy teaches the *natural-language* input ("try: кофе 350"), not the button.
2. **Safe-to-Spend hero** (the goal-narrative tip): anchored at the Dashboard hero. Rule: shows **after the user has saved their first transaction** (`Tips.Event`), so it lands when it's meaningful, not on an empty screen. Copy is gain-framed and ties to a goal ("This is what's safe to spend — the rest is protecting your plan").
3. **Category / Analytics** — anchored where the donut or category picker lives. Rule: shows after **≥3 transactions** exist (`@Parameter` + event count), so it never fires on an empty chart.
- Not one tip more. Every extra tip taxes the first-run flow and pushes the "aha" further out.

### Unit 3 — Strengthen the demo/sandbox path (don't rebuild it)
- Verify the existing onboarding demo data makes the Dashboard + Analytics **immediately meaningful** (this pairs with the "no blank analytics state" work already shipped).
- Clearly non-destructive and clearly removable — the user must be able to tell demo data from their own and clear it in one step. Never let demo rows leak into CSV export or the widget snapshot as if they were real.

### Unit 4 — Retire the static help plan
- If an annotated-screenshots / static help screen exists or is stubbed, demote it to a secondary reference (Settings → Help), NOT the primary teaching surface. Don't invest in it further.

## Explicitly OUT of scope
Full tutorial/coach-mark system, modal onboarding takeover, confetti/celebration animations, gamification, streaks, any tip that fires on an empty screen, tips that block interaction.

## Motion / craft
Tip appearance and dismissal must feel Apple-native: correct easing (enter ≠ exit), no bounce, no attention-grabbing pulse. Non-modal, never blocks a tap. Respect Reduce Motion.

## Tests (targeted — no suite-wide runs)
- Each tip's display rule: Quick Add on first Overview; Safe-to-Spend only **after** the first saved transaction; Analytics tip only at **≥3** transactions (0/1/2 → not shown, 3 → shown).
- Dismissal persists across relaunch; `resetDatastore()` restores.
- No tip renders on an empty/zero-data screen.
- Demo data never appears in CSV export or the widget snapshot as real data.
- 5-locale string parity for all tip copy; longest locale (ru/pt-BR) doesn't truncate the tip body.

## Report (≤6 lines/unit): tips shipped + their exact rules, where TipKit is configured, what changed in the demo path, files, build status, commit hash per unit. Device-verify (yours): fresh install → first-run sequence shows exactly one tip at a time, in order, none on an empty screen; dismissal sticks; Reduce Motion respected; Dark + Light; check the longest locale for truncation.
