# BRIEF (Claude Code) — v1.0.2 device-QA blockers. Model: Sonnet. Branch `main`. BOTH block submission. Commit per item, build + test before commit, push.

Found on the real device during the 1.0.2 QA pass (founder, 2026-07-16).

## 1. [BLOCKER] Debug/temporary selectors are visible in Settings in the shipping build
While hunting the save bug we added temporary reset seams (account reset, tip-collection reset, possibly others). They are **still in Settings**, and the founder sees them on device — **in English, unlocalized**, in a build we're about to submit.

Why this is not cosmetic:
- These controls **destroy user data** (reset accounts / reset the tip collection). A real user can tap them.
- Unlocalized English strings in 5 localized locales.
- App Review sees debug affordances in a production build.

Do:
- **Find every debug/temporary/reset affordance reachable from the UI** — don't fix only the two we remember. Grep for the seams added since the 1.0.1 tag (`--reset-accounts`, `--reset-tip-collection`, and anything similar), plus any Settings row that exists only for testing.
- Each one: wrap in `#if DEBUG` (so the QA seam survives for us) or delete it if it has no ongoing value. **Nothing debug-only may be reachable in a Release build.**
- Add a test or a build-time check asserting no debug affordance is compiled into Release — the same discipline as `ChartBisection` (which you already made compile to constants in Release; mirror that).
- Report the **full list** of what you found, and what you did with each. If the list is longer than the two we remember, say so plainly.

## 2. [BLOCKER] The app FREEZES — "Edit opens nothing", then recovers on its own. This is the known main-thread Core Data hang we never fixed.
**Exact symptom (founder, updated):** tapping Edit in the Transactions list opened **nothing at all** — then, some minutes later, **it unfroze by itself and edit worked normally**. Delete worked throughout. So this is **not** a broken presentation binding and **not** a save-path defect: the main thread was **blocked**, taps went nowhere, and when the blocking work finished the UI came back.

**Two hypotheses I raised and am withdrawing — do not spend time on them:** (a) `88fe39e` / `SaveActionGate` / `AddTransactionSaveService` — that's the write path, wrong layer; (b) a broken sheet binding — a binding doesn't heal itself.

**This is already diagnosed, with device evidence, in `outputs/BRIEF_MAINTHREAD_HANG_NANFRAME.md` Item 1 — which we appear to have never executed.** That brief records confirmed Performance-Diagnostics faults from the founder's device, all on `com.apple.main-thread`:
```
-[NSManagedObjectContext performBlockAndWait:]
sqlite3_prepare_v3 / sqlite3_step
-[NSManagedObjectContext executeFetchRequest:error:]
```
firing on **every save and keystroke** during entry. Synchronous DB reads on the UI thread = the freeze. We chased Item 0 (the Charts crash) for ten rounds and Item 1 fell through the cracks. That same brief already calls it out: *"A hang = App Review 2.1 rejection + rating killer."*

### Step 0 — establish the truth before coding
- **Was Item 1 ever implemented?** Check git and the code: grep `performBlockAndWait`, `executeFetchRequest`, `FetchDescriptor`, `context.fetch(`, `try? modelContext.fetch(`, `ModelContext(` outside actors, and `@ModelActor`. Report plainly: done, partially done, or never done.
- **Find where the synchronous main-thread fetches originate.** The prior brief's suspicion: an aggregation/summary path recomputed on every change (dashboard totals, safe-to-spend, donut, pace, month scope). Confirm against the code.
- **Do not "fix" edit.** Edit is a *victim*, not the defect. If the main thread is free, edit works — the founder just proved that.

### The fix (per the original brief, still valid)
- Route heavy aggregation reads through a background `@ModelActor`, returning **plain value types** to the view — never pass a `PersistentModel` across the actor boundary.
- Where `@Query` suffices, stop the redundant synchronous re-fetch on every change: debounce/coalesce recomputation and cache the derived summary so a keystroke doesn't trigger a full main-thread DB scan.
- Defer launch-time reads off the first-frame path.
- Project rule: never touch `ModelContext` from a background thread without a `ModelActor`.

### Tests + verification
- A test asserting the aggregation/summary path does not perform a synchronous fetch on the main path in the hot loop (or is cached/debounced), and still returns correct totals.
- ⚠️ **Unit tests cannot see a hang** — 348 green tests missed this entirely. **Acceptance is on device:** hammer QuickAdd and the Transactions list with a large dataset and watch for Performance-Diagnostics faults on `com.apple.main-thread` in the Console. Their absence is the signal.
- **Ask for a seeded large dataset** if you need one to reproduce — the hang scales with row count, which is why it appears intermittently on a device that's been accumulating test data and never in a fresh simulator.

### Also worth checking, but only after Step 0 reports
The founder's older "can't add a new category while editing a transaction" complaint — same hang, or separate defect? Report either way. `CategoryPickerSheet` is the single shared picker for both entry surfaces — do not add a per-view picker (CLAUDE.md anti-pattern).

Then:
- Fix the edit path. An edit must **update the existing Transaction**, never insert a second one, and must not be blocked by an add-path gate. If edit needs its own gate, give it one — content-blind, guarding the action.
- **Tests, and these specifically:** edit an existing transaction → the same row updates, the row count is unchanged (assert no duplicate created); a failed edit-save leaves the original intact and the context clean; double-tap Save on edit → one update, not two.
- While you're in there: the founder previously reported that **adding a new category from inside the edit flow doesn't work**. Check whether that's the same defect or separate; report either way. `CategoryPickerSheet` is the single shared picker for both entry surfaces — do not add a per-view picker (CLAUDE.md anti-pattern).

## Report (≤6 lines per item): item 1 — the full list of debug affordances found + disposition + the Release guard. Item 2 — the real failure (not the hypothesis), regression-or-not with the commit that caused it, the fix, tests added. Build/test/commit per item.
