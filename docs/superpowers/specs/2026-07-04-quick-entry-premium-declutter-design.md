# Quick Entry — Premium Declutter (Brief #3)

**Date:** 2026-07-04 · **Status:** approved-by-brief (execute + screenshot as review gate)

## Problem

The "+" Quick Entry screen reads as non-premium and overcrowded: the empty state
shows a prompt line *and* a "Details appear here as you type" skeleton card that
duplicates the input's own placeholder ("Type or say an amount" / "Starbucks 5.50"),
while a row of six saturated category tiles competes with the input + Save for
first-look attention. P1 research direction: single restrained mint accent,
simplified > feature-heavy, Quiet Premium, progressive disclosure.

## Decisions (grounded in the brief; no new user-facing strings)

1. **Kill the redundant skeleton card.** `previewCard(nil)` renders nothing instead
   of the "Details appear here…" skeleton. The parsed detail card appears *only after*
   a value is parsed (progressive disclosure). The empty state keeps ONE orientation
   line — the existing `quick_entry.prompt.amount` ("Type or say an amount") — which is
   distinct from (not a duplicate of) the input placeholder example.

2. **Quiet the category row so it doesn't out-shout the hero.** Chips stay (recognition
   + one-tap correction) but shrink 46→40 px tiles, labels 12→11 pt and muted, tighter
   spacing. The tile fill is already low-saturation (themeColor @ 0.16) — no component
   change. Row still scrolls horizontally.

3. **One primary action, clearer secondary.** Save stays the single filled mint capsule
   CTA. "Use detailed form" becomes obviously tappable (a prior complaint): accent-tinted
   label with a chevron and a real ≥44 pt tap target, instead of a faint grey footnote.

4. **Emphasize the parsed result.** Unchanged structure (amount 34 pt bold + direction
   pill + tappable category/merchant row) already leads; the quieted chips now sit below
   it as a secondary correction tool, so the result out-weighs the picker.

5. **Spacing polish** using the `Spacing`/`CornerRadius` tokens; more calm whitespace in
   the empty state where the skeleton card was.

## Non-goals / guardrails

- Preserve the B7 keyboard-avoidance structure (chips anchored in the fixed bottom
  cluster directly above the input; scroll region absorbs squeeze). No layout jump.
- No changes to parsing, category resolution, or the save path.
- No new localization keys → no parity-test churn. `quick_entry.preview.hint` simply
  becomes unused (left in place).
- Keyboard-accessory Save (B8) stays.

## Review gate

Before/after screenshots (Dark, small device — empty + parsed states) are the
acceptance artifact.
