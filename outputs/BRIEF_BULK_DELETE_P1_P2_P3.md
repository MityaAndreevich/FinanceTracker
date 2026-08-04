# Bulk delete: swallowed save failure (P1), why save() is quadratic (P2), ModelActor costing (P3)

**Date:** 2026-08-05
**Follows:** `outputs/MEASUREMENT_BULK_DELETE_CURVE.md` (commit `4563c2c`)
**Commits:** fix `ea2fb23` · measurement `<this commit>`
**Suite:** 617 tests, `** TEST SUCCEEDED **`

---

## PRIORITY 1 — the swallowed save error

### 1a. How is it reachable?

Asked empirically, not argued: `FinanceTrackerTests/SaveFailureReachabilityProbe.swift` tries every
plausible mechanism against the **real two-configuration container** and reports which actually throw.

| Mechanism | Result |
|---|---|
| `.unique` violation, one save | **did NOT throw** |
| `.unique` violation, second save | **did NOT throw** — 1 row survives, i.e. SwiftData *upserts* |
| Read-only store, delete + save | **THREW** — `NSCocoaErrorDomain 513` |
| Delete a row a second context already deleted | **did NOT throw** — merges silently |
| chmod 0555 on the store directory | **did NOT throw** — SQLite holds writable fds; POSIX is checked at `open(2)` |
| Immutable flag on store + wal + shm | **did NOT throw** |
| Store file removed underneath | **THREW** — `NSCocoaErrorDomain 134030` |

**First correction: the cause the brief guessed at is gone.** `.deny` no longer exists anywhere —
every rule in `Models/` and `Data/FinanceTrackerSchemaV1.swift` is `.nullify` or `.cascade`. The
historical NSError 1600 cannot recur.

**So the reachable classes are "the store cannot be written":** read-only store (513) and store
loss/corruption (134030). Disk pressure is the realistic field cause of that class, and I could not
induce it — neither transient analogue throws in the simulator, so **disk-full remains an inference,
not a demonstration.** Stated plainly because it is the load-bearing assumption: the failure is real
but I cannot put a rate on it.

**Not honest to leave out — one path makes it likelier than "rare I/O event":** the app now runs two
`@ModelActor`s (`CSVImportActor` writes, `LedgerAggregator` reads) against the same store the main
context reviews. The duplicate-review queue exists *because* an import just ran. Cross-context
deletes merged silently in the probe, which is evidence against conflict-throws — but it is a second
writer on the same file, and that is the shape that produces store-level save errors in the field.

### Second correction — to my own report, and it changes the severity you assigned

I told you the poisoned context makes "every subsequent save fail" and everything the user does
afterwards is lost. **That claim does not survive testing and I should not have passed it on.** It
comes from `TransactionResetService`'s comment, written when Category carried `.deny`. With that rule
gone, no surviving mechanism produces a permanently-poisoned context: `.unique` upserts,
cross-context deletes merge, and the throwing mechanisms are permanent store failures rather than
poisoning. I could not construct one.

**What IS demonstrated is different, and quieter** (`SaveFailureReachabilityProbe`, all assertions
passing against a real 513):

1. **The context is left dirty.** `hasChanges == true`, deletes pending and unapplied.
2. **The app then misreports the ledger.** `flaggedCount` sets `includePendingChanges = true`, so it
   counts the pending deletes as done: **the app reports 0 rows to review while the store holds all
   50.** The sheet dismissed itself on the way in. Nobody is told anything.
3. **The pending deletes are not inert.** The next ordinary save — the user entering a transaction,
   minutes or days later — **flushes them.** Measured on a healthy store: 50 flagged rows on disk
   before an unrelated save, **0 after**.

So the failure is not "everything afterwards is lost". It is: *the destructive operation the user
was told nothing about silently commits itself later, detached from the action that caused it.*
Less catastrophic than I implied; still an irreversible operation firing at a moment the user never
authorized, on the import path, on day one.

### 1b. Audit — every other `save()` with the same shape

40 real `ModelContext.save()` sites. **Reported before fixing, as instructed: nothing in this section
is changed by commit `ea2fb23` except the duplicate-review service itself.**

#### Correct — the reference shapes

| Site | What it does |
|---|---|
| `TransactionResetService.swift:44` | log + `rollback()`; outcome decided by post-delete count; user alert. **The reference.** |
| `TransactionEditService.swift:77` | restore field snapshot + `rollback()` + rethrow |
| `AddTransactionSaveService.swift:46` | targeted undo (`delete(tx)`) + rethrow |
| `QuickAddSaveService.swift:95` | targeted undo + rethrow + `persistenceLog` |
| `MerchantLearningService.swift:39` | `rollback()` + log; runs strictly after the primary save |
| `DemoSeeder.swift:145` | deletes what it inserted + rethrow |
| `AddCategorySheet.swift:278` | targeted undo + **user-visible** error |
| `DuplicateReviewService` ×4 | fixed in `ea2fb23` |

#### Defective — swallowed, no rollback, UI proceeds as if it worked

Ranked by exposure.

| # | Site | Why it matters |
|---|---|---|
| 1 | `RecurrenceService.swift:200` (post a recurrence) | **Worst.** `setHandledDate()` runs *before* the `try?` save and lives in UserDefaults, so it is outside anything `rollback()` could undo. A failed save marks the period handled with no transaction created: the recurring charge is silently never logged **and never re-prompted.** |
| 2 | `RecurrenceService.swift:220` (`stopRecurrence`) | `clearHandled` + `cancelNotification` already happened. Series looks stopped, isn't. |
| 3 | `DashboardView.swift:616` (shake-to-undo) | `try?` then success haptic + "undo confirmed" toast. The toast lies; the pending delete rides along on a later save. |
| 4 | `TransactionsView.swift:198` (swipe-delete) | DEBUG print only. Row leaves the list (pending), stays on disk, deletes itself at some arbitrary later save. |
| 5 | `CategoriesSourcesView.swift:312, 346 → 398` | Bulk delete of categories/sources; DEBUG print only. Destructive. |
| 6 | `CategoriesSourcesView.swift:488, 505` | Set/clear a category limit: `try?` + dismiss (505 also marks the feature used). |
| 7 | `CategoriesSourcesView.swift:587` | Add source: `try?` + `onAdded` + dismiss. |
| 8 | `AddTransactionView.swift:731` | Create source: does *not* dismiss on failure — the only implicit signal in this group — but no message and no rollback; the pending insert stays. |
| 9 | `DemoDataController.swift:39, 117` | `try?`; `isDemoDataActive` is set regardless, so Settings shows the wrong state. |
| 10 | `DemoSeeder.swift:161` | `clearDemoData`, `try?`. |
| 11 | `SeedService.swift:89, 118, 211` | First-run category seed + legacy nameKey migration; DEBUG print / `try?`. |
| 12 | `StoreMigration.swift:203` | Logs properly and correctly keeps the handoff file on failure; no rollback. |

**Pattern:** #1, #2, #3 and #9 share the trait that made the duplicate-review bug bad — a side effect
*outside* the store (UserDefaults flag, cancelled notification, success toast) is committed before or
regardless of the save, so even a rollback would not make them consistent. Those need the side effect
moved after a confirmed save, not just a `rollback()`.

#### Errors surfaced (no rollback, but the user is told)

`CSVImportService.swift:114, 255` and `CSVImportActor.swift:61, 66, 113, 119` propagate to the
`data.import.failed.format` alert. Footnote: the actor saves every 100 rows, so a mid-import failure
leaves a **partial import** — additive and reported, but not transactional.

#### DEBUG-only seams (not shipped paths)

`DuplicateReviewDebugSeed.swift:39`, `AccountResetDebugSeam.swift:57`,
`LargeDatasetDebugSeed.swift:96, 160, 162`.

### 1c. The fix — commit `ea2fb23`, both parts

- **`rollback()` on failure.** All four `DuplicateReviewService` mutators (`keep`, `delete`,
  `keepAll`, `deleteAll`) now route through one `saveOrRollback` helper: rollback, log, **rethrow**.
  All four had the identical defect, so all four are fixed — a small deliberate widening beyond
  `deleteAll`, called out rather than hidden.
- **A user-visible failure.** `DuplicateReviewView.perform` returns success, raises an alert
  (`duplicates.review.action_failed.message`, added in all 5 locales; baseline 759 → 760), and the
  bulk actions **dismiss only on success**. Dismissing regardless is what made the failure invisible.

Regression tests, all against a *real* 513 rather than a simulated throw: the error reaches the
caller, the context is left clean, nothing is destroyed; plus the healthy-store pair showing pending
deletes ride along on the next save and that `rollback()` prevents exactly that.

---

## PRIORITY 2 — why `save()` is quadratic

**Your hypothesis is confirmed on every discriminator.** `BulkDeleteQuadraticMechanismTests`, same
fidelity rules (on-disk, cold context, phases timed separately).

| Case | table / deleted / categories | `save()` | µs per deleted row |
|---|---|---:|---:|
| A | 8 000 / 8 000 / 7 — no survivors | 7 356 ms | 920 |
| B | 16 000 / 8 000 / 7 — 8 000 survivors | **44 664 ms** | 5 583 |
| C | 16 000 / 16 000 / 7 — no survivors | 29 512 ms | 1 845 |
| D | 16 000 / 8 000 / **400 cats** | **1 212 ms** | 152 |
| E | 16 000 / 8 000 / **no category** | **720 ms** | 90 |

**The confound is broken:**

- **B/A = 6.07×** — same 8 000 deletions, 8 000 extra survivors. Survivors cost 6×.
- **B/C = 1.51×** — B deletes **half** as many rows as C and still takes 1.5× longer. Deletion volume
  is not the driver; **what survives is.**
- **C/A = 4.01×** — doubling the table doubles the collections *and* the deletions: 2 × 2.

**The mechanism, with deletions, table and survivors all held fixed at B's values:**

- **B/D = 36.8×** — only the number of categories changed (7 → 400, i.e. collection size ~2 286 → 40,
  a 57× reduction for a 37× speedup). **Cost scales with the size of the inverse collection.**
- **B/E = 62.0×** — only the relationship removed. 44 664 ms → **720 ms**. **The inverse-relationship
  maintenance is essentially the entire cost.**

Deleting a row removes it from its Category's to-many `transactions` array by identity, at
O(collection size) per row — so O(n²/categories) overall. In `reset()` the collections collapse as the
loop proceeds; in `deleteAll()` they stay large throughout. Exactly as you predicted.

**Relevance to real users:** the app ships a **13-category** taxonomy, far closer to case B (7) than
to D (400). Users cannot escape this by having tidy categories — the taxonomy is ours.

Not varied, so not claimed: `Source` (nil in all seeds) and `TransactionSplit` children (none). Both
are additional relationships on the same row and would plausibly add to the same cost.

**No fix proposed here, as instructed.** One measured fact belongs in that discussion though: case E
is the floor at **720 ms for 8 000 deletions**, so the mechanism has ~40–60× of headroom.

---

## PRIORITY 3 — costing the move off the main actor (not built)

### Your premise needs one correction, and it makes this cheaper

ARCHITECTURE.md's rule stands, but **this project has already built two `@ModelActor`s**:

- `LedgerAggregator` (`Services/LedgerAggregator.swift:76`) — reads, shipped in the hang fix.
- **`CSVImportActor`** (`Services/CSVImportActor.swift:21`) — **writes**: insert loop + batched saves,
  up to 10 000 rows, explicitly built to keep imports off the main thread.

`CSVImportActor` is the same operation shape (bulk mutation of the ledger) on the **adjacent screen**,
and `DataSettingsView.startAsyncImport` is already the exact UI pattern needed: `Task.detached`,
capture only the Sendable `ModelContainer`, spinner overlay, hop back to `MainActor` for the result
alert. This is not a new capability — it is a third instance of a pattern with two precedents.

### What it takes

| Piece | Work |
|---|---|
| One `@ModelActor` with `deleteFlaggedDuplicates()` and `resetAllTransactions()` | ~60 lines; `DuplicateReviewService` is **not** `@MainActor`, so it can be called from the actor unchanged |
| `DuplicateReviewView.deleteAll` → detached task + progress overlay + result alert | small; the alert now exists (`ea2fb23`) |
| `GeneralSettingView.resetTransactions` → same | small |
| Drop `@MainActor` from `TransactionResetService` (or duplicate its logic) | the annotation is the convention guard; removing it means isolation is the caller's job — plus 4 test call sites |

**Scopable to exactly these two call sites.** No general refactor: nothing else changes isolation, and
both services keep their current signatures.

### Risks, honestly

| | Risk | Mitigation / status |
|---|---|---|
| R1 | Thread-affinity trap — a `@ModelActor` adopts the executor of the thread that builds it; a plain `Task` silently gains nothing | Known and documented in `CSVImportActor`'s header; `Task.detached` is the established answer |
| R2 | Main context staleness — the actor deletes rows the main context has materialized | `CSVImportActor` already depends on cross-context merge working; the probe showed cross-context deletes merge silently rather than throwing. **Device verification still required.** |
| R3 | **The real one.** The review sheet is `@Query`-backed on the very rows being deleted. A live sheet holding references to rows deleted underneath is the dangling-reference class this project already paid for (V2 preflight repair, EXC_BREAKPOINT) | The current code already dismisses before the work — but that ordering becomes load-bearing rather than incidental, and a progress overlay implies staying on screen. **This is a design decision, not a refactor step.** |
| R4 | It does not fix the quadratic | 49 s of freeze becomes 49 s of spinner. Correct on your framing — broken → slow — but a 49-second modal spinner on a new user's first action is its own problem |

**Estimate:** ~1 day including device verification, concentrated in R3.

**Sequencing fact, not a proposal:** cases D and E put the mechanism fix's ceiling at a 40–60×
reduction — 49 s → roughly 1 s, at which point there is nothing to background. If that fix turns out
to be cheap, the ModelActor becomes optional rather than the shipping decision. If it turns out to be
expensive or risky, the ModelActor stands alone and ships without understanding the quadratic, exactly
as you said.

---

## Reproducing

```bash
xcodebuild test -scheme FinanceTracker -destination 'platform=iOS Simulator,id=<id>' \
  -only-testing:FinanceTrackerTests/SaveFailureReachabilityProbe \
  -only-testing:FinanceTrackerTests/BulkDeleteQuadraticMechanismTests \
  -parallel-testing-enabled NO
```

Probe ~1 s; mechanism experiment ~5½ min (case C alone deletes 16 000 rows).

---

## Still queued

`MonetizationGateFlowTests`, third branch first — begun fresh, not tacked onto this.
