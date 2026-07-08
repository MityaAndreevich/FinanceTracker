# BRIEF (Claude Code) — Fix Swift Charts NaN crash (PRIMARY) + main-thread Core Data hang. Model: Sonnet + systematic-debugging.

**Priority: LAUNCH BLOCKER — hard crash (EXC_BREAKPOINT) confirmed inside Swift Charts.** Do NOT touch save-correctness/CSV/entitlement logic. Build green, commit per item, push.

## Item 0 — CONFIRMED crash root cause: Swift Charts fed a non-finite value (fix FIRST)
Device `bt` (Thread 1, main-thread) — the trap is INSIDE Apple's `Charts` framework during render:
```
frame #0–9:  Charts`___lldb_unnamed_symbol… (recursive scale/layout compute → brk #1)
frame #10–14: SwiftUICore`CanvasDisplayList.updateValue()
frame #20–24: SwiftUICore`ViewGraphRootValueUpdater.render → SwiftUI`_UIHostingView.layoutSubviews()
frame #51:   FinanceTracker main
```
Swift Charts **traps on non-finite input** — a `SectorMark`/`BarMark`/`LineMark` value or a scale `domain` that is **NaN, ±infinity, or degenerate** (e.g. a percentage computed as `amount / total` when `total == 0`, or a ring fraction from empty/zero data). This is the SAME defect that spams `Invalid frame dimension (negative or non-finite)`. It fires during rapid QuickAdd because the chart re-renders on each save with transient empty/zero-total data.

**Fix (do this first — it kills the crash AND the frame spam):**
- Find every value/`domain`/`angle`/fraction handed to a Charts mark (the Dashboard "Spending by category" donut is the prime suspect; also any analytics chart, Safe-to-Spend/Pace ring).
- **Sanitize before it reaches Charts:** drop/skip data points whose value is not finite (`value.isFinite`), clamp to `>= 0`, and **guard the total: if `total <= 0`, do NOT compute `amount/total`** (no NaN) — render the empty/placeholder state instead of a chart.
- Ensure the chart is not built at all when there is no valid data (empty categories, zero total) — show the non-blank empty state, not a degenerate chart.
- Add a single choke-point sanitizer for chart input so no non-finite number can ever reach a mark.
**Test (targeted):** unit-test the chart-data builder: with total == 0 / empty categories / a NaN-producing input, it returns an empty/placeholder dataset (no NaN, no inf, no negative) — never a value that would reach Charts non-finite. Assert every emitted value `.isFinite && >= 0`.

## Item context — app also HANGS (main-thread Core Data); fix alongside
Device log (rapid QuickAdd of ~7 tx) also shows heavy **synchronous Core Data I/O on `com.apple.main-thread`** plus constant invalid view sizes — a real freeze on top of the crash. A hang = App Review 2.1 rejection + rating killer.

## Confirmed evidence (from device Console — do NOT re-derive)
Repeated Performance Diagnostics faults, all on `com.apple.main-thread`:
- `-[NSManagedObjectContext performBlockAndWait:]`
- `sqlite3_prepare_v3`, `sqlite3_step`
- `-[NSManagedObjectContext executeFetchRequest:error:]`
→ These are synchronous DB reads/fetches on the UI thread, firing on every save/keystroke while entering transactions. This is the freeze.
Also constant: `Invalid frame dimension (negative or non-finite).` and constraint warnings involving zero/negative widths near the QuickEntry input bar (`_dictationButton`, button-wrapper width == 0).

## Token discipline
Sonnet. Grep-first: `performBlockAndWait`, `executeFetchRequest`, `FetchDescriptor`, `context.fetch(`, `try? modelContext.fetch`, `ModelContext(` in non-actor paths. Read only the files that own the hot synchronous fetches + the QuickEntry input bar. Targeted tests only; no suite-wide runs.

## Item 1 — Move heavy Core Data reads OFF the main thread (the hang)
Investigate & report WHERE the synchronous main-thread fetches originate — likely an aggregation/summary path recomputed on every transaction change (dashboard totals, Safe-to-Spend, donut, "Pace", month scope) doing explicit `context.fetch(...)` / `performBlockAndWait` synchronously.
Fix approach (report what you choose):
- Route heavy aggregation reads through a background **`@ModelActor`** (off-main), returning plain value types (structs) to the view — do NOT pass `PersistentModel` across the actor boundary.
- OR, where a `@Query` is fine, stop the redundant **synchronous re-fetch on every change**: debounce/coalesce recomputation, and cache the derived summary so typing/saving doesn't trigger a full main-thread DB scan each keystroke.
- Ensure launch-time reads are deferred/off the first-frame path.
- Per project rule: never touch `ModelContext` from a background thread without a `ModelActor`.
**Test (targeted):** a logic test that the aggregation/summary computation runs off-main (or is cached/debounced) and returns correct totals; assert no synchronous fetch on the main path in the hot loop. Keep it minimal.

## Item 2 — Guard NaN / negative view sizes (`Invalid frame dimension`)
Find the view(s) producing non-finite/negative width/height. Prime suspects: the QuickEntry voice/input bar we recently refactored (ZStack + cross-fade, fixed height), the mic/dictation button, and any ring/donut/progress computing a width from a value that can be 0 or produce a divide-by-zero (Safe-to-Spend ring, Pace, category donut with empty data).
- Clamp all computed dimensions to `>= 0` and guard against NaN/inf (`value.isFinite ? value : 0`, `max(0, value)`); guard divide-by-zero in ring/progress math (empty totals → 0 progress, not NaN).
- If the `_dictationButton`/input-bar constraint (width == 0) is ours, give the control a valid intrinsic/min width so it isn't laid out at zero.
- No new strings expected.
**Verify on device** (voice/keyboard don't run under simctl): the `Invalid frame dimension` spam is gone and the input bar lays out cleanly.

## NOT in scope / notes
- The keyboard noise (`TUIKeyboardCandidateMultiplexer`, `variant selector cell`, `RTIInputSystemClient sessionID`, `Result accumulator timeout`, `_dictationButton not yet initialized`), the `_UIButtonBarButton`/`TUIKeyplane` width==0/-1.5 constraints, `RBSService Client not entitled`, `Sandbox restriction`, `personaAttributes` = benign iOS system-keyboard / dev-build noise. Ignore.
- Priority order: Item 0 (Charts NaN crash) FIRST — it's the actual EXC_BREAKPOINT and also removes the frame-dimension spam. Then Item 1 (off-main Core Data). Item 2 NaN-frame guard largely overlaps Item 0 (same non-finite source) — after Item 0, verify the spam is gone.

## Report
1. Item 0: the exact chart + the input path that produced the non-finite value (was it total==0 division? empty data? palette change?), the sanitizer you added, and the test. 2. Item 1: origin of main-thread fetches + off-main/caching approach. Files changed, build status, commit hashes, test output. Device-verify (Charts/keyboard don't repro headlessly). Target: v1.0 (hard blocker).
