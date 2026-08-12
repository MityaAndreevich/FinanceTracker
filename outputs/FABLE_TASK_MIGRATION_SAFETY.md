# FABLE TASK — design phase only, no code. Finalize the migration as implementable + design the user-facing safety flow. Extend outputs/DESIGN_1_0_3_MODELS_FABLE.md (new §9–§11).

You already designed the V2 schema, the split model, the aggregation 12/7 split, §6 category limits, §7 the didMigrate repair algorithm, and §8 canaries. Decision made: **everything ships in ONE release (1.0.3) with a safety belt.** Design the safety belt.

## §9 — Pre-migration automatic backup + first-launch warning
The migration runs on real users' accumulated stores (currently 8 friends; treat as if it were 8,000 — a migration bug looks identical at any scale).
- You already proposed a `Vela.pre-v2.bak` sidecar. Specify it fully: **when** it's written (before the first V2 store open / before `didMigrate`), **what** it copies (the raw store file(s) — main + any -wal/-shm), **where**, and its **one-release retention** (deleted after a confirmed-good V2 launch).
- Design a **first-launch, pre-migration screen**: "We've improved how your data is stored. As a precaution, export a copy first." with a button that invokes the **existing** CSV/PDF/Excel export (do NOT build new export — reuse it). It must appear BEFORE the migration runs, be dismissible ("Skip"), and never block a user who declines. Specify exactly where in the launch sequence it sits relative to the store open + migration.
- Decide: is the export screen shown once (first V2 launch only) or every launch until acted on? Justify.

## §10 — Rollback / failure path
The non-negotiable: **a mid-migration failure must leave a working store, not a brick.**
- Specify what happens if `didMigrate` throws or the process is killed mid-migration: how the app detects an incomplete/failed migration on next launch, and how it restores from `Vela.pre-v2.bak` to a working V1 state.
- Specify the user-visible message on a restore ("We restored your data from a backup") — no silent data loss, ever.
- Confirm the restore path is itself idempotent and safe to run twice.

## §11 — The real-store verification protocol (write it as a runbook, not code)
This is the gate that unit tests cannot replace — today's 850 green tests missed two device-only blockers. Write the exact steps the founder performs on a COPY of his real device store before this ships:
- how to obtain a copy of the real store off the device,
- how to run the migration against that copy in a throwaway target/scheme,
- the specific post-migration assertions to eyeball (grand total unchanged, transaction count unchanged, no dangling source/category, a known split reads correctly),
- the rollback drill: deliberately fail the migration and confirm the backup restores a working store.

## Token discipline for the downstream implementation (note it in the doc for Sonnet)
Specify the MINIMAL high-value test set, and explicitly list what NOT to test:
- WRITE: the 7 canary double-count detectors (§8), the split-sum invariant, "migration is a no-op on a clean store", "repair fixes a damaged fixture", the rollback-restore test.
- DO NOT WRITE: UI permutation matrices, idempotency ceremony, trivial-getter pins, full-suite reruns.
- Targeted test runs only, never suite-wide (CLAUDE.md).
- The real-store rehearsal (§11) is MANUAL and is NOT one of the tests that can be cut.

Deliverable: §9–§11 appended to the design doc, plus a one-paragraph "implementation order for Sonnet" at the end. Then STOP — no code.
