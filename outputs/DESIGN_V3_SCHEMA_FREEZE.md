# DESIGN — what goes into V2→V3, the last migration with full freedom

**Date:** 2026-08-02 · **Status:** decision document, **no code written yet** (this is the brief-8 item 5 gate)
**Inputs:** `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md` §3.2/§7 · `DESIGN_ICLOUD_SYNC_1_0_4.md` §1.3 ·
`PLAN_RECURRENCE_SYNC_IDENTITY.md` · `MIGRATION_IMPORT_ROADMAP.md` · `ROADMAP_V1_0_2.md` ·
`ARCHITECTURE.md` (Source built for per-account balances; roadmap items 4–5) · the V2 models as they ship in 1.0.3.

---

## 0. First, a correction to the framing — because it changes three of the answers

The brief says: *"Adding a field now costs one line; adding it after sync ships costs a schema version
nobody can undo."*

The second half is not quite right, and the difference decides which speculative fields are worth taking.
What CloudKit's production schema actually forbids, once deployed (`DESIGN_ICLOUD_SYNC_1_0_4` §1.3):

> "no field rename, no retype, no deletion. From the day sync ships, every future schema change must be
> a new optional field."

**Adding an optional field later is explicitly still allowed.** It is *additive*, which is the thing that
stays legal forever. What is irreversible is the **shape** of anything we commit to: a name, a type, a
relationship's cardinality and inverse, a record type's existence.

So the real cost table is:

| Action | Cost after production deploy |
|---|---|
| Add a new optional attribute | Legal forever. Costs: one more schema version + migration stage in the plan, one more "Deploy Schema Changes" in the CloudKit Console, and a window where older clients don't know the field |
| Add a new model / record type | Same — legal, same costs |
| **Rename** a field | **Impossible.** Ever |
| **Retype** a field (`String?` → `UUID?`, `Int?` → `Double?`) | **Impossible.** Ever |
| **Delete** a field | **Impossible.** It stays in the schema forever, dead |
| Change a relationship's inverse or cardinality | **Impossible** |

Which inverts the intuition the brief is working from:

> **A field we add now with the wrong name or the wrong type is permanently worse than a field we
> add correctly two versions later.** The migration is what's expensive to repeat, not the field.

So the test for each candidate is **not** "will we need it?" It is **two** questions, and both must be yes:

1. **Need:** is there a named plan within 2–3 versions that requires it?
2. **Shape confidence:** are we sure of its *name and type* today — because those are what freeze?

A "yes / no" on those two is a **defer**, not a **take**. Speculative fields are cheap to add and
expensive to have added wrong.

⚠️ One more thing this run must not forget: **nothing is frozen yet.** The CloudKit production schema is
deployed in 1.0.4, not 1.0.3. Everything below is still free to change right up until that
"Deploy Schema Changes" click. V3 is the last *migration* with full freedom; the freeze itself happens
one release later. That gives us one more chance to fix a shape — in 1.0.4 development, before deploy —
and exactly one.

---

## 1. The V2 shapes as shipped (what we are adding to)

```
Transaction   uuid, typeRaw, amountCents, currency, date, taxCents?, note?, merchant?,
              recurrenceRaw?, isDemo, isPossibleDuplicate, category?, source?, splits?[],
              createdAt, updatedAt
Category      uuid, name, nameKey?, nameCustom?, kindRaw, icon?, order, isPrimary,
              limitCents?, transactions?[], splits?[]
Source        uuid, name, note?, isActive, transactions?[]
TransactionSplit  uuid, amountCents, note?, order, parent?, category?
```
(`MerchantCategoryLearning` lives in the local-only store and is out of scope for the synced schema —
`DESIGN_1_0_3_MODELS_FABLE` §1.3. `DailyTip` is a plain `Codable` struct loaded from `tips.json`, not a
`@Model` — no schema surface at all.)

---

## 2. The enumeration

### 2.1 TAKE — already agreed, this is what step 3 is

| # | Field | Type | Why it must be in V3 |
|---|---|---|---|
| 1 | `Transaction.lastPostedPeriod` | `Date?` | The recurrence watermark moves out of `UserDefaults` and into the store, so it commits in the same `save()` as the row it authorizes. `DESIGN_AUTOPOST` §3.2/R-4. **Hard prerequisite of sync**, not of auto-post — the per-device UserDefaults key double-charges a two-device user regardless of whether auto-post ships |
| 2 | `Transaction.autoPostEnabled` | `Bool?` | Per-series override. **Not read by 1.0.4.** Taken now on the explicit R-5 decision. Shape confidence is total: it is a nullable flag whose only three states (nil = follow global, true, false) are already specified |
| 3 | `Transaction.occurrenceKey` | `String?` | Deterministic occurrence identity: `"<template uuid lowercased>\|<cadence>\|<period label>"`. Format frozen and documented in `RecurrencePeriod.swift`; `RecurrenceType`'s raw values are frozen as its middle segment. Closes the sync-lag double-charge that `lastPostedPeriod` alone leaves open (§3.4) |

Shape confidence on all three: **high**. Names and types settled in a written design that has already been
amended once (`occurrenceID: UUID?` → `occurrenceKey: String?`, 2026-08-02) — the amendment is exactly the
kind of retype that becomes impossible after deploy, and we got it in under the wire.

### 2.2 TAKE — recommended additions, need + shape both confident

| # | Field | Type | Need (plan it serves) | Shape confidence |
|---|---|---|---|---|
| 4 | `Source.openingBalanceCents` | `Int?` | **Per-account balances.** `ARCHITECTURE.md` line 113 says Source was built for this; balances are unbuildable without a starting figure, because the ledger only contains transactions the user entered, not the account's history | **High.** Every money value in this app is `Int` cents through `Shared/Money.swift`; there is no other type this could be. Optional is load-bearing: `nil` = "never set" is genuinely different from `0` = "this account started empty", and that distinction cannot be recovered later if we default it |
| 5 | `Source.kindRaw` | `String?` | Same feature. A balance is meaningless without knowing whether the account is an asset or a liability — a credit card's balance runs the other way. Also the natural grouping for any accounts screen | **High.** `typeRaw` on Transaction and `kindRaw` on Category already establish the repo's raw-string-plus-typed-enum pattern; a new typed wrapper obeys the same "add cases, never rename" freeze as `RecurrenceType`. The extensibility risk is on the *values*, which are not part of the CloudKit schema |
| 6 | `Source.order` | `Int = 0` | Any accounts list beyond the current alphabetical one. Category already has it | **High** — copied verbatim from `Category.order`, same name, same type, same default |
| 7 | `Source.icon` | `String?` | Same. Category already has it, `SFSymbolPicker` already exists and is shared | **High** — copied verbatim from `Category.icon` |
| 8 | `Category.limitPeriodRaw` | `String?` | **Per-category budgets.** `limitCents` shipped in 1.0.3 and is implicitly monthly (`DESIGN_1_0_3_MODELS_FABLE` §6). The roadmap's budget item and the proactive-alerts item both want weekly/monthly/yearly. `nil` preserves today's meaning — monthly — forever, deliberately and in writing | **High** — same raw-string pattern; `nil` = monthly is a legacy default we are choosing on purpose, not inheriting by accident |

Items 6 and 7 are the cheapest entries on this list: they are not designs, they are **two lines already
written elsewhere in the same codebase**, being copied. Their shape cannot be wrong because it is already
right on `Category`.

### 2.3 DEFER — the need is real, the shape is not settled. This is where the discipline pays

| Candidate | Why it is deferred |
|---|---|
| **Transfers between accounts** (`Transaction.transferGroupKey: String?` or a `Transfer` model) | The moment per-account balances ship, "move $500 from Checking to Savings" becomes the top request — it is the most-requested feature in every ledger app that has accounts. **But the model is genuinely unsettled:** two linked transactions sharing a group key, versus one row with a counterparty account, versus a separate `Transfer` entity. They have different consequences for every aggregation path in `CategoryAttribution`, for CSV export columns, and for what a partially-synced device sees when one leg arrives first. A `transferGroupKey: String?` guessed today and frozen forever, then abandoned for the `Transfer`-model design, is a dead column in the production schema that can never be removed. **Adding it later is legal and costs one migration. Getting it wrong now costs it permanently.** Decide it when transfers are designed, not before |
| **Tags / labels** (`Transaction.tags: String?`) | Mint's CSV export has a `Labels` column and Tier 2 import (v1.1) maps Mint files — so there is a dated, named need. But the correct model for tags is many-to-many, and a comma-joined `String?` is a wart that would be frozen forever the moment it deployed. Tier 2 can route `Labels` into `note` without data loss until tags are designed properly |
| **Attachments / receipts** | Needs a new model plus `CKAsset` semantics, its own privacy review, and a storage-quota conversation. Adding a *model* later is additive and legal. Nothing about it is cheaper today |
| **`Source.balanceAnchorDate: Date?`** ("balance as of a date", for users who don't know the opening figure) | A real alternative to a plain opening balance, and it composes cleanly *on top of* #4 — `openingBalanceCents` becomes the anchor amount, `nil` anchor date means "since the beginning". Because it composes rather than conflicts, taking #4 now does not foreclose it, so there is no reason to take it before the balances feature is designed |
| **`Transaction.isCleared: Bool?`** (pending vs reconciled) | Bank reconciliation is not on any roadmap, and we do not link banks by design. No named need |
| **Soft-delete tombstones** (`deletedAt: Date?`) | SwiftData + CloudKit replicate deletions natively. A tombstone column would invite a whole soft-delete semantics — "is a deleted row still in the totals?" — that nothing in the product asks for |

### 2.4 NOT A SCHEMA DECISION — named here so they are not mistaken for one

- **Household / partner sharing** (roadmap #7) — `CKShare` and a shared database scope, not a field. It
  changes which *zone* records live in, and that decision is independent of the attribute set.
- **Proactive "safe-to-spend" alerts** (roadmap #3) — forecasting state is derived and per-device;
  `@AppStorage`, not the store.
- **The global auto-post toggle** — deliberately per-device `@AppStorage("autoPostRecurring")`
  (`DESIGN_AUTOPOST` §5/R-3). Only the *watermark* syncs. Putting the toggle in the store would create a
  sync surface the design explicitly rejected.
- **CSV import presets / column mapping** (Tier 2) — parsing configuration, not persisted user data.
- **The free/paid line** (roadmap #1, history-horizon gate) — a read-side filter over `date`. No field.

---

## 3. The recommendation

**V3 carries eight optional/defaulted attributes across two models — three agreed, five recommended:**

```swift
// Transaction  (the agreed three — DESIGN_AUTOPOST §3.2)
var lastPostedPeriod: Date?
var autoPostEnabled: Bool?
var occurrenceKey: String?

// Source  (per-account balances, ARCHITECTURE.md:113)
var openingBalanceCents: Int?
var kindRaw: String?
var order: Int = 0
var icon: String?

// Category  (per-category budgets, completes 1.0.3's limitCents)
var limitPeriodRaw: String?
```

Every one is optional or defaulted, so the migration stays **lightweight** — no custom stage, no data
transform, no `willMigrate`/`didMigrate`. That is the whole reason this list can afford to be generous:
five extra attributes cost the same migration as three.

**What this deliberately does not do:** it does not add a field for anything whose shape is still an open
design question. Transfers is the case that proves the rule — the highest-probability future need on the
list, and the one it would be most expensive to guess at.

**One correction to record about the `RecurrencePost` ledger** (`DESIGN_AUTOPOST` R-4): it was rejected
partly because "a new CloudKit record type frozen into the production schema on day one" is expensive.
That reasoning is sound, but note the freeze is on the record type's *existence and shape*, not on adding
record types later — a ledger remains addable in 1.0.5+ as a purely additive change if per-period
decisions ever become a product need. The rejection stands on its other grounds (rows forever, more
surface); it should not be remembered as "we can never have a ledger."

---

## 4. What I need before writing the migration

1. **Go / no-go on §2.2** — the five recommended fields. §2.1's three are already agreed and are not in
   question. If any of the five is a no, say which; the migration is the same shape either way.
2. **A real V2 store** for the item-6 rollback drill — see the separate readiness note. The
   `store-rehearsal/` copies on this machine are **V1** stores from the July 1.0.3 rehearsal (7
   transactions, no `ZTRANSACTIONSPLIT` table), not V2 stores from the shipped app.
