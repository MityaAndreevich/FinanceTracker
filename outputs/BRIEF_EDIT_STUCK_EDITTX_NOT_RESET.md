# BRIEF (Claude Code) — Edit transaction dies after first use: editTx not reset to nil on dismiss. Model: Sonnet. Branch `main`. BLOCKER. Report the exact dismiss path before fixing.

## The mechanism is captured on device — not a hypothesis this time
Device log (Debug, EditPresentation category), tapping Edit while it's dead:
```
DEST-INVOKED row=5B26A24C
DEST-INVOKED row=5B26A24C
TAP-SET row=5B26A24C periodCount=15 filtered=15 scope=month-2026-7 editTxWasNil=false liveChildId=1A7729ED
TAP-SET row=5B26A24C ... editTxWasNil=false ...   (×4, every dead tap)
```
Healthy trace (works): `TAP-SET … editTxWasNil=true → BINDING editTx nil→X → DEST-INVOKED → EDITOR-APPEAR`.
Dead trace: `editTxWasNil=FALSE`, **no `BINDING nil→X`, no `EDITOR-APPEAR`.**

**Diagnosis:** `editTx` (the item driving the Transactions editor presentation) is **not reset to nil when the editor is dismissed**, and item-presentation only fires on **nil→value** — so once `editTx` is stuck non-nil, edit is dead. Everything else works (founder: list scrolls, tabs switch, Delete works, only Edit is dead) → main thread is fine; this is a presentation-binding sync bug, not the hang. Backgrounding+foregrounding re-creates the view state → `editTx` back to nil → works again.

### SECOND, RICHER CAPTURE — refines the mechanism (do not re-derive)
1. **value→value does NOT present.** `TAP-SET … editTxWasNil=false` then `BINDING editTx 100FCF42→5B26A24C` (the value genuinely changed) but **no `EDITOR-APPEAR`**. So the presenter reacts only to nil→value; a non-nil→non-nil change silently no-ops. This is why a stuck non-nil `editTx` kills Edit permanently until reset.
2. **The onset: one dismiss skipped the reset.** Every HEALTHY cycle logs `BINDING editTx X→nil` after `CHILD-DISAPPEAR`. The cycle that got stuck (`100FCF42`) **never logs `→nil`** — the reset was dropped.
3. **STRONG LEAD for why it's dropped: concurrent list rebuild.** The stuck `100FCF42` cycle is interleaved with `QuickAddSave #1…#4` and `periodCount` climbing `11→12→14→15` — i.e. the Transactions list was **rebuilding (new rows inserted) while the editor was dismissing**. The `editTx→nil` reset appears to be lost when `ScopedTransactionList` / the `.id(scope)` parent re-evaluates concurrently with dismissal — points back at the Stage-2 refactor `8a7f7bf`. HYPOTHESIS — verify against the diff, don't assume.
4. **Both Edit affordances fail, Delete works.** Founder repro: swipe-left → Edit AND long-press context-menu → Edit are both dead; Delete works throughout. Both Edit paths set `editTx`; Delete doesn't. Confirms `editTx` is the single point of failure.
5. **Abnormal re-eval:** the stuck row logs `DEST-INVOKED` dozens of times (vs ~4-5 normally) — the destination closure is being re-evaluated excessively, suggesting the destination/binding is recreated on every list change. Investigate whether that re-creation is what drops the `→nil` reset. Symptom, possibly not root — report.

## Likely origin
The Stage-2 refactor `8a7f7bf` (`ScopedTransactionList` + `.id(scope)` + presentation registration hoisted to the parent). The dismiss no longer clears the item binding it once did. Verify against that diff.

## Step 0 — report before fixing
Find where the editor is presented on the Transactions surface and how `editTx` is bound: is it `.sheet(item: $editTx)`, `.navigationDestination(item: $editTx)`, or a `NavigationLink`? Then find **every** dismiss path — Done/Cancel button, interactive swipe-to-dismiss, edge-swipe back, programmatic — and identify which one(s) fail to set `editTx = nil`. The interactive/gesture dismiss is the prime suspect (it bypasses an explicit Done handler). Report the exact binding and the paths that don't clear it.

## Fix — two things, and the second is the one the richer capture exposed
1. **Guarantee `editTx→nil` on every dismiss, INCLUDING when the list rebuilds concurrently.** The reset is dropped specifically when new rows are inserted (QuickAdd) during dismissal and the scoped list re-evaluates. Ensure dismissal clears the binding regardless of a concurrent parent/child rebuild — do not let the reset live somewhere that a `.id(scope)` identity change can discard before it runs.
2. **Make the presenter robust to a stuck non-nil `editTx`.** Today a non-nil→non-nil change silently fails to present (evidence #1). Even after fixing the reset, defend against it: the Edit action must reliably present the tapped row even if `editTx` is somehow already non-nil (e.g. clear-then-set on the next runloop tick, or use a presentation that keys on the row identity, not just nil↔value). Pick the correct SwiftUI pattern and say why.
- Do not paper over it with a naive nil-then-set that reintroduces a flicker or a race; fix the reset (root) AND make the present path defensive (safety net).
- Do not touch the hang fix, the aggregation actor, or data paths. Presentation state only.

## Tests — the existing matrix passed BECAUSE it missed the real trigger; this must reproduce it
The edit-presentation matrix is green because it opens on a fresh state and dismisses cleanly. The real repro is **interleaving**: open editor → dismiss → **insert a transaction (or several) so the list rebuilds** → open editor again → assert it presents. Specifically:
- Same app session, seeded store. Open editor on row A, dismiss, **add a QuickAdd transaction** (this is the `periodCount`-changing rebuild that drops the reset), then tap Edit on row B → assert `EDITOR-APPEAR` / editor visible.
- Assert `editTx == nil` after each dismiss.
- A value→value guard: with `editTx` forced non-nil, tapping Edit still presents (the safety net from Fix #2).
- Exercise BOTH affordances: swipe-action Edit and context-menu Edit.

## Report (≤6 lines): the exact binding + which dismiss path failed to clear it (Step 0), the fix, the new same-session repro test, whether 8a7f7bf introduced it, build/test, commit.
