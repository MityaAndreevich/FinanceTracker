# BRIEF (Claude Code) — Dashboard color semantics + voice hint layout (v1.0 polish, visible first-impression). Model: Sonnet.

Two device-QA issues on the marquee surfaces (Dashboard + voice Quick Entry). Both are visible on first use → fix for v1.0. Do NOT touch save/parser/CSV/entitlement mechanics. Build green, commit per item, push. Device-verify where noted (voice can't repro under simctl).

## Token discipline
Sonnet. Grep-first to find the Dashboard spending card + the QuickEntry voice hint. Read only those. **Targeted/structural fixes**; no suite-wide runs, no UI-presentation tests (these are visual — verify on device).

## Item 1 — Dashboard: expenses read as INCOME because of green (perception bug)
Device: on the Dashboard "Spending by category" card, the spending ring AND the "SPENT $160.00" total render in the **income-green**. With a single category (and a budget that isn't exceeded yet) the whole card reads as **positive/gain** — a finance app where your spending looks like income. Undermines trust on the first screen.
- **Fix:** the SPENT total must NOT use the income/positive green. Render it in a **neutral/primary** text color (or the expense-directional color) so spending never reads as a gain. Keep income strictly green; ensure income vs expense are visually distinguishable at a glance across the Dashboard.
- The multi-color category palette is fine, but a single-category **expense** donut must not present as the pure income-green. If the palette's first color is the income-green, use a different lead color for expense categories, or desaturate/neutralize so it doesn't signal "positive."
- Stay consistent with the existing direction: safe-to-spend was already made neutral (not green); calm base + green/coral, green reserved for positive. Apply the same logic here.
- Verify on device in Dark (default) + Light, one-category and multi-category, with and without a budget set.

## Item 2 — Voice hint STILL wraps one-char-per-line + janky voice/text switch (previous fix dcd34ca did NOT hold)
Device (17:27): during voice input the hint "Введите или скажите сумму" is still stacked **one character per line** ("Введ/ите/или/скаж/ите/сумм/у"), and switching between voice and text modes shows **torn/janky movement**, not a smooth transition. The earlier animation opt-out did not resolve it.
- **Re-diagnose properly:** the label is being laid out at ~0/collapsed width during the mode transition. The opt-out wasn't enough — likely the container width itself is animating from 0, or the voice-mode and text-mode layouts are separate paths and only one was fixed.
- **Fix structurally:** give the hint label an **explicit, stable width** (e.g. pinned to screen width minus horizontal padding, `.frame(maxWidth: .infinity)` + fixed padding + `.multilineTextAlignment(.center)`), NOT an animated/derived width. Ensure **both** voice-mode and text-mode use the **same stable container** so switching doesn't reflow the label.
- **Smooth the transition:** replace the resize-based mode switch with a **fixed-height container + cross-fade (opacity)** between the voice panel and text bar, so toggling modes doesn't produce torn movement.
- Cannot repro headlessly (speech doesn't run under simctl). Ship the structural fix; report exactly what you changed and why the previous fix missed. I will device-verify.

## Report
Item 1: what color/token changed + confirm income vs expense distinct. Item 2: why dcd34ca missed and the new structural approach. Files changed, build status, commit hashes. Target v1.0 — land before the final clean-reinstall QA pass.
