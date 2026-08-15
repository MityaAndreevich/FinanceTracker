# Proposal: a store fixture per shipped version

**Status: AGREED AND BUILT, 2026-08-15.** All five decisions were taken as proposed; what follows is
the proposal as written, then §"What was actually built" records the result and the two things the
build taught that the proposal did not anticipate.

## Why

`FinanceTrackerSchemaV1` turned out to be the **1.0.2** shape, not the 1.0.0 shape. That went
unnoticed for two releases because **the only fixtures we have are 1.0.2-era**, so every drill
validated the path that works. A store last written by 1.0.0 strands its owner on the terminal floor
screen (`BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`).

The general defect is not that one column was missed. It is that **we have never checked a declared
schema version against what a shipped binary actually wrote.** Versions are checked against each
other and against fixtures we produced ourselves, which cannot expose a disagreement with a build.

**This lands on V3.** V3 will meet stores written by 1.0.2, 1.0.3 and 1.0.4 — on devices with real
ledgers. Nobody has verified that `FinanceTrackerSchemaV2` matches what those builds put on disk. If
it does not, the failure mode is the same terminal screen, on users with data. The V1 instance was
survivable partly because 1.0.0-era stores are nearly empty. That is luck.

## What a fixture is

A store captured from a **shipping commit's own binary**, never constructed from today's model types
— a store this repo builds today is by definition the shape we already believe in.

Generation, exactly as done for the first one:

1. `git worktree add <dir> <shipping-commit>`
2. build that worktree for the simulator
3. erase a simulator, install, launch with `--demo-mode` (deterministic rows), terminate
4. copy `Vela.sqlite{,-shm,-wal}` out of the App Group container
5. record, beside the fixture: commit, marketing version, build number, capture date, row/table
   counts, and the raw `PRAGMA table_info` for each table

Step 5 matters as much as the file. The fixture's value is that it is **evidence about a released
binary**, and an unlabelled `.sqlite` is not evidence of anything.

## Proposed shape

```
FinanceTrackerTests/Fixtures/
  StoreV1_0_0/   Vela.sqlite + MANIFEST.md      ← EXISTS (1e9b20b, 33 tx, no ZISPOSSIBLEDUPLICATE)
  StoreV1_0_1/   …                              ← proposed
  StoreV1_0_2/   …                              ← proposed
  StoreV1_0_3/   …                              ← proposed (first V2-shaped store — the V3 gate)
  StoreV1_0_4/   …                              ← proposed
scripts/capture-store-fixture.sh <commit> <label>   ← proposed, regenerates any one of them
```

And one test that grows by a line per version:

```swift
// for each fixture: stage a COPY, open it through the real guarded path, assert it opens
// and that the rows/amounts survive.
func test_everyShippedStoreShape_migratesUnderTheCurrentPlan()
```

## Decisions I want agreed before building

1. **Which versions.** All five, or only those a user can still be sitting on? 1.0.0–1.0.2 are the
   unmigrated shapes; 1.0.3/1.0.4 are the V2 shapes that V3 will meet. My view: **all five** — the
   V2-shaped ones are the point of the exercise for V3, and the unmigrated ones are the only guard
   on the class we just hit.
2. **Committed or generated?** Five stores ≈ 600 KB of binary in git, forever, versus a script that
   regenerates them (needs old commits to still build — `1e9b20b` built fine today with the current
   Xcode, but that is not guaranteed to hold). My view: **commit the files AND keep the script.**
   The files are the evidence; the script is how new versions join. A fixture that only exists when
   an old commit still compiles is a fixture that disappears exactly when it becomes historical.
3. **Where the test lives.** A per-fixture case in the unit target (hermetic, staged to a temp dir —
   the existing `PreV1StoreMigrationTests` pattern), versus a UI-level launch drill. My view:
   **unit target.** It runs in seconds, needs no simulator choreography, and exercises the real
   `openContainer(...)` production path.
4. **Does capture belong in release ritual?** Proposed: capturing the fixture for version *N* is a
   step in shipping *N*, not archaeology performed later under pressure. Cheap at the time, and it
   is the only moment the binary is definitely buildable.
5. **What the floor's escape hatch needs.** Verifying the export fix required an external setup step
   (place a pre-V1 store, then launch with `--fail-migration`), so it is not a suite member today —
   I verified it by hand and deleted the scratch test. A `--seed-pre-v1-store` DEBUG seam, feeding
   from these fixtures, would make it a real UI test. Worth it, or is the unit-level coverage plus a
   manual check enough?

## What this would have cost, and what it would have bought

Building the first fixture end-to-end — worktree, build, capture, test, discrimination check — took
well under an hour. **It would have caught this bug before 1.0.3 shipped**, i.e. before two releases
went out that strand a real (if small) group of users on a dead-end screen with a broken export.


---

# What was actually built (2026-08-15)

- **Five fixtures**, one per shipped version, in **`StoreFixtures/`** — each with a generated
  `MANIFEST.md` (commit, subject, version, build, capture date, counts, raw `ZTRANSACTION` columns).
- **`scripts/capture-store-fixture.sh`** — worktree → build → erase → install → `--demo-mode` →
  capture → manifest. Refuses to overwrite without `FORCE=1`; warns loudly on a zero-row capture.
- **`ShippedStoreShapeTests`** — 7 tests: the corpus is complete (a missing fixture FAILS, it does
  not silently reduce coverage), each of the five shapes opens under the current plan with rows,
  amounts and category links intact, and the corpus genuinely **spans distinct shapes**. That last
  test exists because five identical stores would pass everything else and prove nothing.
- **`--seed-pre-v1-store` DEBUG seam** + **`PreV1UpgradeFlowTests`** (2/2 green): the pre-V1 upgrade
  and the floor's escape hatch are now hermetic UI tests. This is the check that previously had to be
  run by hand and deleted.
- **`GO_LIVE_CHECKLIST §3`**: tag the submitted commit, capture the fixture, run the migration repro
  against a Release build — all three at submission time.

## Two things the build taught

**1. Fixtures cannot live inside the test target's directory.** `FinanceTrackerTests/` is a synced
root group, so five directories each holding a `Vela.sqlite` were auto-added as bundle resources and
collided: *"Multiple commands produce …/FinanceTrackerTests.xctest/Vela.sqlite"*, five errors, build
failed. They live at repo-root `StoreFixtures/` instead and are located by path from `#filePath` —
which was already the design (a bundle resource that silently fails to copy makes the test pass
against nothing), and is now also a build requirement.

**2. An untagged release makes "which commit shipped" a judgment call, and the version string is not
enough to settle it.** The first 1.0.2 capture used `49d32a9`, the last commit carrying
`MARKETING_VERSION = 1.0.2` — and it already contained `ZTRANSACTIONSPLIT`, because the V2 schema
landed 19 minutes before the version was renumbered. That fixture was 1.0.3 development wearing a
1.0.2 label. It was caught by **inspecting the captured shape**, not by trusting the metadata — the
same discipline the whole corpus exists to enforce, applied to the corpus itself. Re-captured from
`bc8110a` (last 1.0.2 commit before V2 landed). The reasoning for all three untagged versions is
recorded in their manifests, and tagging is now a checklist line.
