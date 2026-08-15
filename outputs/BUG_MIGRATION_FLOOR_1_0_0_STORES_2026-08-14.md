# Field bug: 1.0.0-era stores are stranded on the migration floor

**Status: REPRODUCED, ROOT-CAUSED, FIXED (both halves) — see §7. Not yet committed or released.**
Reported 2026-08-14 by Anton Kyriachok (tester): installed 1.0.0, never used it, updated straight to
1.0.4. Pre-migration screen → Continue → *checkmark + "your data is safe"* → the app never went
further. He recovered by **deleting and reinstalling**, which discards the store.

---

## 1. Which screen is reached — measured, not reasoned

The question posed was (a) `bootstrap()` never returns, or (b) it returned `.ready` and RootView
drew nothing. **It is neither.** Instrumented `LaunchGateView` phase transitions (`LAUNCHPROBE`,
`persistenceLog`) on a simulator carrying a real 1.0.0-created store:

```
LAUNCHPROBE decide storeFileExists=true migrationComplete=false needsGuarded=true
            hasCompletedOnboarding=false attempts=0
LAUNCHPROBE phase=preMigration
LAUNCHPROBE phase=migrating (bootstrap about to start)
LAUNCHPROBE bootstrap ENTER
pre-V2 backup written: 3 file(s)
save failed [SharedModelContainer.migrate(attempt 1)] domain=SwiftData.SwiftDataError code=1
pre-V2 backup restored (attempt 1)
save failed [SharedModelContainer.migrate(attempt 2)] domain=SwiftData.SwiftDataError code=1
pre-V2 backup restored (attempt 2)
LAUNCHPROBE bootstrap RETURNED .failedPermanently in 188ms err=SwiftData.SwiftDataError/1
```

**(c): `bootstrap()` returned `.failedPermanently` in 188 ms, and the app rendered the degraded
floor (`MigrationFloorView`) — which is a terminal screen by design.** Nothing hung and nothing
took minutes. The migration ladder ran to completion — attempt, restore, retry, restore, stop —
in under a fifth of a second, and stopped exactly where §10.4 says it should.

The user's description matches that screen verbatim: `MigrationFloorView` draws
`Image(systemName: "checkmark.shield")` above `floor.title` = *"Your data is safe"* / RU *"Ваши
данные в безопасности"* (his device is `ru`). He was not looking at a hang. He was looking at the
designed floor, which has no way forward.

UI-driven confirmation, same store: `PRE_MIGRATION` → tap Continue → **`FLOOR` in 0.2 s**, with
exactly two controls on screen: `["Export my data", "Contact support"]`.

## 2. Root cause: the declared V1 schema is the 1.0.2 shape, not the 1.0.0 shape

`FinanceTrackerSchemaV1` (`FinanceTrackerSchemaV1.swift:43`) declares
`var isPossibleDuplicate: Bool = false` on `Transaction`. That property was added on **2026-07-11**
(`c1d59e4`, *"feat(import): persist the possible-duplicate flag on the transaction"*) — **one day
after 1.0.0 was released (2026-07-10).**

A store written by 1.0.0 therefore has no `ZISPOSSIBLEDUPLICATE` column, while the migration plan's
*earliest* known version says it must. Diffing the two stores column-by-column, that is the **only**
difference anywhere in the schema:

| table | 1.0.0-created store | 1.0.2-era rehearsal fixture |
|---|---|---|
| `ZTRANSACTION` | …ZISDEMO, **(absent)**, ZMERCHANT… | …ZISDEMO, **ZISPOSSIBLEDUPLICATE**, ZMERCHANT… |
| `ZCATEGORY` | identical | identical |
| `ZSOURCE` | identical | identical |
| `ZMERCHANTCATEGORYLEARNING` | identical | identical |

So the store on disk is effectively a **V0** that the plan has no stage for, and
`ModelContainer(for:migrationPlan:configurations:)` throws `SwiftData.SwiftDataError` code 1 on both
ladder attempts.

**The rehearsal fixtures could not have caught this.** `store-rehearsal/original` is a 1.0.2-era
store — it *has* the column, and it migrates cleanly: `.ready` in **1403 ms**, RootView appeared.
That is why the drill passed and the field did not.

## 3. Scope — who is stuck, measured per version

Every row below was produced by installing that version on an erased simulator, launching it to
create/settle its store, then installing 1.0.4 over it and walking the upgrade.

| store last written by | `ZISPOSSIBLEDUPLICATE` | `v2MigrationComplete` | 1.0.4 upgrade result |
|---|---|---|---|
| **1.0.0** | **absent** | unset | **FLOOR — stranded** (`.failedPermanently`, 188 ms) |
| 1.0.1 | present | unset | `.ready` in 2710 ms → RootView |
| 1.0.0 then opened once under 1.0.1 | **added by that launch** | unset | `.ready` in 1526 ms → RootView |
| 1.0.2 (rehearsal fixture) | present | unset | `.ready` in 1403 ms → RootView |
| 1.0.3 | present | **true** | fast path, **no pre-migration screen at all**, `.ready` in 146 ms |

**The criterion is not "which version they installed" — it is which version last RAN.** Installing
an update does not open the store; only launching does. So the stranded population is:

> **anyone whose most recent LAUNCH of Budget Crab was 1.0.0**, who then updates to 1.0.3 or later.

Merely opening 1.0.1 (or 1.0.2) once rescues the store permanently — SwiftData lightweight-migrates
the missing column in on that launch (measured: column count 0 → 1), and the later guarded migration
then succeeds.

**1.0.3 users are NOT affected — confirmed, not assumed.** Their store carries
`v2MigrationComplete = true`, so `needsGuardedMigration` is false, `decide()` never shows the
pre-migration screen, and bootstrap takes the fast path in 146 ms.

**Upgrade paths that hit it today: two — 1.0.0 → 1.0.3 and 1.0.0 → 1.0.4.**

**This is not a 1.0.4 regression.** A 1.0.0 store put through **1.0.3** lands on the same floor
(measured: `PRE_MIGRATION` → `FLOOR` in 0.1 s). The defect has been live since **1.0.3 became
available on 2026-07-29** — roughly two weeks longer than the 1.0.4 framing suggests.

Size, stated as an unknown rather than guessed: the app was released 2026-07-10 and 1.0.1 followed
within days, so the exposed set is *installs from that window that were never opened again until an
update landed*. **We have no install-base or version-distribution number** — App Store Connect can
answer this and has not been consulted. "Some early users" vs "everyone who lapsed" is not decidable
from here.

## 4. The escape hatch on the stuck screen is ALSO broken — for exactly this population

The floor screen tells the user to *"export a copy, and write to us"*. **The export fails.** Tapping
"Export my data" on the stranded 1.0.0 store produced the failure line — *"The export didn't work…"*
— with no share sheet, and the plain button still in place.

The reason is the same defect one level down: `openV1ReadOnly()` opens the store with
`Schema(versionedSchema: FinanceTrackerSchemaV1.self)` — the **same declared V1 shape the store does
not match**. The comment above it says *"The schema matches the disk exactly, so this open can never
trigger a migration"*, and for a 1.0.0 store that premise is false.

So a stranded user is offered two controls, and one of them does not work:

- **"Export my data"** → fails, for the same reason they are stranded.
- **"Contact support"** → a `mailto:`, which is how this report reached us.

There is no control that returns them to the app, and none that preserves their data. **The obvious
next move — delete and reinstall — is the only thing that "works", and it destroys the ledger.** The
reporter had nothing to lose. A user with a real ledger doing the same thing loses all of it, and
the screen never warns them.

Worth stating precisely because the copy is otherwise honest: **"Your data is safe" is TRUE.** The
ladder restored the pristine backup on both failures, the store on disk is intact and unmigrated
(verified: the column count is still 0 after the failed run, and the row counts are unchanged), and
the pre-V2 backup files were written before anything opened the store. The data is fine. The
sentence is accurate. What is missing is any way for the user to act on it.

## 5. Falsified along the way

- **"He may never have completed onboarding, and RootView no longer branches on
  `hasCompletedOnboarding`."** Not the cause. `hasCompletedOnboarding=false` was present in **every**
  run recorded here, including all four that reached RootView normally.
- **(a) a slow or hung migration.** Ruled out by the clock: the whole ladder finishes in 188 ms.
  There is no long-running work to wait through, so "give it more time" is not advice that would
  have helped him.
- **(b) `.ready` with an empty RootView.** Ruled out: the outcome was `.failedPermanently`, and every
  `.ready` in these runs was followed by `LAUNCHPROBE RootView appeared` within ~30 ms.

## 6. How this was reproduced (so it can be re-run)

1. Worktrees at the shipped points: `1e9b20b` (2026-07-10, last 1.0.0-shape commit — Transaction has
   no `isPossibleDuplicate`), `43792fc` (1.0.1), `v1.0.3-build7`, `v1.0.4-build8`.
2. `LAUNCHPROBE` instrumentation added to `LaunchGateView` in the 1.0.4 worktree only (log-only, no
   behaviour change): phase transitions, bootstrap enter/return, outcome, elapsed ms, and a
   `RootView appeared` marker.
3. Erase simulator → install the old build → launch → terminate (this writes the era-correct store)
   → install 1.0.4 → launch.
4. Taps driven by XCUITest (`FieldUpgradeReproTests`, `FloorExportReproTests`) because `idb` is not
   installed on this machine; the tests only record which screen is reached, and assert nothing about
   the outcome.
5. Store shapes read directly with `sqlite3 PRAGMA table_info(...)` before and after each step.

**Caveat, stated rather than papered over:** all repro builds are **Debug**, not the Release binary
in the store. The failing path contains no `#if DEBUG` branch and the failure is schema matching at
container-open time, so configuration is not expected to matter — but it was not measured on a
Release build, and the field report is the only Release evidence.

The rehearsal fixtures in `store-rehearsal/` were used first and did **not** reproduce it; they are
1.0.2-era stores. The reproducing artefact is a store created by an actual 1.0.0-era build.

---

## 7. The fix — both halves, each measured

### 7.1 Root fix: one extra open, not a new schema version

**The cheap route was tested first and it works.** 1.0.1 opened the very same store successfully
because a **planless** open lets SwiftData lightweight-migrate — it added the missing column itself.
The engine can do this; only the *stage machinery* cannot, because it asserts a version match before
it will start. So the store is lifted to the declared V1 shape by a plain open, and the plan then
recognises it:

`SharedModelContainer.liftToDeclaredV1IfNeeded(storeURL:)`, called from
`openContainer(storeURL:localStoreURL:preflightRepair:)` under the existing `preflightRepair` gate —
i.e. **guarded path only, strictly after the §9.2 backup exists**, because a lightweight migration is
a write. A throw is swallowed on purpose: if the lift cannot help, behaviour is byte-identical to
before, the ladder runs, and the floor still catches it. **It can only convert a failure into a
success, never the reverse.**

No V0 stage was added. A new stage is itself a migration that has to be right; this is one open.

Measured, end to end on the simulator, 1.0.0 store → 1.0.4:

| store | before the fix | after the fix |
|---|---|---|
| 1.0.0, empty | FLOOR (`.failedPermanently`, 188 ms) | `.ready` 1721 ms → RootView |
| 1.0.0, **33 transactions** | FLOOR | `.ready` 1987 ms → RootView |
| 1.0.1 | `.ready` 1466 ms | `.ready` 1466 ms (lift is a **99 ms** no-op) |
| 1.0.2 rehearsal fixture | `.ready` 1403 ms | `.ready` 2419 ms (lift is an **86 ms** no-op) |
| 1.0.3 | fast path, 146 ms | unchanged — never enters the guarded branch |

**Data preservation, checked rather than assumed** (populated 1.0.0 store, before → after):
33 → 33 transactions, `sum(amountCents)` 635473 → 635473, 33 distinct uuids → 33, transactions with
a category 33 → 33, with a source 33 → 33, categories 13 → 13, sources 3 → 3, and the V2
`ZTRANSACTIONSPLIT` table created.

### 7.2 Escape hatch: the export retries, and the screen now says what deleting costs

- **`MigrationFloorView.prepareExport()`** now retries after lifting, guarded on
  `StoreBackup.backupExists()`. Verified on the one path that still reaches the floor with a pre-V1
  store — a 1.0.0 store plus the DEBUG `--fail-migration` seam, where the ladder restores the
  **pre-lift** backup, so the first export attempt fails exactly as in the field. App log:
  `floor export: succeeded on the post-lift retry`, and the failure line is gone.
- The **pre-migration** screen's export deliberately does NOT get this retry: it runs before any
  backup exists, and no write may precede the safety net.
- **`floor.delete_warning`** (new, 5 locales): *"Don't delete the app — that erases this data from
  your device. Export a copy first."* Verified visible on the floor.
- **`floor.export_failed`** (new, 5 locales) replaces the borrowed `premigration.export_failed`,
  which ends *"you can still continue safely"* — on the floor there is nothing to continue to. The
  new string points at support and says not to delete the app.
- The false comment on `openV1ReadOnly()` — *"the schema matches the disk exactly, so this open can
  never trigger a migration"* — is corrected in place, with the reason it was false.

### 7.3 Tests

`FinanceTrackerTests/PreV1StoreMigrationTests.swift`, against
`FinanceTrackerTests/Fixtures/StoreV1_0_0` (captured from `1e9b20b`; see its `MANIFEST.md`):
premise (fixture really is older than declared V1), the regression (opens through the guarded path),
data preservation (amounts, uuids, category links), and lift idempotence.

**Discrimination check — the test was proven to fail without the fix.** With the lift call commented
out: `exit 1`, 2 of 4 failed (`test_preV1Store_opensThroughTheGuardedPath`,
`test_preV1Store_preservesAmountsAndLinks`). With the fix restored: 4/4, exit 0. A regression test
never observed failing is a guess, and this project has shipped that mistake before.

**Full unit target after the fix: 1029 passed, 0 failed, 3 skipped, exit 0.**

### 7.4 Not done

- The **UI-level** test of the floor's export needs external setup (place a pre-V1 store, launch with
  `--fail-migration`), so it is not a suite member. Verified by hand; the scratch test was deleted. A
  `--seed-pre-v1-store` DEBUG seam would make it hermetic —
  `PROPOSAL_STORE_FIXTURE_CORPUS_2026-08-14.md`, decision 5.
- **Release-configuration verification.** All measurements here are Debug builds.
- **Users already stranded** are not reached by this fix until they install the release carrying it.
  They can update; nothing about their store prevents the fixed build from migrating it — but anyone
  who already deleted and reinstalled has lost the ledger, and that is not recoverable by any code.
