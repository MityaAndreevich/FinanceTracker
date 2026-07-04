# BRIEF (Claude Code) — Quick Entry: keyboard/Save overlap + category auto-detect + premium declutter

Paste into Claude Code. **Restart CC first (superpowers active).** Model: **Sonnet**; use `systematic-debugging` for the category issue (#2), `brainstorming`→`writing-plans` for the redesign (#3). Verify every item with device-size screenshots (Dark).

Context: on the latest build the save/duplication cluster no longer reproduces on device (clean single saves, no dup, no error) — the anti-poison guard held. These are the REMAINING quick-entry issues found on device 2026-07-04.

## 1. Keyboard covers the Save button (functional — HIGH)
On the "+" Quick Entry screen, when the keyboard is up (and especially once a parse-preview appears), content slides onto / overlaps the **Save** button, and there's no way to save while typing.
- Add proper **keyboard avoidance** so the input + preview + Save never sit under the keyboard (ScrollView + safe-area/keyboard inset, or move Save into a pinned bottom bar above the keyboard).
- Add a **Save affordance reachable with the keyboard up**: either make the keyboard **return key = Save** (submitLabel(.done)/onSubmit) and/or a keyboard toolbar "Save" button. User must be able to commit without dismissing the keyboard.
- Verify on a small device (SE/mini) and with large Dynamic Type — nothing clips or overlaps.

## 2. Category is NOT auto-detected (core value — HIGH; use systematic-debugging)
On device, typing an expense yields category **Uncategorized**; only manual tile selection works. Our whole "smart entry" wedge depends on auto-categorization working.
- **Diagnose first (don't rewrite the parser blind):** is `CategorySuggestionService` actually invoked on the quick-add path, and does it return for COMMON inputs? Test proper terms, not just the typo: `coffee`, `Starbucks 5.50` (your own placeholder!), `uber 20`, `groceries 40`, `rent 1000`.
  - If `coffee`/`Starbucks` also return Uncategorized → the service is **not wired** into this UI path, or its lookup table is empty/incorrect → fix the wiring / seed the keyword→category map for the top ~30 merchants+keywords per default category.
  - If only the typo `coffe` fails but `coffee` works → acceptable, but add light fuzzy/prefix matching so near-misses (`coffe`, `starbuks`) still resolve.
- Add unit tests: given each of the common inputs above, assert the resolved category is the expected one (not Uncategorized). Red→green.
- Guardrail: keep changes scoped to category resolution; do NOT touch the amount/name parsing or the save path (both work now).

## 3. Premium declutter of the entry screen (design — grounded in our research)
The screen feels non-premium and overcrowded (title + "details appear here" card + full colored category row + input + Save + form link all competing at once). Apply our P1 findings: **single restrained mint accent, simplified > feature-heavy (+111%), Quiet Premium, progressive disclosure.**
Direction (implement, then screenshot):
- **Kill redundancy:** the "Details appear here as you type" placeholder card duplicates the input placeholder ("Starbucks 5.50"). Keep ONE. Show the parse-preview inline only AFTER the user types.
- **Hierarchy:** the input + mic is the hero. The category row is a **secondary correction tool** — shrink it / reduce saturation / let it scroll, so 5 colored tiles don't compete with the primary action on first look. (Multi-color category tiles are OK for recognition, but they must not out-shout the input + Save.)
- **One primary action:** Save = the single filled **mint** CTA. "Use detailed form" stays a clear but secondary text button (it must still be obviously tappable — that was a prior complaint).
- **Parsed state:** once a value is parsed, emphasize the result (amount + category + name) + Save; de-emphasize the picker.
- More whitespace, calm base, consistent spacing. No visual noise; match the "premium private-banking" feel.

## 4. Fix the stale DemoSeeder test (same run, quick)
`DemoSeederTests.testSeed_creates_anomaly_transaction` fails because the no-affluence reseed caps at ~$93, but the test expects a Food & Drink expense >$100. This is a STALE test, not a regression — we deliberately removed big numbers.
- **Relax the test**, don't inflate the seed: assert the anomaly via the seeder's OWN anomaly mechanism/flag, not a hardcoded $100 threshold. Keep the seed data as-is. Build green.

## Guardrails
- Localize any new/changed strings in ALL 5 locales (en/ru/es/pt-BR/uk); update parity test.
- Accessibility: tap targets ≥44pt, Dynamic Type, VoiceOver labels.
- Build green; commit per item; push. Report: files changed, build status, commit hashes, category-test results, + before/after screenshots of the entry screen (empty + parsed).
