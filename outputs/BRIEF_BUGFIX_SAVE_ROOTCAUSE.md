# BRIEF (Claude Code) — Root-cause the save/duplication cluster (it's NOT fixed)

Paste into Claude Code. **Model: Opus** (data-layer root-cause). The earlier view-wiring fixes did NOT hold — device stress test shows the core cluster is worse. **We keep going in circles because we never captured the real save error. There is now a RELIABLE repro — get the error FIRST, then fix the root. Do not patch the view layer again without the error.**

## 🔴 Reliable repro (device-confirmed 2026-07-02)
1. Settings → **Reset Transactions**. 2. Set a **monthly budget**. 3. Dashboard quick-add: type **`50 coffe`** → Save.
Result: transaction **duplicates ~10×** (Transactions shows 10× −$50 = $500), the quick-add preview **does not dismiss**, totals **disagree across screens** (donut $100, Transactions $500, Analytics −$300), and afterwards **every save fails with an error in the "+" sheet**.

## Step 1 — CAPTURE THE ERROR (mandatory, before any fix)
Run from Xcode on device, do the repro, and read the Xcode console. Capture:
- The **NSError from the save catch** (`domain=… code=… userInfo=…`) — the os.Logger line you added (dab158f). If it's not firing, add explicit `print`/`Logger.error` in EVERY `modelContext.save()` catch on the quick-add + detailed-form + reset paths.
- Whether `save()` is being **called multiple times per one user Save** (add a call-counter log at the save site) — the 10× duplication suggests a re-entrant/looping save (onChange, re-render, retry, or autosave + explicit save both firing).
Paste the error + call count back before fixing.

## Step 2 — Root-cause hypotheses to check (data layer, NOT view cosmetics)
- **Re-entrant save / render loop:** does the quick-add Save trigger a state change that re-renders and re-fires save? (10× = a loop that stops after N.) Check for `.onChange`/`.task`/binding writes that re-invoke save. This likely explains B1 (dup) + B2 (no dismiss = state never cleared).
- **Post-Reset context corruption:** after Reset Transactions, is the `ModelContext` / container left in a bad state so subsequent saves throw? Does Reset delete objects on the right context/actor? Does it leave the budget or an account in a dangling state?
- **Ghost rows from failed saves:** if `save()` throws mid-write, are partial rows left that later reads count? (Explains cross-screen total disagreement.)
- **Autosave vs explicit save:** is SwiftData `autosaveEnabled` on AND you also call `save()` → double writes / conflicts?
- **Threading:** any `save()` off the main context / not via the ModelActor?
The captured NSError code will point precisely (e.g. 133021 unique-constraint, 134060 validation, 267 file-protection, 134030 generic save).

## Step 3 — Fix + PROVE with a test that mirrors the real flow
- Fix the root (likely: make Save idempotent/guarded so it writes exactly once and clears state; and/or fix the Reset→context state).
- **Add a test that reproduces the REAL flow:** reset → set budget → quick-add save once → assert exactly ONE transaction exists and the pending state is cleared. The previous tests passed while the bug shipped → they didn't cover this. This test MUST fail before the fix and pass after.

## Other bugs in the same pass
- **B-loc (raw keys):** the Reset alert shows literal `general.alert.info.title` and `general.reset_success.message` → those keys are MISSING from Localizable.strings. **Audit ALL keys in all 5 locales for missing/untranslated keys** — grep every `Text("…")`/`LocalizedStringKey`/`String(localized:)` key used in code against each `*.lproj/Localizable.strings`; add a test/script that fails if any used key is absent in any locale. Fix all missing keys.
- **B-keyboard:** in the detailed Add form, the keyboard does NOT dismiss when editing the Note field. Add a dismiss affordance (tap-outside / Done / scroll-to-dismiss).
- **Parser note:** `50 coffe` (typo) → category Uncategorized is partly the lookup expecting "coffee"; acceptable. BUT the "+" sheet shows the amount ($60) AND "Couldn't read that" simultaneously — that false-error inconsistency must go (if amount parsed, don't show "couldn't read").

## Guardrails
- Do NOT modify the mechanic services if the bug is in the view/context wiring (services are unchanged since ae1ba21 and their unit tests pass — the bug is in HOW they're called + the reset/context flow).
- Build green; commit per fix; push. **Report the captured NSError + save-call-count first**, then the fix + the new failing→passing flow test.
