# The CSV import orchestration exists twice — what differs, and which way to collapse

**Date:** 2026-08-13 · **Mode:** read-only. **Nothing fixed.** Report first, per the brief.

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
