# Bulk delete: transactionality + cost curve

**Date:** 2026-08-04
**Method:** code read (transactionality) + `FinanceTrackerTests/BulkDeleteCostMeasurementTests.swift`
**Run:** `TEST SUCCEEDED`, 2 tests, 496 s, iPhone 17 Pro simulator, Debug, on-disk SQLite
**Status:** measurement only. **No fix is proposed here** — by instruction.

---

## 0. Answer first

| Question | Answer |
|---|---|
| Is `reset()` transactional? | **Yes.** One `save()` at the end. |
| Is `deleteAll()` transactional? | **Yes.** One `save()` at the end. |
| Can an interrupted run leave a partially deleted ledger? | **No.** |
| Does the curve cross "a few seconds"? | **Yes, well inside real data.** `deleteAll` ≈ 3 s at ~2 000 flagged rows, **49 s at 8 000**. `reset` ≈ 3 s at ~4 800 rows, **9 s at 8 000**. |
| Shape | **Superlinear, approaching quadratic** (k → 1.9–2.2), and it is **`save()`**, not the delete loop. |

The data-loss scenario that would have outranked the freeze **does not exist**. The freeze is the finding.

---

## 1. Transactionality (code read)

### `TransactionResetService.reset(in:)` — `Services/TransactionResetService.swift:38`

```
fetch all  →  for tx in all { context.delete(tx) }  →  try context.save()  →  fetchCount verify
                                                       catch → context.rollback()
```

One terminal `save()`. No save inside the loop. On a thrown save it **rolls back**, discarding the
pending deletes, and the count check then reports `.failure(remaining:)` so the user is told to retry.

### `DuplicateReviewService.deleteAll(in:)` — `Services/DuplicateReviewService.swift:65`

```
flagged() fetch  →  for tx in rows { modelContext.delete(tx) }  →  try modelContext.save()
```

Same shape. One terminal `save()`. No save inside the loop.

### Why an interruption cannot leave a partial ledger

1. `ModelContext.delete()` performs **no I/O**. Nothing reaches SQLite until `save()`.
2. `save()` is a single SQLite transaction — atomic at the store level.
3. Autosave cannot interleave: `autosaveEnabled` is never touched in production (the app-group
   `mainContext` keeps the default), but SwiftData's autosave fires on run-loop / lifecycle
   boundaries, and a synchronous main-thread loop yields to neither. The loop is precisely what
   starves the run loop that would have triggered it.

So: force-quit, low-memory kill, or watchdog **during** the freeze ⇒ zero rows deleted on disk.
Bad UX, no data lost. This is the "one save at the end" branch of your fork.

### One asymmetry found on the way — reported, not fixed

`reset()` rolls back on save failure and shows the user an alert.
`deleteAll()` does neither:

- it propagates the error;
- `DuplicateReviewView.perform` (`Views/DuplicateReviewView.swift:159`) swallows it into a `#if DEBUG`
  `print` and **dismisses the sheet**;
- nothing calls `rollback()`, so the failed `save()` leaves un-committable pending DELETEs in the
  long-lived `mainContext` — the exact poisoned-context state that `TransactionResetService`'s own
  comment documents as the origin of the "after Reset, every save fails" report.

Still not on-disk partial loss. But the user is told nothing and the sheet closes as if it worked.

---

## 2. Premise check (the one that made the UI vehicle unnecessary)

- `TransactionResetService` is `@MainActor` (file-level, `:18`). `reset()` is a plain synchronous
  `static func` — no `await`, no continuation, no dispatch inside the loop.
- Call site `GeneralSettingView.resetTransactions()` (`:461`) runs inline from the alert's destructive
  button (`:146`). No `Task` hop.
- `DuplicateReviewService.deleteAll` is likewise plain synchronous, called inline from
  `DuplicateReviewView.deleteAll()` (`:155`) off the alert button (`:65`). **Its work is ONE
  synchronous pass — nothing is interleaved with UI**, which is why it did not need the UI vehicle
  either.

For an operation of that shape there is nothing else the main thread can be doing while it runs, so
**wall-clock == main-thread-blocked**. The blocked-fraction question collapses to a stopwatch, and
`BulkDeleteStallMeasurementTests` (the UI vehicle) is now redundant for this question. Left in place;
not deleted as part of this task.

Corroboration from the in-app instrument, which agrees with the stopwatch and reports `main=yes`:

```
[HangProbe] PASS name=DuplicateReview.deleteAll ms=48791.27 main=yes rows=8000
```

---

## 3. The curve

Store is on-disk SQLite (never in-memory — in-memory never reaches `sqlite3_step`). Seeded through one
container, that container dropped, and a **new container + context opened over the same file**, so the
measurement runs against a **cold context** — the user's context has almost none of those rows
materialized when they tap the button.

### 3a. `DuplicateReviewService.deleteAll` — measured first (acquisition path)

Import shape: user already had *n* rows, the re-import added *n* more, all flagged. Table = 2*n*,
deleted = *n*.

| flagged rows deleted | total | µs/row | ×rows | ×time | k |
|---:|---:|---:|---:|---:|---:|
| 1 000 | **929 ms** | 929 | 1.0 | 1.0 | — |
| 2 000 | **2 866 ms** | 1 433 | 2.0 | 3.1 | 1.63 |
| 4 000 | **10 816 ms** | 2 704 | 4.0 | 11.6 | 1.77 |
| 8 000 | **49 185 ms** | 6 148 | 8.0 | 53.0 | 1.91 |

Phase attribution (same sizes, second identically seeded cold store; the fetch phase is the **real**
`flagged(in:)`):

| phase | 1 000 | 2 000 | 4 000 | 8 000 | shape |
|---|---:|---:|---:|---:|---|
| `flagged()` fetch | 37 ms | 68 ms | 131 ms | 280 ms | linear, ~35 µs/row |
| delete loop | 4.7 ms | 8.8 ms | 16.8 ms | 38 ms | linear, ~4.5 µs/row |
| **`save()`** | **831 ms** | **2 794 ms** | **10 614 ms** | **48 559 ms** | **k = 1.75 → 1.96** |

At 8 000: `save()` is **98.7 %** of the wall clock. The delete loop is **0.08 %**.

### 3b. `TransactionResetService.reset` — whole ledger

| ledger rows | total | µs/row | ×rows | ×time | k |
|---:|---:|---:|---:|---:|---:|
| 1 000 | **289 ms** | 289 | 1.0 | 1.0 | — |
| 2 000 | **656 ms** | 328 | 2.0 | 2.3 | 1.18 |
| 4 000 | **2 052 ms** | 513 | 4.0 | 7.1 | 1.41 |
| 8 000 | **9 028 ms** | 1 129 | 8.0 | 31.3 | 1.66 |

| phase | 1 000 | 2 000 | 4 000 | 8 000 | shape |
|---|---:|---:|---:|---:|---|
| full fetch | 31 ms | 60 ms | 121 ms | 247 ms | linear, ~30 µs/row |
| delete loop | 4.1 ms | 8.0 ms | 16.3 ms | 34 ms | linear, ~4.1 µs/row |
| **`save()`** | **193 ms** | **563 ms** | **1 910 ms** | **6 877 ms** | **k = 1.54 → 1.72** |

The phases sum to 7 158 ms against a 9 028 ms end-to-end at 8 000. The ~1.9 s gap is the
post-delete `fetchCount` verification, which `reset()` performs and the phase replica does not —
i.e. the verification is itself a second-scale cost at 8 000 rows.

### 3c. Where it crosses (power-law fit on the top two points)

| | 1 s | 3 s | 10 s |
|---|---:|---:|---:|
| `deleteAll` (flagged rows) | ~1 050 | ~2 050 | ~3 850 |
| `reset` (ledger rows) | ~2 600 | ~4 800 | ~8 400 |

### 3d. Observation the numbers force, with its confound named

At the **same deletion count of 8 000**, `deleteAll`'s `save()` costs 48 559 ms while `reset`'s costs
6 877 ms — **7×**. The difference between the two runs is what is left behind: `deleteAll` leaves
8 000 surviving rows, `reset` empties the table.

**Confound:** `deleteAll`'s table was 16 000 rows to `reset`'s 8 000, so table size and survivor count
move together and this run cannot separate them. What it does establish is that the cost is **not a
function of rows removed alone** — the state of the rest of the table matters, and matters a lot. Any
fix discussion should treat that as an open variable rather than assume per-deleted-row cost.

---

## 4. Caveat, stated plainly

This is a scratch on-disk store in the test host's temp directory, not the real app-group store on a
device: different filesystem, different I/O scheduler, no second process holding the store open, and a
Mac CPU rather than an A-series under thermal load. **Absolute numbers will differ on device** —
plausibly worse. The **shape** — superlinear approaching quadratic, concentrated in `save()`, linear
and negligible in the delete loop — is what decides severity, and shape survives the difference.

Debug build. `hangProbe` wraps the loop once per call (not per row), so its cost is not in these
numbers.

Not measured, out of scope for this pass: rows carrying `TransactionSplit` children (`.cascade`), which
would add per-row cascade work the seeded rows do not have.

---

## 5. What this means for priority (no fix proposed)

`deleteAll` is the worse of the two on every axis, as you predicted:

- it is **5× more expensive** than `reset` at the same row count (49 s vs 9 s at 8 000);
- it crosses 3 s at ~2 000 rows — a Mint refugee re-importing a couple of years of history;
- it is hit by a **new user on their first real action**, with no destructive-action framing to set
  expectations, and the sheet **dismisses on the way in** so there is no surface telling them anything
  is happening;
- and if its `save()` fails, it says nothing and leaves the context poisoned (§1).

`reset` is rare, user-initiated, explicitly destructive, and preceded by a confirmation alert. 9 s at
8 000 rows is bad; it is not the same exposure.

---

## 6. Reproducing

```bash
xcodebuild test -scheme FinanceTracker \
  -destination 'platform=iOS Simulator,id=<device-id>' \
  -only-testing:FinanceTrackerTests/BulkDeleteCostMeasurementTests \
  -parallel-testing-enabled NO
```

~8 minutes. Prints both curves with a growth exponent `k` per point, so linear (k≈1) vs quadratic
(k≈2) is readable off the output rather than eyeballed. Sizes are `BulkDeleteCostMeasurementTests.sizes`.
