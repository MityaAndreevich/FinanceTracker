# Save-failure side effects, the reachability class, and the bulk-delete mechanism fix

Date: 2026-08-05. Follows `outputs/BRIEF_BULK_DELETE_P1_P2_P3.md` and `outputs/MEASUREMENT_BULK_DELETE_CURVE.md`.

---

## Task 1 — the dangerous shape: a side effect not conditioned on the save

### Fixed

`RecurrenceService.confirm` (:200) and `stopRecurrence` (:220). Both now save first,
`rollback()` + `logSaveFailure` on throw, and write the UserDefaults watermark only on
success. Both return `Bool`; `RecurringPromptSheet` advances only on success and alerts
otherwise, `RecurringSettingsView` alerts. No new localized strings (`common.error` +
`add.error.save_failed` / `edit.error.save_failed` already ship in all five .lproj).

`stopRecurrence` also restores `recurrenceRaw` explicitly before `rollback()`. That is not
belt-and-braces: `rollback()` does not reliably revert a mutated attribute on a live object
(established in `TransactionEditServiceTests`, which is why `TransactionEditService` carries a
snapshot). Without the restore the series would stop anyway, minutes later, on the next
unrelated save.

Regression: `FinanceTrackerTests/RecurrenceWatermarkOrderingTests`. Failure induced with a
real read-only store (NSCocoaErrorDomain 513), same as `SaveFailureReachabilityProbe` — not a
mocked throw. **Verified to bite**: reverted to the old ordering, the two failure-path tests
fail on 7 expectations between them, including `handledDate → 2026-07-06` where nil is
required, and `template.recurrence → nil` after a failed stop.

Harness note: `handledDate` round-trips `Date → Double → Date` through UserDefaults, so an
`==` assertion on a watermark flakes. Compare with a tolerance. Harmless in production — the
value only ever seeds `nextDate(after:)`.

### The other 10, ranked by consequence

The shape is *a side effect outside the store's transaction that is not conditioned on the
save*. Ordering (before vs after) is incidental; **unconditional** is the defect. Seven of the
ten have it.

| # | Site | Unconditioned side effect | Consequence on a failed save |
|---|------|---------------------------|------------------------------|
| 1 | `DashboardView:616` `undoLastAutoSave` | disarms the undo window, success haptic, `"quickadd.undo.confirmed"` toast, widget snapshot | **Worst remaining.** The transaction is still there, the user is told it was undone, the undo is unrepeatable — and the abandoned delete rides along on the next ordinary save (mechanism proven in `SaveFailureReachabilityProbe.pendingDeletesRideAlongOnTheNextSave`). Destructive, deceptive, one tap. This is the duplicate-review defect on the shake gesture. |
| 2 | `TransactionsView:198` `delete` | none (DEBUG print only) | Swipe-delete. No rollback ⇒ same ride-along. Less deceptive than #1 (the `@Query` re-shows the row) but the row still disappears later, unasked. |
| 3 | `DemoDataController:39` `clearDemoData` | `isDemoDataActive = false` (UserDefaults) | Demo rows survive but the app believes demo is off ⇒ `seedDemoData` re-seeds ⇒ **duplicate demo rows in the real ledger**. |
| 4 | `DemoDataController:117` (+ caller :31) | `isDemoDataActive = true` | Flag says demo active with no rows; clear is a no-op and the banner cannot be dismissed by clearing. |
| 5 | `CategoriesSourcesView:587` `AddSourceSheet.add` | `onAdded?()`, `dismiss()` | User told the account was added; it wasn't. Interacts with the free-tier 2-account cap. |
| 6 | `CategoriesSourcesView:505` limit set | `FeatureUsageSignals.markUsed(.categoryLimits)`, `dismiss()` | Low user harm, but `usage.ever.*` is the **pre-test measurement instrument** with a pre-registered kill rule (`project_receipt_ocr_pretest_instrument`). Recording "used" for a feature the user did not get corrupts the number a ship/kill decision rests on. |
| 7 | `CategoriesSourcesView:488` limit clear | `dismiss()` | Sheet closes; the limit is still set. |
| 8 | `CategoriesSourcesView:398` `saveContext` | none | Generic catch, DEBUG print, no rollback. |
| 9 | `DemoSeeder:161` `clearDemoData` | none | Self-healing: `hasDemoData` derives from the store. Only defect is the missing rollback. |
| 10 | `SeedService:118` (also :89, :211) | none | Genuinely benign. Idempotent by `nameKey`, retried every launch, derived from the store. **Leave alone.** |

Recommended order if this gets scheduled: 1, 2 (both destructive and both already have a
proven mechanism), then 3/4 (silent data duplication), then 5–8, then stop.

---

## Task 2 — can any of the 12 throw on a HEALTHY store?

**Answer: no. All 12 are in the store-failure class. But that classification does not carry
the weight the emergency-vs-scheduled decision is putting on it — see the caveat.**

Every model-level throw mechanism is structurally dead at HEAD:

| Mechanism | Cocoa code | Status at HEAD | Basis |
|---|---|---|---|
| `.deny` delete rule | 1600 | **Dead.** No `.deny` anywhere; every rule is `.nullify` or `.cascade` | grep of `Models/` + `FinanceTrackerSchemaV1.swift` |
| Mandatory-property validation | 1570 | **Impossible.** The V2 CloudKit shape: every synced attribute has a default, every relationship is `Optional` (`Transaction.category/source/splits`, `TransactionSplit.parent/category`, `Category.transactions/splits`, `Source.transactions`). Nothing can be nil-at-save that the type system allows to be nil | code |
| `.unique` constraint | 133021 | **Does not throw — it upserts.** Only `MerchantCategoryLearning.merchantNormalized`, in the local store | demonstrated, `SaveFailureReachabilityProbe` cases 1 & 2 |
| Merge conflict | 133020 | **Merges silently** in the realistic two-context shape (`CSVImportActor` vs `mainContext` deleting the same row) | demonstrated, probe case 4 |
| Type not in the configuration schema | — | Impossible; `fullSchema` covers all five models | code |
| Cross-configuration relationship | — | Impossible; `MerchantCategoryLearning` has no relationships | code |
| Read-only store (`allowsSave: false`) | 513 | **Unreachable from these sites.** Two uses: `openV1ReadOnly` (export only, its own container) and the migration floor — and the floor is a *terminal screen* (`MigrationFloorView` replaces the app UI at `LaunchGateView:72`), so no ordinary surface ever runs on a read-only container | code |
| File protection | 513 | **Deliberately closed.** `.completeUntilFirstUserAuthentication`, not `.complete`, precisely because `AddTransactionIntent` runs headless and can fire while locked (`SharedModelContainer:340`). The residual pre-first-unlock-after-reboot window fails at container *open*, before any of these sites | code + its own comment |

### The caveat, which is the part that actually decides it

"Store-level" was being read as "as rare as hardware failure." That equation does not hold,
for one reason: **out-of-space is store-level and is not hardware trouble.** A phone at 100%
full is an ordinary, common state, and `SQLITE_FULL` surfaces as `NSFileWriteOutOfSpaceError`
(640) out of exactly these `save()` calls. The previous session could not induce disk-full in
the simulator, so this is inference from the Cocoa error taxonomy and the code path, **not
demonstration** — the honest status is "believed reachable, unmeasured."

So the risk model is not "requires a broken device." It is "requires a full device," which is
a normal-population condition rather than a tail one.

What that means for the decision, stated plainly and left to you: the *frequency* argument
does not support emergency, but it does not support "as rare as hardware failure" either. The
ranking above is by consequence for a reason — `DashboardView:616` is a destructive,
deceptive, one-tap path, and its cost if it fires is the same whether it fires once a year or
once a month.

One forward dependency worth recording: this whole answer is contingent on
`cloudKitDatabase: .none`. Turning sync on in 1.0.4 adds a mirroring layer to the save path
and this classification has to be redone, not inherited.

---

## Task 3 — the mechanism fix (proposal only, nothing implemented)

Recap of the measurement (`12e642c`): the cost is removing each deleted row from its
`Category.transactions` to-many **by identity**, O(collection) per row ⇒ O(n²/categories).
B/E = 62× (44 664 ms → 720 ms with `category == nil`); B/D = 36.8× (7 categories vs 400);
B/C = 1.51 — deleting half as many costs *more* when half survives. The delete loop is 0.08%.

**A gap in the measurement that changes the target.** Every seeded row had `source == nil`
and no splits. Real users have accounts assigned, and `Source.transactions` is a second
to-many with an explicit inverse — same maintenance, same shape. So **49.2 s at 8k is a lower
bound for the shipped app**, not the number. Any fix has to detach `source` too, and the
re-measurement should seed both.

### Option 1 — nil the relationship before deleting

```swift
for tx in rows { tx.category = nil }        // then delete, then save
```

**Predicted effect: none, or worse. Do not do this.** It performs the *same* identity-removal
from the *same* large collection, just at assignment time instead of at save time. The
collection does not shrink meaningfully, because the survivors — 8 000 of them in case B — are
what keep it large, and they are not being touched. This targets the wrong thing for exactly
the reason "batch delete instead of per-object" targets nothing: it relocates work the
measurement already attributed elsewhere.

Risk: low. Value: none. Cheap to falsify with the existing harness if you want it on the
record rather than argued.

### Option 2 — `context.delete(model:where:)`

**Effect: potentially below E's floor** (E still materializes and saves 16 000 objects; a
store-level delete does not). **Risk: the highest of the three, in two ways.**

1. **`.cascade` on `Transaction.splits` — the quiet data-loss risk you named.** I will not
   assert what a SwiftData batch delete does to it in either direction; the honest position is
   that **this is unknown at HEAD and is not answerable from the docs with the confidence a
   ship decision needs.** It is directly measurable and must be measured *before* this option
   is chosen: seed parents with splits, batch-delete the parents, count surviving
   `TransactionSplit` rows in a fresh context. Orphaned splits are invisible to aggregation
   (`CategoryAttribution` derives from the parent) — which means this failure would be
   **silent**, a growing set of unreachable rows nobody sees. Note the existing seeds cannot
   answer this: splits are nil in every measurement case.
2. **Staleness — the R3 dangling-reference class this project has already paid for.** A
   store-level delete does not update the in-memory graph. `DuplicateReviewView` holds a
   `@Query` over exactly the rows being deleted, and the long-lived `mainContext` has them
   materialized. The mitigation is a `reset()`/re-fetch, which then has to be sequenced against
   an open sheet.

Also note it changes the transactionality answer that was just settled: the current paths are
one `save()` at the end and an interrupted run loses nothing.

### Option 3 — detach from the *other* side, in one pass (recommended)

The measurement says the cost is **per-row identity search over a large array**. Then don't do
it per row. Rebuild each affected collection once:

```swift
let doomed = Set(rows.map(\.persistentModelID))
for cat in affectedCategories {
    cat.transactions = cat.transactions?.filter { !doomed.contains($0.persistentModelID) }
}
// same for the affected Sources
for tx in rows { modelContext.delete(tx) }
try modelContext.save()
```

O(deleted × collection) → O(categories × collection) = O(table). And it lands the delete in
**E's condition** — `category == nil` (and `source == nil`) at delete time, nothing left to
maintain — which is the state E measured at 720 ms.

**Expected: ≈ E's 720 ms plus one linear pass, so roughly 0.7–1.2 s at 8k.** D is the sanity
check on that estimate: at 400 categories, D still came in at ~1.2 s rather than at the floor,
so "spread the collection thinner" alone does not reach 720 ms — nulling does. Option 3 nulls.

**Risk: low.** Ordinary object-graph code. Stays one transaction, keeps `.cascade` honest,
leaves no stale in-memory state, needs no `reset()`, touches no delete rules.

**The one thing that has to be checked before committing to it:** whether SwiftData treats a
whole-array assignment to a to-many as a single operation or diffs it element-by-element. If
it diffs by identity, Option 3 degenerates into Option 1 and buys nothing. That is one
measurement on the existing harness (add it as case F, same seed as B), and it is the
gate — not a reason to prefer Option 2 in the meantime.

### Recommendation

Measure case F first (Option 3's assumption), and case G (Option 2's cascade behaviour with
splits seeded) alongside it, since both are the same harness and the same afternoon. Then
implement Option 3 if F holds. **Option 3 is the one I expect to reach the 720 ms floor**,
because it is the only one of the three that reaches E's *condition* rather than trying to
make E's *cost* smaller.

Both bulk paths benefit: `TransactionResetService.reset` (9.0 s at 8k) pays the same
per-row identity cost, just against collections that happen to be collapsing.

Concurs with your sequencing conclusion: at ~1 s there is nothing left worth moving to a
`@ModelActor`, and the actor would carry R3 — which is also the reason Option 2's staleness
problem is not a small one.
