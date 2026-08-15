# AUDIT — the §11 rollback drill cannot be walked for V2→V3, and why that is the finding

**Date:** 2026-08-02 · **Scope:** the §10 failure ladder and the §11 Step-4 drill, re-read against the
code as it ships in 1.0.3 (`a615e07`), asked one question: *what happens when the V2→V3 migration fails
on a real 1.0.3 user's device?*
**No code was changed producing this document.**

---

## 0. The answer, up front

**Nothing in the §10 ladder runs.** Not the backup, not the restore, not the retry. A V2→V3 migration
failure on a live 1.0.3 device goes straight to the degraded floor on the first throw, with **no backup on
disk to restore from**.

The drill was called a prerequisite. It is — but not because it is a box to tick. It cannot be walked at
all in the current code, and the reason it cannot is the same reason the migration would be unprotected.

---

## 1. Finding 1 — every 1.0.3 device takes the fast path, which has no safety net

`SharedModelContainer.swift:83`:

```swift
static var needsGuardedMigration: Bool {
    storeFileExists && !isMigrationComplete
}
```

`isMigrationComplete` reads the App Group default `v2MigrationComplete`. Trace it for a 1.0.3 device:

| Device | How it got the flag | `v2MigrationComplete` |
|---|---|---|
| Upgraded 1.0.2 → 1.0.3 | `markComplete` after the guarded ladder succeeded (`:202`) | **true** |
| Fresh 1.0.3 install | no store file → `needsGuardedMigration` false → fast path → `markComplete` (`:142`) | **true** |

So on **every** device now running 1.0.3, `needsGuardedMigration` is `false`, and `bootstrap()` takes the
fast path at `:137`. On that path:

- `StoreBackup.writeIfAbsent` is **never called** — it lives on the guarded path only (`:165`).
- The attempt sentinel is **never incremented** (`:192` is guarded-path).
- The `for attempt in (priorAttempts + 1)...(priorAttempts + 2)` retry loop (`:191`) is **not entered**.
- A throw from `openContainer()` returns `.failedPermanently(error)` **immediately** (`:151`).

Ship a V2→V3 migration into that and the failure path is: one attempt, no backup, no restore, no retry,
degraded floor. §10's promise — *"a mid-migration failure leaves working, exportable data"* — technically
survives, because the floor still opens read-only and exports. But every rung above it is gone, and the
rung that is gone is the one that recovers the user instead of stranding them.

## 2. Finding 2 — the backup those devices would restore from was already deleted

`StoreBackup.deleteAfterConfirmedGood` (`StoreBackup.swift:155`) clears the immutable flag and removes
`Backups/pre-v2/` on the second good launch (`SharedModelContainer.swift:146`).

That was correct for what it was designed for: the pre-V2 backup is a V1 store, it is worthless once V2 is
soaked, and keeping a duplicate ledger on the user's disk forever is its own problem. But the consequence
today is that **on every live 1.0.3 device the backup directory is already gone.** Even if the guarded
path were somehow entered, `StoreBackup.restore` would have nothing to copy back.

## 3. Finding 3 — the `--fail-migration` seam cannot fire for a lightweight V2→V3 stage

The seam is inside `StoreRepair.verifyNoDanglingReferences` (`StoreMigration.swift:99–104`), which is
reachable from exactly one place: the `didMigrate` closure of the **V1→V2** custom stage
(`StoreMigration.swift:57–59`).

A V2→V3 migration that adds only optional/defaulted attributes is a **lightweight** stage — no custom
stage, no `willMigrate`, no `didMigrate`, no call site. The seam is not merely inconvenient to reach; for
this migration it does not exist.

And a V2 store never runs the V1→V2 stage in the first place, so even a store that *did* reach
`verifyNoDanglingReferences` would only be doing so on the V1 path we are no longer testing.

## 4. Finding 4 — the sentinel is version-blind, and that is the root cause

Three keys and one directory are named for one specific migration:

| Symbol | Value | Location |
|---|---|---|
| `migrationCompleteKey` | `"v2MigrationComplete"` | `SharedModelContainer.swift:29` |
| `migrationAttemptKey` | `"v2MigrationAttemptCount"` | `:32` |
| `restorePendingNoticeKey` | `"v2RestorePendingNotice"` | `:35` |
| backup directory | `"Backups/pre-v2"` | `StoreBackup.swift:46` |

The names are not the problem — renaming them fixes nothing. The problem is what the flag **means**. It
records "this store finished *the* migration," a boolean about one historical event, and it is then used
to answer a different question: "does this store need guarding *now*?" Those were the same question
exactly once. From V3 onward they never are again.

**The root cause is that the completeness sentinel is a `Bool` where it needed to be a schema version.**

---

## 5. What has to change before a drill is meaningful

Three changes, and they are the real prerequisite the brief was reaching for. Costed, not applied:

1. **Make the sentinel version-aware.** Replace the boolean with the schema version the store was last
   confirmed good at — e.g. `storeSchemaVersionConfirmed: Int` (or the `Schema.Version` triple as a
   string). `needsGuardedMigration` becomes `storeFileExists && confirmedVersion < currentSchemaVersion`.
   Read the legacy `v2MigrationComplete == true` as "confirmed at 2.0.0" so existing devices migrate their
   sentinel without a second store touch. **This is the load-bearing change**; the other two are
   consequences.
2. **Make the backup generational.** `Backups/pre-v2` becomes `Backups/pre-v<n>`, written before *each*
   guarded bump and deleted after that bump's confirmed-good launch. Existing
   `deleteAfterConfirmedGood` semantics carry over unchanged, one directory at a time.
3. **Move the `--fail-migration` seam somewhere a lightweight stage still passes through.** The natural
   home is the post-open sanity probe in `bootstrap()` — right before or inside the
   `fetchCount(FetchDescriptor<Transaction>())` at `:201`, which every path executes regardless of whether
   the stage was custom or lightweight. That also makes the seam migration-agnostic, so V3→V4 gets it free.

Only after those does §11 Step 4 mean anything: launch with `--fail-migration` → attempt 1 dies → restore
from `Backups/pre-v3` → retry → dies → floor → relaunch clean → restore notice with the correct count.

**Corollary worth stating plainly:** these three are a prerequisite of *shipping V3*, not only of drilling
it. A V2→V3 migration shipped before them is a migration running on real user ledgers with its safety net
disconnected — which is the precise situation the brief's "this raises the stakes rather than lowering
them" was worried about, arrived at from a direction the brief did not anticipate.

---

## 6. The other blocker: there is no real V2 store on this machine

`store-rehearsal/` holds three copies — `original/`, `run-1/`, `run-2/`. All three are **V1 stores** from
the July 1.0.3 rehearsal:

```
$ sqlite3 store-rehearsal/original/Vela.sqlite ".tables"
ZCATEGORY  ZMERCHANTCATEGORYLEARNING  ZSOURCE  ZTRANSACTION  Z_METADATA  Z_MODELCACHE  Z_PRIMARYKEY
$ sqlite3 store-rehearsal/original/Vela.sqlite "select count(*) from ZTRANSACTION;"
7
```

No `ZTRANSACTIONSPLIT` table — that entity arrives with V2 — and 7 transactions, which is a fixture, not
the founder's ledger. `ZMERCHANTCATEGORYLEARNING` is still present, which V2 moves out to the local store.
These are pre-migration artifacts, correctly kept, and useless for a V2→V3 drill.

⚠️ **Disclosure:** reading those tables with `sqlite3` rewrote each copy's `-shm`/`-wal` sidecars (mtime
now 2026-08-02). The `.sqlite` contents are unchanged and the row counts verify, but if any of the three
was being preserved as byte-exact evidence, `run-1`/`run-2` are no longer byte-identical to what the July
run produced. They are untracked scratch from a completed rehearsal, so this is recorded rather than
repaired.

> ### ⚠️ 2026-08-14 — WHAT THE §11 DRILL ACTUALLY PROVED, and what it structurally could not
>
> A field bug (`BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`) showed that **a store last written
> by 1.0.0 cannot be migrated at all** — the declared `FinanceTrackerSchemaV1` is the **1.0.2**
> shape, because it carries `isPossibleDuplicate`, added 2026-07-11, *the day after 1.0.0 shipped*.
> Such a store matches no version the plan knows, and the §10 ladder — working exactly as designed —
> strands the user on the terminal floor screen in 188 ms.
>
> **The §11 drill passed, and could not have caught this.** Its fixture is the same three copies
> described above: all 1.0.2-era, all carrying the column. The drill validated **one path through
> the migration — the path that works.** It did not validate the migration.
>
> The generalisation is the part that lands on V3, so state it plainly:
>
> > **The declared schema versions have never been checked against what SHIPPED BINARIES actually
> > wrote.** They are checked against each other, and against fixtures drawn from a version that
> > already works.
>
> `FinanceTrackerSchemaV1` turned out not to describe 1.0.0. **Nobody has verified that
> `FinanceTrackerSchemaV2` describes what 1.0.2, 1.0.3 and 1.0.4 actually put on disk** — and V3
> will meet those stores on devices holding real ledgers, where the failure mode is this same
> terminal screen with no way out. The V1 case was survivable partly because the affected stores
> were nearly empty; that is luck, not a property of the design.
>
> A fixture drawn from a working version can only ever confirm the path that works. The fix for the
> class — one captured fixture per shipped version, generated by building the shipping commit and
> capturing what it writes — is proposed in `PROPOSAL_STORE_FIXTURE_CORPUS_2026-08-14.md`. **That
> test would have caught this before 1.0.3 shipped**, and it is the only thing that will catch the
> V3 version of it. The first fixture already exists (`FinanceTrackerTests/Fixtures/StoreV1_0_0`,
> captured from `1e9b20b`) with the regression test that fails without the fix.

**A real V2 store requires a founder action** — the §11 Step 1 route: Settings → Debug → "Share raw store
files" on the 1.0.3 device, AirDrop the zip to the Mac, drop it in `store-rehearsal/v2-original/`.
(Reminder from §11: Xcode's *Download Container* does **not** include App Group containers and silently
yields no store.)

**On "a real device" vs a copy:** the brief asks for the drill on a real device. §11 Step 1 says the
opposite, deliberately — *"It runs on a COPY; the device is never the test bench."* That rule should hold
here and for a sharper reason than when it was written: the drill deliberately fails a migration twice
against the store it is pointed at. Running that on the founder's live 1.0.3 device means deliberately
corrupting the only real ledger in existence, on the one build users are running, with the restore ladder
under test rather than trusted. The simulator + real-store-copy route (Stage B) exercises every rung
including the App Group defaults, the backup write, and the floor screen. Recommend keeping it.

---

## 7. Status against the brief's item 6

| Rung | Walked? | Why |
|---|---|---|
| restore | **No** | Unreachable: fast path, and no backup on disk (§1, §2) |
| retry | **No** | Unreachable: the retry loop is guarded-path only (§1) |
| floor | **Not walked** | Reachable — it is the *only* reachable rung — but walking it proves nothing until §5's changes exist, because reaching it first-throw with no backup is the defect, not the pass condition |

**Nothing was drilled. The drill was not skipped for convenience — it was found to be unreachable, and
the reason it is unreachable is a defect that would have shipped silently underneath the V3 migration.**
