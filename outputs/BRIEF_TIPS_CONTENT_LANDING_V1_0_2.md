# BRIEF (Claude Code) — v1.0.2: land the real tips library (5 locales), replacing the placeholders. Model: Sonnet. Branch `main` (per-user collection already merged, 4462535). Build + test before commit, push.

This is a **content drop**. The mechanism (TipDeck / TipCollection / LearnAndTipsView) already shipped — expect **no logic changes** beyond the one edge case in §3.

## 1. The files
Source files sit in `outputs/`. Copy each into the matching `.lproj` as `tips.json` (overwriting the 5-item placeholder library):

| source (outputs/) | destination |
| --- | --- |
| `tips_en_full.json` | `FinanceTracker/en.lproj/tips.json` |
| `tips_ru_full.json` | `FinanceTracker/ru.lproj/tips.json` |
| `tips_es-MX_full.json` | `FinanceTracker/es.lproj/tips.json` |
| `tips_pt-BR_full.json` | `FinanceTracker/pt-BR.lproj/tips.json` |
| `tips_uk_full.json` | `FinanceTracker/uk.lproj/tips.json` |

⚠️ The Spanish file is named `es-MX` (the copy is Mexican Spanish) but the app's folder is **`es.lproj`** — land it there; do not create an `es-MX.lproj`.

Already verified by me before handoff: all 5 parse, 102 entries each, ids unique, **id order identical across all five**, no empty fields. Schema per entry: `id`, `term`, `explanation`, `strategy`, `category`. Categories used: basics, saving, budgeting, mindset, spending, debt, income, habits, planning, household.

## 2. Verify the resources are actually bundled
The app target uses `PBXFileSystemSynchronizedRootGroup`, so files added under the target's folder sync automatically — but **confirm** each `tips.json` ends up in the built product for its locale (this bit us before with widget resources). If any locale's file isn't in the bundle, fix it and say so.

## 3. Edge case you MUST handle — this is a REPLACEMENT, not an append
The growth-safety design assumed appending. Here every placeholder id (`placeholder-001…005`) **disappears from the library**, while existing installs (my device, testers) already have those ids in their persisted revealed log. So:
- `tip(forID:)` / `tips(forIDs:)` must treat an **unknown id as skippable, never fatal** — no force-unwrap, no crash, no empty-hero.
- The collection view must render only resolvable ids; orphaned placeholder ids just vanish from the list.
- The deck/reveal must still produce a valid tip of the day for a user whose entire revealed log is orphaned (i.e. treat them as having 0 seen, reveal one today).
- Add a test: a revealed log containing only unknown ids → no crash, collection empty-ish, today's tip still resolves.

## 4. Terminology consistency — check, don't assume
Two tips use terms that are also live UI strings; the tip copy must match the app's existing localized wording exactly, or the app will call the same concept two different names:
- **safe-to-spend** (`safe-to-spend`, `the-number-not-spreadsheet`, `permission-not-restriction`) — EN "safe-to-spend", RU «свободно тратить», ES "disponible para gastar", PT-BR "livre para gastar", UK «вільно витрачати».
- **Pace** (`pace`, `weekend-slip`) — EN "Pace", RU «темп», ES "ritmo", PT-BR "ritmo", UK «темп».
Grep `Localizable.strings` in each locale for the shipped wording. **If a tip's term differs from the UI's, change the TIP to match the UI** (the UI is canonical) and report every change you made. Do not change UI strings.

## 5. Do NOT
- Do not run any "humanizer"-style rewrite over this copy. The register (restrained advisor, gain-framed, no humor, no idioms) is research-validated; a naturalising pass would break it.
- Do not reorder, add, or drop entries — the 5 files must stay parallel.
- Do not translate the product name: `Budget Crab` stays as-is in every locale.

## 6. Tests
- Parity: all 5 `tips.json` parse, have equal counts, identical id sequences, no empty fields. (Update whatever baseline the locale-completeness test asserts.)
- The deck produces 102 distinct tips before repeating; reveal cadence unchanged (one per calendar day).
- The §3 orphaned-id test.
- Full unit target green.

## Report (≤6 lines): files landed per locale + bundling confirmed, orphaned-id handling, any tip term you had to realign to the UI (§4), build/test, commit.
