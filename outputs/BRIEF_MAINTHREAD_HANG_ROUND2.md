# BRIEF (Claude Code) — the main-thread hang. Round 2. Model: Sonnet + systematic-debugging. Branch `main`. **Report before fixing.**

## Read this first — the record, corrected
- **The build was NOT stale.** The founder confirms he installs to the device **from current `main` via Xcode**. Your "QA-round-2 stale-build profile" conclusion is dead. (What he *is* running is a **Debug** configuration — Xcode's Run defaults to it — which is why he saw the `#if DEBUG` chart-bisection panel. Correct on that point; wrong on staleness.)
- **The symptom is a FREEZE, not a presentation bug.** Tapping Edit did nothing for minutes, then **the app unfroze by itself** and edit worked normally. Delete worked throughout. A binding does not self-heal. A stale build does not freeze and then recover.
- **Your 7/7 UI matrix passing is expected and proves nothing here.** Edit presents fine whenever the main thread is free — the founder watched exactly that happen. You tested the state in which the bug cannot occur, on simulators with a near-empty store. **Edit is the victim, not the defect. Do not touch the edit path again.**
- Credit where due: falsifying your own `.languageReactive()` fix from the xcresult hierarchy was the right call. Apply that same scepticism one floor down.

## The defect is already diagnosed with device evidence — locate it, don't re-derive it
`outputs/BRIEF_MAINTHREAD_HANG_NANFRAME.md` **Item 1**, which we appear to have never executed (it was lost while Item 0, the Charts crash, ate ten rounds). Confirmed Performance-Diagnostics faults from the founder's device, all on `com.apple.main-thread`, firing **on every save and every keystroke** during entry:
```
-[NSManagedObjectContext performBlockAndWait:]
sqlite3_prepare_v3 / sqlite3_step
-[NSManagedObjectContext executeFetchRequest:error:]
```
Synchronous DB reads on the UI thread. That brief's own verdict: *"A hang = App Review 2.1 rejection + rating killer."*

## Step 0 — answer these three, in order, and report BEFORE writing any fix
1. **Was Item 1 ever implemented?** Grep `performBlockAndWait`, `executeFetchRequest`, `FetchDescriptor`, `context.fetch(`, `try? modelContext.fetch(`, `ModelContext(` outside actors, `@ModelActor`. Check git since the `1.0.1` tag. Answer plainly: **done / partial / never**. If never — say so; that's the likeliest answer and it's not a criticism, it's the starting point.
2. **Where do the synchronous main-thread reads originate?** Prior suspicion to confirm or refute against the code: an aggregation/summary path recomputed on every change — dashboard totals, safe-to-spend, the donut, pace, month scope. Name the actual call sites, file:line.
3. **Reproduce it with scale.** The hang scales with **row count** — that's why a fresh simulator can't see it and a device with weeks of accumulated data can. Seed a large realistic store (thousands of transactions across many months; add a `--seed-large-dataset` DEBUG launch-arg if we lack one — you already inventoried 12 such seams, follow that pattern) and **measure the main thread** while: (a) rapid QuickAdd, (b) opening the Transactions list, (c) tapping Edit. Use Instruments (Time Profiler / Core Data) or main-thread fetch timing. **Report the measurement — milliseconds blocked, and which fetch — not an opinion.** If you cannot make it hang at scale, that is a real and reportable finding: say so with the numbers you got, and we'll go back to the device.

## The fix (from the original brief — still valid, but only after Step 0 reports)
- Route heavy aggregation reads through a background **`@ModelActor`**, returning **plain value types** to views — never pass a `PersistentModel` across the actor boundary.
- Where `@Query` suffices, kill the redundant synchronous re-fetch on every change: **debounce/coalesce** recomputation and **cache** the derived summary so a keystroke doesn't trigger a full main-thread DB scan.
- Defer launch-time reads off the first-frame path.
- Project rule: never touch `ModelContext` from a background thread without a `ModelActor`.

## Acceptance — this cannot be closed by unit tests
⚠️ **348 green tests missed this entirely; a unit test cannot see a hang.** So:
- Add what a test *can* pin: the aggregation/summary path performs no synchronous fetch on the main path in the hot loop (or is cached/debounced), and still returns correct totals.
- **Real acceptance is on device, at scale, with the Console open:** the `com.apple.main-thread` Performance-Diagnostics faults are gone under rapid QuickAdd and while opening the Transactions list. Their absence is the signal.

## Second item — tell us what Release actually does
We have been QA'ing **Debug** builds this whole time and submitting **Release**. Different binaries, different active checks.
- Confirm which configuration Xcode's Run uses for this scheme, and document how the founder builds/installs a **Release** configuration to his device for final QA (exact steps, so this stops being a guess).
- Then say whether any of our open device-only symptoms could be **Debug-only artefacts** — specifically the unresolved Charts `EXC_BREAKPOINT` / `brk #0x1` (#22), which is a Swift trap, and Debug enables traps Release does not. **Do not assert either way without evidence** — I am not claiming it is Debug-only; I am saying we never checked, and after ten rounds on that crash we owe ourselves the check.

## Report
Step 0's three answers (with file:line and the measurement in ms) **before any code**. Then, if a fix follows: what you changed, why, the device acceptance result, files, build/test, commits.
