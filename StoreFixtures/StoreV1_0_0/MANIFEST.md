# Fixture: store as written by 1.0.0

**This is evidence about a released binary, not a store we constructed.** That is the whole point:
a store built from today's model types would be, by definition, the shape we already believe in, and
could not disagree with what shipped.

| | |
|---|---|
| commit | `1e9b20b` — *fix(widget): adaptive premium gradient surface*, 2026-07-10 |
| why this commit | the last commit before `isPossibleDuplicate` was added (`c1d59e4`, 2026-07-11) — i.e. the schema shape 1.0.0 shipped with |
| marketing version | `1.0` (build 2) |
| captured | 2026-08-14, iPhone 17 Pro Max simulator, erased, `--demo-mode`, Debug build |
| transactions | 33 (`sum(ZAMOUNTCENTS)` = 635473) |
| categories / sources | 13 / 3 |
| tables | `ZCATEGORY ZMERCHANTCATEGORYLEARNING ZSOURCE ZTRANSACTION Z_METADATA Z_MODELCACHE Z_PRIMARYKEY` |

`ZTRANSACTION` columns:

```
Z_PK Z_ENT Z_OPT ZAMOUNTCENTS ZISDEMO ZTAXCENTS ZCATEGORY ZSOURCE ZCREATEDAT ZDATE
ZUPDATEDAT ZCURRENCY ZMERCHANT ZNOTE ZRECURRENCERAW ZTYPERAW ZUUID
```

**No `ZISPOSSIBLEDUPLICATE`, and no `ZTRANSACTIONSPLIT` table.** The missing column is the entire
bug: declared `FinanceTrackerSchemaV1` requires it, so this store matches no version the migration
plan knows and could not be migrated at all before the 2026-08-14 fix.

## Rules

- **Never open this store in place.** An open migrates it, which would silently destroy the property
  the fixture exists for. `PreV1StoreMigrationTests` stages a copy in a temp directory, and
  `test_fixture_isOlderThanDeclaredV1` fails loudly if the premise is ever lost.
- Reading it with `sqlite3` rewrites the `-shm`/`-wal` sidecars. The `.sqlite` content is what
  matters; do not treat the sidecars as byte-exact evidence (this already happened once to
  `store-rehearsal/run-1` and `run-2` — see `AUDIT_V3_ROLLBACK_READINESS §6`).
- To regenerate: worktree at `1e9b20b`, build, erase a simulator, install, launch with
  `--demo-mode`, terminate, copy the store triple out of the App Group container.

Proposed siblings for the other shipped versions: `PROPOSAL_STORE_FIXTURE_CORPUS_2026-08-14.md`.

## ⚠️ Which commit is this, really

**This release was never tagged, so the commit is a judgment call, and here is the one that was
made:** `1e9b20b` — the last commit before `c1d59e4` added `isPossibleDuplicate` on 2026-07-11, dated the 1.0.0 release day (2026-07-10). Corroborated by the field: this shape reproduces the reported bug exactly.

The version STRING is not sufficient evidence on its own: it changes when someone remembers to bump
it, not when a build ships. Tag every release (`GO_LIVE_CHECKLIST §3`) and this note stops being
necessary for future versions.
