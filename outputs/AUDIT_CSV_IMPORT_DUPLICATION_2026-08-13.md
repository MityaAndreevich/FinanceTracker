# The CSV import orchestration exists twice — what differs, and which way to collapse

**Date:** 2026-08-13 · **Mode:** read-only when written. Report first, per the brief.

> **STATUS UPDATE — the disclosure half is BUILT (1.0.5).** §A5's fix (1) shipped: `PartialImportFailure`
> carries the committed snapshot out with the error, and the alert now states how many rows landed and
> that re-importing is safe. Batch size stayed at 100 and foreign dedup still FLAGS rather than skips,
> both deliberately. `.importAll` is pinned unreachable by `ImportModeReachabilityGuardTests`.
> **Still open:** the collapse onto the actor — deferred to the first item after 1.0.5 ships, with its
> reason recorded in `PROPOSAL_1_0_5_SCOPE.md`.

---

## 0. Answer to the question asked

> *"A duplicate that has silently diverged is a different problem from a duplicate that is merely
> redundant — establish which it is before choosing."*

**Neither, exactly — and the third case is the one that matters.**

The two orchestrations have **not** silently diverged. Line for line they are the same algorithm,
and the per-row logic is genuinely shared (`processMappedRow`), not copied. Every mapping, dedup,
convention-resolution and row-failure path the tests exercise **is** the code that ships.

But they are not merely redundant either, because they differ by exactly one thing **on purpose** —
and that one intentional difference **inverts the failure semantics of the whole import**:

| | `importMappedCSV` (tested) | `importMappedData` (**ships**) |
|---|---|---|
| `save()` | **once, at the end** | **every 100 rows**, plus a final one |
| On a failing save | **atomic — nothing is committed** | **partial — everything before the failing batch is already committed** |

**The duplicate is faithful in the part the tests cover, and the single place it is unfaithful is the
single place no test can reach.** That is worse than ordinary drift, because reading the two files
side by side makes them look safely identical.

---

## 1. The complete diff

`CSVImportService.importMappedCSV:210` vs `CSVImportActor.importMappedData:72`. Identical:

- `prepare(...)` → same preamble
- empty-rows guard
- `categoryCache` / `sourceCache` / `seenUUIDs` / `seenHeuristics` seeding
- `defaultCurrency` from `UserDefaults`
- `start = hasHeader ? 1 : 0`
- `resolveAutoConventions(...)` — same call, same arguments
- `total = max(0, rows.count - start)`
- the `while` loop, calling the **same** `processMappedRow` with the **same** arguments
- `progress(processed, total)`
- final `try modelContext.save()`

**The only differences, both inside the loop:**

```swift
if processed % Self.batchSize == 0 {   // batchSize = 100
    try modelContext.save()            // ← intermediate commit
    await Task.yield()                 // ← cooperative yield
}
```

**This is not a mapped-import quirk. The same pair exists for the generic path:**
`importCSV:82` vs `importData:28` differ by the identical batch-save + yield block. **Two
orchestration pairs, and in both cases the tests sit on the half that does not ship.**

---

## 2. What the untested difference actually costs a user

`processMappedRow` is documented never to throw — per-row failures are recorded and the loop
continues. So the realistic throw site inside the loop is `modelContext.save()` itself.

**On the tested path** a mid-import save failure commits nothing. The user sees an error and an
unchanged ledger. Clean, retryable.

**On the shipped path** a save failure at row 4,500 of 8,000 leaves ~4,400 rows **already committed**,
then throws. The user sees an error and a **half-imported ledger**.

The retry is where it compounds. Foreign CSV rows carry no stable UUID, so the importer's contract
(`:203–205`) is that a content match is **flagged as a possible duplicate, never dropped**. So
re-importing the same file after a partial failure does not skip the 4,400 rows already in — it
imports them again and flags them. **The user's recovery action turns a half-import into a
double-import with thousands of rows in the duplicate-review queue.**

Every step of that is reachable only on the path with no tests, and it lands on **large-history
import — the stated acquisition wedge.** The larger the file, the more batches, the more likely the
failure, and the worse the partial state.

**Stated fairly:** this is a latent hazard, not an observed bug. It needs a `save()` to fail
mid-import — disk pressure, a validation error, a migration-era constraint. The point is not that it
is happening; it is that **the suite cannot tell us either way**, and reports green.

**Second-order, worth one line each:**
- **Cancellation is not real.** `Task.yield()` lets cancellation *interleave*, but neither loop checks
  `Task.isCancelled`, so a cancelled import runs to completion. Untestable on the current path.
- **`preamble.startIndex` is ignored by both mapped orchestrations.** `prepare` sets `startIndex = 1`
  only when the first row matches our own export header (`date,type,amount`), so for every foreign
  file it stays `0` while the mapped paths use `hasHeader ? 1 : 0`. The two agree with each other, so
  this is not a divergence — but it does mean `totalDataRows`, and therefore the **`MAX_ROWS = 10k`
  cap**, counts the header row on foreign imports. Off-by-one on the cap, not on the data.

---

## 3. Coverage, stated precisely

**`CSVImportActor` has zero direct test references.** Not thin coverage — none. Both shipped import
entry points (`importData`, `importMappedData`) are untested as orchestrations.

The 13 `importMappedCSV` references live in `CSVMappedImportTests.swift` and
`ImportDuplicateFlagTests.swift`. What they genuinely cover — column mapping, date/decimal convention
resolution, row-failure classification, duplicate flagging — is real coverage of shared code and
**should not be described as worthless.** What they do not cover is the loop that wraps it.

---

## 4. Recommendation: collapse onto the actor. Do not test both.

**Collapse, and specifically: delete `importMappedCSV` and `importCSV`, retarget their tests at
`CSVImportActor`.**

**Why collapse rather than test the live one:**

1. **The sync version's stated reason has expired.** Its doc says *"tests + any off-main caller"*
   (`:202`). There is no off-main caller and never was — production goes through the actor, and the
   only caller of `importCSV` is a DEBUG QA seam. It is kept alive purely by its own tests.
2. **Two copies cannot be kept honest by review.** They are faithful *today* precisely because
   someone maintained them in parallel; that is a standing tax with no upside, and the one place the
   discipline already broke is the batching.
3. **Testing both is the worst option.** It doubles the tests to keep a duplicate that exists for no
   production reason, and still leaves two things to keep in sync.

**Why the actor is the survivor, not the service function:** it is what ships, it is what a user's
build executes, and its batching is the behaviour that most needs assertions. Collapsing the other
way would delete the shipped implementation to keep the test double.

**The honest cost, so this is not sold as a rename.** All 13 tests become `async` and must construct
the actor off-main — `CSVImportActor.swift:10–15` documents the thread-affinity trap: a `@ModelActor`
adopts the executor of whatever constructs it, so a test that builds it on the main actor silently
tests the main-thread path and proves nothing. **That trap is exactly the sort of thing that makes a
green suite meaningless, so the migration itself needs the negative-control treatment: construct one
deliberately on the main actor first and confirm the new test can tell the difference.**

**Sequencing.** This is not a 1.0.5 blocker and does not touch the schema. But it should land
**before** any further import work — the flexible-import Tier 3 (PDF/OCR statement import) is
sketched against the same service, and building a third caller on the untested-orchestration side
would set this in concrete.

**What to assert once collapsed, in priority order:**
1. A save failure mid-import — what is committed, what the user is told, and what a retry does.
2. Batch-boundary correctness at exactly 100, 101 and 99 rows.
3. `Task.isCancelled` behaviour, once the loop actually honours it.

---

# ADDENDUM — the retry path, established before choosing a fix (2026-08-13)

The severity in §2 was asserted without the fact that decides it. Answering it changes the verdict in
**both** directions: the data outcome is better than I implied, and the honesty outcome is worse.

## A1. Which mode does the retry use? — `.skipDuplicates`, always, and it is the only one reachable

`DataSettingsView` never passes `mode`. Both `startAsyncImport:282` and `startMappedImport:316` take
the default, so **every import a user can perform runs `.skipDuplicates`.**

**`.importAll` is unreachable from the shipping app.** Nothing in the app, widget or shared target
ever *sets* it — only the enum case (`:17`) and the branch that reads it (`:688`) exist. There is no
UI to choose "keep both". Three test files exercise it. **This is another instance of the reachability
class, found inside this investigation:** a mode parameter with one reachable value, whose second
value has tests.

So the `.importAll` half of the question is moot for shipped behaviour — **but not in the reassuring
direction**, as A2 shows.

## A2. What `.skipDuplicates` actually does on the mapped path — it does NOT skip

**This is the correction that matters, and it applies to both branches of the framing.** Both assume
the row carries a UUID. On the mapped path no row does.

**Generic path (our own export, has an `id` column)** — the framing is exactly right:

```swift
if mode == .skipDuplicates, seenUUIDs.contains(id) {   // :684
    result.duplicatesSkipped += 1; return              // a real skip
}
```

`seenUUIDs` is seeded from disk, so a retry genuinely skips what landed. Unpleasant, not dangerous.

**Mapped path (Mint / YNAB / Monarch — foreign CSV, no `id` column)** — there is no UUID to match:

```swift
let isPossibleDuplicate = (mode == .skipDuplicates) && seenHeuristics.contains(heuristic)  // :329
let uuid = UUID()          // :334  fresh, EVERY row, BOTH modes
modelContext.insert(tx)    // :348  ALWAYS inserts
```

**On the mapped path the row is always inserted, in both modes.** `.skipDuplicates` does not decide
*whether* the row lands — only whether it is **flagged**. So:

> **A retry after a partial mapped import double-imports in both modes.** The mode only decides
> whether the duplicates are flagged or silent.

The "unpleasant, not dangerous" branch does not exist here — **and this is the acquisition path**, the
Mint-migration wedge. This is not an oversight in the code; `:318–320` states the contract
deliberately: *"flag on content match, never drop"*, because identical content is not proof of an
accidental duplicate. That reasoning is correct and is the same principle that governs the QuickAdd
save path. **It just means UUID-based retry safety is structurally unavailable to foreign rows.**

## A3. Does the user know the import was partial? — No, and they are told the opposite

**This is the real defect.** On a throw, `startMappedImport:323–332`:

- **discards `result` entirely** — the `imported` count of rows that *did* land dies with the error;
- shows `"data.import.failed.format"` = **`"Import failed: %@"`**;
- offers **one button, `common.ok`** — no undo, no retry, no "review what landed".

**The app says the import *failed* when it partially *succeeded*.** A user who imported 8,000 rows and
saw 4,400 land is told nothing happened. Their reasonable next action — re-pick the file and try
again — is the exact action that doubles the 4,400.

This is the silent-success class inverted: not reporting success while doing nothing, but **reporting
failure while having done half.** Same root, same cost — the app's account of itself is false.

## A4. Revised severity — and where I overstated

**Correcting my own §2:** I wrote that a retry *"turns a half-import into a double-import with
thousands of rows in the duplicate-review queue"* and framed the queue as the damage. It is the
**mitigation, working as designed.** Because the retry is forced into `.skipDuplicates` and
`existingHeuristics` is seeded from disk, every re-imported row matching a landed row is flagged
`isPossibleDuplicate`, **persisted on the row**, badged, and surfaced in the review sheet built for
exactly this in 1.0.2. Nothing is lost, corrupted, or silently wrong.

| Axis | Verdict |
|---|---|
| **Data safety** | **MEDIUM**, not HIGH. Duplicates are flagged, reviewable and reversible. The 1.0.2 review queue is the designed catch and it catches this. |
| **Honesty / trust** | **HIGH.** "Import failed" after a partial commit is a false statement to the user, on the acquisition path, at the moment of highest abandonment risk. |
| **Silent-duplicate risk** | **LOW** — *conditional on the retry staying in `.skipDuplicates`.* If a "keep both" toggle is ever exposed, the flagging disappears and this becomes genuinely dangerous. **`.importAll` must not reach the UI without solving partial-state disclosure first.** |

So: **"bad", not "thousands of duplicate rows on a new user's first day"** — the rows are there, but
they arrive labelled, in a queue designed to resolve them.

## A5. What to fix — the retry, not the transaction size

**Batch size stays at 100.** Batching bounds peak memory, gives a real progress boundary and avoids
one enormous transaction on a 10k-row file. It is the right call for large imports and reverting to a
single save would trade a disclosure bug for a memory-and-watchdog bug on precisely the files that
matter most.

**Fix, in priority order:**

1. **Tell the truth about partial state.** The actor must carry the partial `CSVImportResult` out with
   the error rather than discarding it — a typed error holding the result, or returning
   `(result, error?)`. Then the alert can say what actually happened: *N rows imported before the
   error*, and what to do next. **Smallest change, removes the false statement, and makes the retry
   informed rather than blind.** This is the fix.
2. **Then make the retry's consequence visible** — if a partial import is followed by a re-import,
   the result summary should surface the flagged count and offer the review queue directly, instead
   of leaving the user to find a badge later.
3. **Do NOT make foreign-row dedup skip instead of flag.** It would make the retry idempotent and it
   is the wrong trade: it silently drops rows a user may genuinely have twice, which is the mistake
   already made and reverted on the QuickAdd save path. The flag is correct.

**Sequencing note:** (1) is independent of the collapse and worth landing on its own — it is a
user-facing honesty fix on the acquisition path, and it does not require the 13 tests to move first.
The collapse onto the actor remains the destination, with the migration itself commissioned against a
negative control (build the `@ModelActor` on the MainActor deliberately and confirm the new tests can
tell the difference), the way exit-1 and exit-3 were commissioned as a pair.
