# BRIEF (Claude Code) — v1.0.2 final fixes before submission. Model: Sonnet. Branch `main`. Commit per item, build + test before each commit, push. 5-locale parity on any string change.

Two items. **#1 is a submission BLOCKER** (device-diagnosed, evidence below — do not re-derive it). **#2 is cosmetic/brand**, ship in the same release if quick, otherwise say so and we defer to 1.0.3. They're independent — separate commits.

Ground rules carried from this whole session:
- **Report the mechanism before changing code** where a Step 0 is called for. Verify hypotheses against the code; several confident diagnoses this week were wrong until the device log settled them.
- Do NOT touch: the main-thread hang fix (`LedgerAggregator`/`ProactiveAlertRefreshScheduler`), the aggregation actor, the tip collection, the paywall derivation, or any data path. These are presentation-state and text-input-config only.

---

## 1. [BLOCKER] Editing a transaction dies after first use — `editTx` not reset to nil, and item-presentation only fires on nil→value

### Device evidence (two captures, EditPresentation os_log — this is FACT, not hypothesis)
Healthy open (works): `TAP-SET … editTxWasNil=true → BINDING editTx nil→X → DEST-INVOKED → EDITOR-APPEAR`.
Dead open: `TAP-SET … editTxWasNil=FALSE`, and even when the value changes — `BINDING editTx 100FCF42→5B26A24C` — there is **no `EDITOR-APPEAR`**.

Four established facts:
1. **The editor presents only on nil→value.** A non-nil→non-nil change silently no-ops (proven: `BINDING 100FCF42→5B26A24C` with no `EDITOR-APPEAR`). So once `editTx` is stuck non-nil, Edit is permanently dead until it's reset.
2. **The stuck state begins when one dismiss skips the reset.** Every healthy cycle logs `BINDING editTx X→nil` after `CHILD-DISAPPEAR`. The cycle that got stuck (`100FCF42`) **never logs `→nil`**.
3. **Strong lead for WHY the reset is skipped — concurrent list rebuild.** The stuck cycle is interleaved with `QuickAddSave #1…#4` and `periodCount` climbing `11→12→14→15`: the Transactions list was **rebuilding (rows inserted) while the editor dismissed**. The `editTx→nil` reset appears to be discarded when `ScopedTransactionList` / the `.id(scope)` parent re-evaluates concurrently with dismissal — points at the Stage-2 refactor `8a7f7bf`. **HYPOTHESIS — verify against that diff, don't assume.**
4. **Both Edit affordances fail; Delete works.** Founder repro: swipe-left → Edit AND long-press context-menu → Edit are both dead; Delete works throughout. Both Edit paths set `editTx`; Delete doesn't. `editTx` is the single point of failure. Also observed: the stuck row logs `DEST-INVOKED` dozens of times (vs ~4-5 normal) — the destination closure is re-evaluating excessively; investigate whether that re-creation is what drops the reset (symptom, maybe not root — report).

Everything else works during the dead state (list scrolls, tabs switch) → main thread is fine, this is a presentation-binding bug, not the hang. Backgrounding+foregrounding re-creates view state → `editTx`=nil → works again (explains "self-heals on re-entry", "fine on first launch", and why it took real interleaved use to catch — a fresh-state matrix can't see it).

### Step 0 — report before fixing
Find how the editor is presented on the Transactions surface and how `editTx` is bound (`.sheet(item:)` / `.navigationDestination(item:)` / `NavigationLink`). Enumerate **every** dismiss path (Done/Cancel, swipe-to-dismiss, edge-swipe back, programmatic) and identify which one(s), under a concurrent list rebuild, fail to set `editTx = nil`. Report the binding and the failing path.

### Fix — two parts
1. **Guarantee `editTx→nil` on every dismiss, including under a concurrent list rebuild.** Do not let the reset live somewhere a `.id(scope)` identity change can discard before it runs.
2. **Make the present path robust to an already-non-nil `editTx`** (safety net): tapping Edit must present the tapped row even if `editTx` is somehow still set — e.g. clear-then-set on the next runloop tick, or key the presentation on row identity rather than nil↔value. Pick the correct SwiftUI pattern and say why. No naive nil-then-set that adds a flicker/race.

### Tests — must reproduce the REAL trigger (interleaving), not a fresh-state open
The existing edit-presentation matrix is green because it opens/dismisses cleanly on fresh state. The repro is: same session, seeded store, **open editor → dismiss → insert a QuickAdd transaction (list rebuild) → open editor again → assert `EDITOR-APPEAR`/editor visible**. Also: assert `editTx == nil` after every dismiss; a value→value guard (force `editTx` non-nil, tap Edit, still presents); exercise BOTH affordances (swipe-action + context-menu).

---

## 2. Text fields offer Passwords/Contacts autofill — suppress it (privacy brand)

### The problem
Tapping a search or name field pops iOS autofill for **Passwords and Contacts**. On a privacy-positioned app this reads careless. Confirmed by grep: **no `TextField` or `.searchable` sets `.textContentType`**, so iOS guesses and offers credentials/contacts. The app has no logins — no field should ever offer them.

### Fix
Set the non-credential content type (`.textContentType(nil)` for SwiftUI — verify on device it actually kills the Passwords key; a `.searchable` field may need a different approach than a plain `TextField`, determine and report). Prefer a small shared modifier (e.g. `.plainTextEntry()`) applied across fields so it can't regress field-by-field. Never add a password/credential content type anywhere (we don't want AutoFill offering to save, either).

Surfaces (confirm the full set by grep, don't rely only on this list):
- **Search (priority — what the founder hit):** `TransactionsView:83`, `LearnAndTipsView:122`, `CategoryPickerSheet:77`, `SFSymbolPicker:79`, `SearchablePickerSheet:41`, `ElevatedSelectionList:65`.
- **Name/note/merchant:** AddCategorySheet, AddTransactionView (title/note/source name+note), EditTransactionView (merchant/note), CategoriesSourcesView (source name+note), QuickEntryView input, DashboardView QuickAdd.
- Amount/budget fields already use `.decimalPad`; set content type only if trivial.

### Verify (device)
Tap each search + name/note field → **no Passwords key, no Contacts bar** in the QuickType row; normal autocorrect still works where wanted.

---

## NOT in scope — already dispositioned this session, do not touch
- `Invalid frame dimension` + `_UIButtonBarButton width==0`: proven Apple keyboard-teardown noise (private UIKit classes, self-healing first-pass constraint), fires on keyboard dismiss (e.g. opening the "+" screen and swiping down). Not ours. No fix.
- Splash/launch crab: already fixed (04883f0 storyboard + 71c9104 SplashView).
- CFPrefs app-group read + `fopen errno=2`: benign, confirmed.

## Report (≤6 lines per item)
Item 1: Step 0 answer (binding + failing dismiss path), the two-part fix, whether `8a7f7bf` introduced it, the interleaving repro test, build/test, commit. Item 2: how you disabled autofill on TextField vs `.searchable`, full field list, shared modifier y/n, device no-passwords-key result, build/test, commit.
