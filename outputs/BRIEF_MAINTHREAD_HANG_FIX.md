# BRIEF (Claude Code) — main-thread hang: GO. Fix approved. Model: Sonnet. Branch `main`. Commit per item, push.

Step 0 accepted in full — the measurement is the answer. Keep `/tmp/hotpath-measure.txt` and the measuring test in the suite; it is the acceptance instrument for this brief.

## Fix in this order — the cheapest win is first, and it isn't the actor
### 1. Stop calling it. `ProactiveAlertRefresher` should not run on every save at all.
`FinanceTrackerApp.swift:131-135` fires `refresh()` on **every** `ModelContext.didSave` plus every foregrounding. But the alert it computes is **weekly** (`ProactiveAlertPolicy`). Recomputing a weekly signal on every keystroke-save is a **design error, not a performance detail** — an infinitely fast query called on every write is still wrong. Move it to a cadence that matches what it produces (a schedule / at most once per day / on foreground with a floor), not per-write. Report the cadence you choose and why.

### 2. Stop scanning the whole table. `ProactiveAlertRefresher.swift:61`
`modelContext.fetch(FetchDescriptor<Transaction>())` pulls the **entire unfiltered table**. It needs only the current month + the prior comparison span. Scope the `FetchDescriptor` with a predicate (and fetch only what it aggregates). This alone drops it from O(all history) to O(month).

### 3. Kill the double-fire. `MerchantLearningService.record`
It performs a second save after every transaction save, so each QuickAdd triggers the full pass **twice**. Coalesce: fold the learning write into the same save, or debounce it — one save per user action.

### 4. Then move the aggregation off-main.
Route heavy aggregation/summary reads through a background `@ModelActor` returning **plain value types** — never a `PersistentModel` across the actor boundary (project rule: no `ModelContext` off-thread without a `ModelActor`). Apply to the Dashboard/Transactions summary paths. The `@Query` full sorted fetch re-running on main after every save: debounce/coalesce and cache the derived summary.

Items 1–3 are small and probably remove most of the measured cost; do them first and **re-measure after each** so we know what actually bought what. Report the table again at 2k / 6k / 12k after each item.

## While you're in here — one hypothesis to test, NOT to assume
We spent ten rounds on the Charts `EXC_BREAKPOINT` (#22), concluded the degenerate frame was a **co-symptom** and that "the real trap is upstream" — and never found upstream. The refresher was in fact our **leading suspect at the time** and we dropped it for the frame theory. It is now measured as the primary main-thread blocker, on the same trigger (rapid QuickAdd), on the same device-only profile.
**I am not claiming the hang causes the crash** — a watchdog kill is `0x8badf00d`, not `brk #0x1`, and I have mis-asserted this crash three times already. But after these fixes land, **re-run the crash repro at scale and report whether it survives.** If it dies, #22 closes and we stop hunting a ghost. If it survives, we've lost nothing and ruled out a real suspect with evidence instead of a theory.

## Acceptance — device, at scale, not the unit suite
- Re-measure with the existing instrument at 2k / 6k / 12k → report the new table against the old one.
- Unit tests can pin what they can: the aggregation path performs no synchronous main-thread fetch in the hot loop; the refresher's cadence; the single-save-per-action invariant; totals still correct.
- ⚠️ **Real acceptance is the founder's device with the Console open:** the `com.apple.main-thread` Performance-Diagnostics faults are gone during a rapid QuickAdd burst and when opening the Transactions list. Their absence is the signal. Unit tests were structurally blind to this — 348 green and a 7/7 UI matrix both missed it. Don't let them close it.
- Also still owed from the last brief: **document how the founder builds and installs a Release configuration to his device** — we have been QA'ing Debug and submitting Release this whole time.

## Report
Per item: what changed, the re-measured numbers, why the cadence you chose. Then the #22 re-test result, plainly, either way.
