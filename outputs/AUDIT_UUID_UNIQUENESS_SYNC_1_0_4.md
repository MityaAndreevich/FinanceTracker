# AUDIT — `uuid`-uniqueness after first-sync union (§3.6 of DESIGN_ICLOUD_SYNC_1_0_4)

**Date:** 2026-07-29
**Scope:** every site that assumes one row per `uuid`, re-read against the code as it
stands at `f00ae8f`. Prerequisite of enabling `.private(…)` — not a post-ship item.
**No code was changed producing this document.**

---

## 0. Why this list is now longer than the design's

`@Attribute(.unique)` is gone from `Transaction`, `Category`, `Source` in V2
(`Transaction.swift:22`, `Category.swift:16`, `Source.swift:15`) — CloudKit forbids it.
Only `MerchantCategoryLearning.merchantNormalized` keeps it, legally, because that model
lives on the local-only store (`SharedModelContainer.swift:52`).

Twins arise in exactly **one** shape: the "existing + existing" first sync (§2.3), where
two already-populated devices union. Replication itself never mints a twin — one model
instance is one CKRecord. So the blast radius is bounded to users who turn sync on with
data already on both devices. That is still the upgrade path for anyone with an iPad.

The design's §3.6 listed 4 sites. Grepping `uuid ==` across the target returns **19**.
Below, all of them, classified.

---

## 1. Sites that need a decision before sync ships

### 1.1 `RecurrenceService.fetchTemplate(_:modelContext:)` — `RecurrenceService.swift:239–242`

```swift
let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.uuid == uuid })
return (try? modelContext.fetch(descriptor))?.first
```

As the design says: post-union the service drives one twin and prompts for both.
**Confirmed as written.** Interacts with Doc 2 §3.

Compounding factor the design already names in §0.1 but that is worth restating here
because it lands on the *same* symbol: the period watermark is
`UserDefaults.standard["recurring.handled.<uuid>"]` (`:247–258`), keyed by the very
`uuid` that is no longer unique **and** per-device rather than synced. Two independent
failure modes on one key:

| | mechanism | result |
|---|---|---|
| per-device | watermark not synced | both devices prompt, two charges |
| non-unique | two templates share the uuid | one watermark covers both templates |

The second is not fixed by migrating the watermark into the model. It is fixed by the
§2.4 reconciliation pass treating recurring templates the way it treats categories —
or by keying series state on `PersistentIdentifier` rather than `uuid`. **Open decision.**

### 1.2 `DashboardView.handleEditRecurring(_:)` — `DashboardView.swift:394–399`

**Not in the design's §3.6 list.** Same predicate-then-`.first` shape as 1.1, reached
from the "Edit" button on a due prompt:

```swift
RecurrenceService.skip(prompt, modelContext: modelContext)
let uuid = prompt.id
let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.uuid == uuid })
guard let template = try? modelContext.fetch(descriptor).first else { return }
```

Post-union this prefills the Add form from an arbitrary twin. Severity is lower than 1.1
(the user sees the prefilled values and can correct them before saving), but the `skip`
on the line above marks the shared watermark, so the *other* twin is silently skipped
for the period too. Add to the §3.6 list.

### 1.3 AppIntents entity resolution — three sites

- `TransactionEntity.swift:56` — `all.first { $0.uuid == id }`
- `CategoryEntity.swift:45` — same shape
- `AddTransactionIntent.swift:100` — `all.first(where: { $0.uuid == cid })`

**None are in the design's §3.6 list.** Siri/Shortcuts resolves an arbitrary twin.
For `AddTransactionIntent` the consequence is that an intent can file a transaction into
the *loser* category of a pending §2.4 merge — which is then repointed to the winner by
the merge, so it self-heals. For the two `EntityQuery` sites the consequence is a
Shortcuts action operating on the wrong twin of a duplicated row.

These matter more than their severity suggests because of **O-1** (§1.2): the headless
intent process opens the store with `cloudKitDatabase: .none`. An intent that resolves
the wrong twin writes it locally, and the export happens later from the app process.
Worth folding into drill D-11 rather than fixing blind.

---

## 2. Sites where uuid-equality is accidentally *correct*

These compare `uuid` to `uuid` rather than resolving one row, so twins make the guard
**more** conservative, not less. No change needed — but do not "fix" them later without
re-reading this section.

- `CategoriesSourcesView.swift:365, :373, :388` — the in-use guards that block deleting a
  category/account still in use. Twins share a uuid, so the guard blocks deleting *either*
  twin while *any* twin's rows exist. Fails safe. Keep.
- `SeedService.swift:179` — `for tx in allTxs where tx.category?.uuid == loser.uuid` in the
  merge repoint. Same property: the sweep repoints rows belonging to *both* twins of the
  loser. This is the behavior §2.4 wants.

---

## 3. Sites unaffected (confirmed, not assumed)

- `CSVImportService` fetch-by-uuid-then-skip — skipping against *any* matching row is the
  intent. Design's read is correct. Note `:679`'s comment still says `uuid` is
  `@Attribute(.unique)`; the comment is stale as of V2 and should be corrected so the next
  reader does not rely on it.
- `SeedService` idempotence is by `nameKey`, not uuid. Unaffected.
- `EditTransactionView.swift:69, :74, :326, :520` and `AddTransactionView.swift:94, :99,
  :587, :642` — resolve against the in-memory `@Query` array, and any twin renders
  identically until §2.4 converges them. Cosmetic at worst.
- `QuickEntryView.swift:414, :441` — selection-state comparison, not resolution.
- Export/import round-trip — canary C7 covers it.

---

## 4. Recommended order

1. Decide 1.1 (series identity: `PersistentIdentifier` vs. uuid + reconciliation).
   This is the one that can produce **duplicate money**, and §3.5 already establishes
   recurrence is the only path in the app that creates rows without a user tap.
2. Fold 1.2 into whatever 1.1 lands on — same symbol, same fix.
3. Add 1.3 to drill D-11 rather than pre-fixing.
4. Correct the stale `.unique` comment at `CSVImportService.swift:679`.
5. Leave §2 alone, deliberately, with this document as the reason.

**Nothing here is a blocker to writing the sync layer.** All of it is a blocker to
flipping `cloudKitDatabase:` to `.private(…)` in a build that reaches a user.
