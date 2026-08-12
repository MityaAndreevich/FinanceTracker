# DEFECT — the V2 migration sentinel disconnects the rollback ladder

**Found:** 2026-08-02, during the V3 readiness audit · **Severity:** high — affects every shipped 1.0.3 device
**Analysis:** `outputs/AUDIT_V3_ROLLBACK_READINESS.md` · **Schema decisions:** `outputs/DESIGN_V3_SCHEMA_FREEZE.md`
**Status:** blocks V3. Fix briefed as its own pass, deliberately separated from the drill.

> Record moved here 2026-08-02 from the studio `STATUS.md`, where it was first written. Budget Crab decision
> records belong in the Budget Crab repo, in version control, next to the audit they explain. `STATUS.md` keeps
> a pointer only — one fact, one home.

## The defect

Every shipped 1.0.3 device has `v2MigrationComplete = true`, so `bootstrap()` takes the fast path. On that path
the app **writes no backup, never increments the sentinel, and never enters the retry loop.** A V2→V3 failure
therefore hits the degraded floor **on the first throw** — with `Backups/pre-v2` already deleted after its own
confirmed-good launch. There is no copy of the user's ledger at the moment it is needed.

The `--fail-migration` seam cannot expose this: it lives in the V1→V2 custom stage, which a lightweight V3 stage
never executes. The safety net reads as present in code and is absent in effect.

**Root cause: the completeness sentinel is a `Bool` where it needed to be a schema version.**

## Why this blocks shipping, not just drilling

A V2→V3 migration released before the fix runs on real paying users' ledgers with the safety net disconnected.
The fix is a **prerequisite of shipping V3**, not a prerequisite of rehearsing it.

## Decisions (2026-08-02)

**1. Fix the ladder first. V3 waits behind it.** Of the three changes costed in the audit §5, the **version-aware
sentinel is load-bearing** and the other two are its consequences. Read legacy `v2MigrationComplete == true` as
"confirmed at 2.0.0" so existing devices migrate their sentinel without a second store touch.
Accept the third change — moving the `--fail-migration` seam into the post-open probe every path executes —
**on its own separate merit**: it makes the seam migration-agnostic, so V4→V5 inherits it free.

**2. The drill runs only on a copied store, in the simulator. Never on the device.** The drill deliberately
fails a migration twice, and the founder's 1.0.3 store is the only real ledger in existence. Procedure:
Settings → Debug → "Share raw store files" → AirDrop to Mac → `store-rehearsal/v2-original/`; work only on
copies, keep the original untouched as the reference. Needed because the repo holds V1 stores only
(7 rows, no `ZTRANSACTIONSPLIT`) — no real V2 store exists on the machine.
The fix is briefed separately from the drill **so the drill can independently falsify the fix**.

**3. Eight V3 attributes frozen.**

| Model | Attributes |
|---|---|
| `Transaction` | `lastPostedPeriod`, `autoPostEnabled`, `occurrenceKey` |
| `Source` | `baselineBalanceCents`, `kindRaw`, `order`, `icon` |
| `Category` | `limitPeriodRaw` |

The test applied was **"are we confident in the name and type today"**, not "will we need it" — additive-only
forbids rename, retype and delete, so *shape* is what freezes, while adding a correct field two versions later
stays legal forever. `Source.order` and `Source.icon` are verbatim copies of fields already proven on
`Category`; their shape cannot be wrong. All money is `Int` cents through `Shared/Money.swift`, and optionality
is load-bearing — `nil` "never set" and `0` "started empty" are different facts that cannot be recovered later.
Transfers, tags and attachments stay **deferred**: the need is real, the *shape* is not settled, and a guessed
key frozen today is a dead column forever.

**⚠️ Name correction, 2026-08-02 — `openingBalanceCents` → `baselineBalanceCents`.** The composability claim for
a future `balanceAnchorDate` holds and was independently re-derived: adding it later is a strict generalization,
a `nil` anchor reproduces today's semantics exactly, and no stored value becomes unreadable — so the field is
not a trap. **But the name does not survive.** Once an anchor exists the value is the balance as of an arbitrary
date, and "opening" is false; under additive-only it can never be renamed. The design's own test passes on type
and fails on name. Costs nothing today, unfixable later.

*This correction was caught by the Budget Crab branch reviewing a decision the app-build branch had already
approved. Recorded because the miss is instructive: the shape test was applied to the type and not to the name.*
